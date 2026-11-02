import Foundation
import HTTPTypes
import OpenAPIRuntime
import XCTest
@testable import ColorMatchingOpenAPI

// Exercises the swift-openapi-generator client (generated from the vendored
// spec published by viamin/color_matching#110) against local stubbed
// responses. The generated client replaces the hand-written Codable models in
// `ColorMatchingLPSAppCore/APIClient.swift`; wire payloads are built and read
// exclusively through `Components.Schemas.*` generated types.
//
// Generated method names map 1:1 to the spec's verbatim operationIds; see
// docs/openapi-client-migration.md for the derivation table. If an upstream
// spec change renames an operation or a schema, regenerating the client makes
// these tests fail to compile — that is the intended drift alarm.
final class GeneratedAPIClientTests: XCTestCase {
    private var recorder: RecordedRequests!

    override func setUp() {
        super.setUp()
        recorder = RecordedRequests()
    }

    // MARK: - Test sheet manifest

    func testFetchManifestDecodesTypedFieldsAndSendsBearerToken() async throws {
        let client = makeClient { request, body, operationID in
            await self.recorder.record(request, body: body, operationID: operationID)
            return StubbedResponse.json(Fixture.manifest)
        }

        let response = try await client.getColorMatchingWebTestSheetControllerManifest(
            .init(path: .init(sheetId: "sheet_123"))
        )

        guard case let .ok(payload) = response else {
            return XCTFail("Expected .ok, got \(response)")
        }
        let manifest = payload.body
        XCTAssertEqual(manifest.schemaVersion, "lps-sheet-manifest/v1")
        XCTAssertEqual(manifest.sheetId, "sheet_123")
        XCTAssertEqual(manifest.captureProfile.scoringAlgorithmVersion, "lps-distance-v1")

        let request = try XCTUnwrap(recorder.first)
        XCTAssertEqual(request.method, .get)
        XCTAssertEqual(request.path, "/api/v1/test_sheets/sheet_123/manifest")
        XCTAssertEqual(request.authorization, "Bearer token")
        XCTAssertEqual(request.contentType, nil)
    }

    // MARK: - Recent sheets

    func testFetchRecentSheetsDecodesSheetsAndUsesDedicatedRoute() async throws {
        let client = makeClient { request, body, operationID in
            await self.recorder.record(request, body: body, operationID: operationID)
            return StubbedResponse.json(Fixture.recentSheets)
        }

        let response = try await client.getColorMatchingWebTestSheetControllerRecent(.init())

        guard case let .ok(payload) = response else {
            return XCTFail("Expected .ok, got \(response)")
        }
        XCTAssertEqual(payload.body.sheets.count, 1)
        let sheet = try XCTUnwrap(payload.body.sheets.first)
        XCTAssertEqual(sheet.sheetId, "sheet_123")
        XCTAssertEqual(sheet.manifestUrl, "https://example.test/api/v1/test_sheets/sheet_123/manifest")
        XCTAssertEqual(sheet.title, nil)

        let request = try XCTUnwrap(recorder.first)
        XCTAssertEqual(request.method, .get)
        // `recent` must hit its own route, not be swallowed by `{sheet_id}`.
        XCTAssertEqual(request.path, "/api/v1/test_sheets/recent")
        XCTAssertEqual(request.authorization, "Bearer token")
    }

    // MARK: - Capture session creation

    func testCreateCaptureEncodesNestedMetadataAndQualityAndDecodesCaptureID() async throws {
        let client = makeClient { request, body, operationID in
            await self.recorder.record(request, body: body, operationID: operationID)
            return StubbedResponse.json(#"{"capture_id": "capture_123"}"#, status: .created)
        }

        let captureRequest = Components.Schemas.CaptureRequest(
            metadata: Components.Schemas.CaptureMetadata(
                deviceModel: "iPhone 15 Pro",
                lens: "built_in_wide_angle",
                exposureDurationSeconds: 0.016,
                iso: 100,
                focusLensPosition: 0.42,
                whiteBalanceGains: nil,
                imageWidth: 4032,
                imageHeight: 3024,
                appVersion: "0.1.0",
                timestamp: Date(timeIntervalSince1970: 0)
            ),
            quality: .init(
                detectedMarkerCount: 4,
                blurScore: 0.82,
                rejections: []
            )
        )

        let response = try await client.postColorMatchingWebCaptureControllerCreate(
            .init(path: .init(sheetId: "sheet_123"), body: .json(captureRequest))
        )

        guard case let .created(payload) = response else {
            return XCTFail("Expected .created, got \(response)")
        }
        XCTAssertEqual(payload.body.captureId, "capture_123")

        let request = try XCTUnwrap(recorder.first)
        XCTAssertEqual(request.method, .post)
        XCTAssertEqual(request.path, "/api/v1/test_sheets/sheet_123/captures")
        XCTAssertEqual(request.contentType, "application/json")
        XCTAssertEqual(request.authorization, "Bearer token")

        let json = try XCTUnwrap(Self.jsonObject(from: request.body) as? [String: Any])
        let metadata = try XCTUnwrap(json["metadata"] as? [String: Any])
        XCTAssertEqual(metadata["device_model"] as? String, "iPhone 15 Pro")
        XCTAssertEqual(metadata["image_width"] as? Int, 4032)
        XCTAssertEqual(metadata["timestamp"] as? String, "1970-01-01T00:00:00Z")
        let quality = try XCTUnwrap(json["quality"] as? [String: Any])
        XCTAssertEqual(quality["detected_marker_count"] as? Int, 4)
        XCTAssertEqual(quality["rejections"] as? [String], [])
    }

    // MARK: - Measurement upload

    func testUploadMeasurementsEncodesGeneratedTypesAndDecodesCounts() async throws {
        let client = makeClient { request, body, operationID in
            await self.recorder.record(request, body: body, operationID: operationID)
            return StubbedResponse.json(
                #"{"capture_id": "capture_123", "measurement_count": 1, "pair_score_count": 1}"#
            )
        }

        let median = Components.Schemas.RgbPayload.case2(.init(r: 0.12, g: 0.1, b: 0.02))
        let upload = Components.Schemas.MeasurementUploadRequest(
            measurements: [
                .init(
                    patchId: "patch_1",
                    linearRgbMedian: median,
                    normalizedLinearRgbMedian: median
                )
            ],
            pairScores: [
                Components.Schemas.PairScoreRequest(
                    pairId: "pair_1",
                    algorithmVersion: "lps-distance-v1",
                    score: nil,
                    similarity: 0.965,
                    distance: 0.035
                )
            ]
        )

        let response = try await client.postColorMatchingWebCaptureControllerUploadMeasurements(
            .init(path: .init(captureId: "capture_123"), body: .json(upload))
        )

        guard case let .ok(payload) = response else {
            return XCTFail("Expected .ok, got \(response)")
        }
        XCTAssertEqual(payload.body.captureId, "capture_123")
        XCTAssertEqual(payload.body.measurementCount, 1)
        XCTAssertEqual(payload.body.pairScoreCount, 1)

        let request = try XCTUnwrap(recorder.first)
        XCTAssertEqual(request.method, .post)
        XCTAssertEqual(request.path, "/api/v1/captures/capture_123/measurements")
        XCTAssertEqual(request.contentType, "application/json")

        let json = try XCTUnwrap(Self.jsonObject(from: request.body) as? [String: Any])
        // The published spec drops the prose contract's top-level
        // `scoring_algorithm_version`; only per-pair `algorithm_version` exists.
        XCTAssertNil(json["scoring_algorithm_version"])
        let measurement = try XCTUnwrap((json["measurements"] as? [[String: Any]])?.first)
        XCTAssertEqual(measurement["patch_id"] as? String, "patch_1")
        let linearMedian = try XCTUnwrap(measurement["linear_rgb_median"] as? [String: Any])
        XCTAssertEqual(linearMedian["r"] as? Double, 0.12)
        let pairScore = try XCTUnwrap((json["pair_scores"] as? [[String: Any]])?.first)
        XCTAssertEqual(pairScore["pair_id"] as? String, "pair_1")
        XCTAssertEqual(pairScore["algorithm_version"] as? String, "lps-distance-v1")
        XCTAssertEqual(pairScore["similarity"] as? Double, 0.965)
    }

    // MARK: - Judgment upload

    func testUploadJudgmentsEncodesPayloadAndDecodesJudgmentCount() async throws {
        let client = makeClient { request, body, operationID in
            await self.recorder.record(request, body: body, operationID: operationID)
            return StubbedResponse.json(
                #"{"capture_id": "capture_123", "judgment_count": 1}"#
            )
        }

        let upload = Components.Schemas.JudgmentUploadRequest(
            judgments: [.init(pairId: "pair_1", judgment: "near_match")]
        )

        let response = try await client.postColorMatchingWebCaptureControllerUploadJudgments(
            .init(path: .init(captureId: "capture_123"), body: .json(upload))
        )

        guard case let .ok(payload) = response else {
            return XCTFail("Expected .ok, got \(response)")
        }
        XCTAssertEqual(payload.body.captureId, "capture_123")
        XCTAssertEqual(payload.body.judgmentCount, 1)

        let request = try XCTUnwrap(recorder.first)
        XCTAssertEqual(request.method, .post)
        XCTAssertEqual(request.path, "/api/v1/captures/capture_123/judgments")
        XCTAssertEqual(request.authorization, "Bearer token")
        let json = try XCTUnwrap(Self.jsonObject(from: request.body) as? [String: Any])
        let judgment = try XCTUnwrap((json["judgments"] as? [[String: Any]])?.first)
        XCTAssertEqual(judgment["pair_id"] as? String, "pair_1")
        XCTAssertEqual(judgment["judgment"] as? String, "near_match")
    }

    // MARK: - Ranked results

    func testFetchRankedResultsDecodesSchemaVersionAndSheetID() async throws {
        let client = makeClient { request, body, operationID in
            await self.recorder.record(request, body: body, operationID: operationID)
            return StubbedResponse.json(Fixture.rankedResults)
        }

        let response = try await client.getColorMatchingWebTestSheetControllerRankedResults(
            .init(path: .init(sheetId: "sheet_123"))
        )

        guard case let .ok(payload) = response else {
            return XCTFail("Expected .ok, got \(response)")
        }
        XCTAssertEqual(payload.body.schemaVersion, "lps-ranked-results/v1")
        XCTAssertEqual(payload.body.sheetId, "sheet_123")

        let request = try XCTUnwrap(recorder.first)
        XCTAssertEqual(request.method, .get)
        XCTAssertEqual(request.path, "/api/v1/test_sheets/sheet_123/ranked_results")
        XCTAssertEqual(request.authorization, "Bearer token")
    }

    // MARK: - Server-side drift surfaces as an error, not silent success

    func testManifestMissingRequiredFieldFailsDecoding() async throws {
        // Server dropped `schema_version` and `capture_profile`: a required
        // field in the published spec. The generated decoder must throw.
        let client = makeClient { _, _, _ in
            StubbedResponse.json(#"{"sheet_id": "sheet_123"}"#)
        }

        await XCTAssertThrowsError(
            try await client.getColorMatchingWebTestSheetControllerManifest(
                .init(path: .init(sheetId: "sheet_123"))
            )
        )
    }

    func testUndocumentedHTTPStatusFailsInsteadOfPassingThrough() async throws {
        let client = makeClient { _, _, _ in
            StubbedResponse.json(#"{"errors": {"detail": "boom"}}"#, status: .internalServerError)
        }

        await XCTAssertThrowsError(
            try await client.getColorMatchingWebTestSheetControllerRecent(.init())
        )
    }

    func testUnauthorizedResponseDecodesToTypedCase() async throws {
        let client = makeClient { request, body, operationID in
            await self.recorder.record(request, body: body, operationID: operationID)
            return StubbedResponse.json(
                #"{"errors": {"detail": "Unauthorized"}}"#,
                status: .unauthorized
            )
        }

        let response = try await client.getColorMatchingWebTestSheetControllerRecent(.init())

        switch response {
        case .ok:
            XCTFail("Expected .unauthorized, got .ok")
        case .unauthorized:
            break
        }
        XCTAssertEqual(recorder.first?.authorization, "Bearer token")
    }

    // MARK: - Helpers

    private func makeClient(
        respond: @escaping @Sendable (HTTPRequest, HTTPBody?, String) async throws -> (HTTPResponse, HTTPBody?)
    ) -> ColorMatchingOpenAPI.Client {
        ColorMatchingOpenAPI.Client(
            serverURL: URL(string: "https://example.test")!,
            transport: StubbedResponseTransport(respond: respond),
            middlewares: [BearerTokenMiddleware(token: "token")]
        )
    }

    private static func jsonObject(from data: Data?) throws -> Any {
        try JSONSerialization.jsonObject(with: XCTUnwrap(data))
    }
}
