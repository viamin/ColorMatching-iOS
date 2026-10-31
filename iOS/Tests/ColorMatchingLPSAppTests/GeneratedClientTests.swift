import Foundation
import MeasurementCore
import OpenAPIRuntime
import ColorMatchingAPI
import ColorMatchingLPSAppCore
import XCTest

/// Exercises the OpenAPI-generated client (module `ColorMatchingAPI`, produced
/// by swift-openapi-generator from the vendored `Sources/ColorMatchingAPI/openapi.json`)
/// against stubbed responses for every API surface the app uses today.
///
/// RED PHASE: this file intentionally does not compile until the implementation
/// run adds the generated `ColorMatchingAPI` target — a missing module here is
/// the compile-time drift signal the migration exists to buy. Naming follows the
/// generator's documented rules for the vendored document:
///
/// - OperationIds are kept verbatim from the published spec, e.g.
///   `ColorMatchingWeb.TestSheetController.manifest` generates the method
///   `colorMatchingWeb_TestSheetController_manifest` (periods become `_`,
///   snake_case segments are camelCased).
/// - Property names are camelCased (`sheet_id` -> `sheetId`) and CodingKeys map
///   back to the documented JSON keys.
///
/// The binding assertions are the HTTP-level facts (method, path, operationId,
/// JSON wire bodies, rawValues) — mechanical name adjustments are permitted only
/// where a pinned generator version differs; see
/// docs/openapi-client-migration-test-plan.md.
final class GeneratedClientTests: XCTestCase {
    private let serverURL = URL(string: "https://example.test")!

    // MARK: - Test-sheet manifest

    func testGetManifestDecodesVersionedContractAndTargetsPublishedPath() async throws {
        let transport = OpenAPIStubTransport { _ in
            .json(.ok, Self.manifestJSON)
        }
        let client = ColorMatchingAPI.Client(serverURL: serverURL, transport: transport)

        let output = try await client.colorMatchingWeb_TestSheetController_manifest(
            .init(path: .init(sheetId: "sheet_1"))
        )

        let recorded = try XCTUnwrap(transport.recorded.single)
        XCTAssertEqual(recorded.method, "GET")
        XCTAssertEqual(recorded.path, "/api/v1/test_sheets/sheet_1/manifest")
        XCTAssertEqual(recorded.operationID, "ColorMatchingWeb.TestSheetController.manifest")

        guard case .ok(let ok) = output else { return XCTFail("expected 200, got \(output)") }
        let manifest = try ok.body.json
        XCTAssertEqual(manifest.schemaVersion.rawValue, "lps-sheet-manifest/v1")
        XCTAssertEqual(manifest.sheetId, "sheet_1")
        XCTAssertEqual(manifest.captureProfile.scoringAlgorithmVersion.rawValue, "lps-distance-v1")
    }

    // MARK: - Recent sheets

    func testListRecentSheetsDecodesTitlesIncludingNull() async throws {
        let transport = OpenAPIStubTransport { _ in
            .json(
                .ok,
                #"{"sheets":[{"sheet_id":"sheet_1","manifest_url":"https://example.test/api/v1/test_sheets/sheet_1/manifest","title":"July LPS sheet"},{"sheet_id":"sheet_2","manifest_url":"https://example.test/api/v1/test_sheets/sheet_2/manifest","title":null}]}"#
            )
        }
        let client = ColorMatchingAPI.Client(serverURL: serverURL, transport: transport)

        let output = try await client.colorMatchingWeb_TestSheetController_recent(.init())

        let recorded = try XCTUnwrap(transport.recorded.single)
        XCTAssertEqual(recorded.method, "GET")
        XCTAssertEqual(recorded.path, "/api/v1/test_sheets/recent")
        XCTAssertEqual(recorded.operationID, "ColorMatchingWeb.TestSheetController.recent")

        guard case .ok(let ok) = output else { return XCTFail("expected 200, got \(output)") }
        let sheets = try ok.body.json.sheets
        XCTAssertEqual(sheets.map(\.sheetId), ["sheet_1", "sheet_2"])
        XCTAssertEqual(sheets.first?.title, "July LPS sheet")
        XCTAssertNil(sheets.last?.title, "sheets without a display name decode with a null title")
    }

    // MARK: - Capture session creation

    func testCreateCaptureEncodesNestedMetadataAndQualityAndDecodesCaptureID() async throws {
        let transport = OpenAPIStubTransport { _ in
            .json(.created, #"{"capture_id":"cap_1"}"#)
        }
        let client = ColorMatchingAPI.Client(serverURL: serverURL, transport: transport)

        let metadata = Components.Schemas.CaptureMetadata(
            deviceModel: "iPhone",
            lens: "built_in_wide_angle",
            exposureDurationSeconds: 0.016,
            iso: 100,
            focusLensPosition: 0.42,
            whiteBalanceGains: [
                "red": AnyCodable(1.2),
                "green": AnyCodable(1.0),
                "blue": AnyCodable(1.4),
            ],
            imageWidth: 4032,
            imageHeight: 3024,
            appVersion: "0.1.0",
            timestamp: try Self.isoDate("2026-07-25T12:00:00Z")
        )
        let quality = Components.Schemas.CaptureRequest.qualityPayload(
            detectedMarkerCount: 4,
            blurScore: 0.82,
            rejections: []
        )
        let body = Components.Schemas.CaptureRequest(metadata: metadata, quality: quality)

        let output = try await client.colorMatchingWeb_CaptureController_create(
            .init(path: .init(sheetId: "sheet_1"), body: .json(body))
        )

        let recorded = try XCTUnwrap(transport.recorded.single)
        XCTAssertEqual(recorded.method, "POST")
        XCTAssertEqual(recorded.path, "/api/v1/test_sheets/sheet_1/captures")
        XCTAssertEqual(recorded.operationID, "ColorMatchingWeb.CaptureController.create")
        XCTAssertEqual(recorded.contentType, "application/json")

        let json = try Self.jsonObject(recorded.body)
        let metadataJSON = try XCTUnwrap(json["metadata"] as? [String: Any])
        XCTAssertEqual(metadataJSON["device_model"] as? String, "iPhone")
        XCTAssertEqual(metadataJSON["iso"] as? Int, 100)
        XCTAssertTrue(
            (metadataJSON["timestamp"] as? String ?? "").hasPrefix("2026-07-25T12:00:00"),
            "timestamp must encode as an ISO8601 date-time"
        )
        let gains = try XCTUnwrap(metadataJSON["white_balance_gains"] as? [String: Any])
        XCTAssertEqual(try gains["red"].unwrapAsDouble(), 1.2, accuracy: 1e-9)
        let qualityJSON = try XCTUnwrap(json["quality"] as? [String: Any])
        XCTAssertEqual(qualityJSON["detected_marker_count"] as? Int, 4)
        XCTAssertEqual(qualityJSON["rejections"] as? [Any], [])

        guard case .created(let created) = output else { return XCTFail("expected 201, got \(output)") }
        XCTAssertEqual(try created.body.json.captureId, "cap_1")
    }

    // MARK: - Measurement upload

    func testUploadMeasurementsEncodesPublishedPayloadAndDecodesCounts() async throws {
        let transport = OpenAPIStubTransport { _ in
            .json(.ok, #"{"capture_id":"cap_1","measurement_count":1,"pair_score_count":1}"#)
        }
        let client = ColorMatchingAPI.Client(serverURL: serverURL, transport: transport)

        let rgb = Components.Schemas.RgbPayload(r: 0.2, g: 0.3, b: 0.4)
        let measurement = Components.Schemas.MeasurementUploadRequest.measurementsPayload(
            patchId: "patch_1",
            linearRgbMedian: rgb,
            normalizedRgbMedian: rgb
        )
        let score = Components.Schemas.PairScoreRequest(
            pairId: "pair_1",
            algorithmVersion: LPSScorer.algorithmVersion,
            score: nil,
            similarity: 0.9,
            distance: 0.1
        )
        let body = Components.Schemas.MeasurementUploadRequest(
            measurements: [measurement],
            pairScores: [score]
        )

        let output = try await client.colorMatchingWeb_CaptureController_uploadMeasurements(
            .init(path: .init(captureId: "cap_1"), body: .json(body))
        )

        let recorded = try XCTUnwrap(transport.recorded.single)
        XCTAssertEqual(recorded.method, "POST")
        XCTAssertEqual(recorded.path, "/api/v1/captures/cap_1/measurements")
        XCTAssertEqual(recorded.operationID, "ColorMatchingWeb.CaptureController.upload_measurements")

        let json = try Self.jsonObject(recorded.body)
        XCTAssertFalse(
            (json.keys).contains("scoring_algorithm_version"),
            "the published contract has no top-level scoring_algorithm_version; algorithm_version rides on each pair score"
        )
        let measurementJSON = try XCTUnwrap((json["measurements"] as? [[String: Any]])?.first)
        XCTAssertEqual(measurementJSON["patch_id"] as? String, "patch_1")
        XCTAssertNotNil(measurementJSON["normalized_linear_rgb_median"], "normalized median is required by the published spec")
        XCTAssertNil(measurementJSON["stats"], "the published contract has no stats object")
        let scoreJSON = try XCTUnwrap((json["pair_scores"] as? [[String: Any]])?.first)
        XCTAssertEqual(scoreJSON["algorithm_version"] as? String, "lps-distance-v1")
        XCTAssertEqual(try scoreJSON["similarity"].unwrapAsDouble(), 0.9, accuracy: 1e-9)

        guard case .ok(let ok) = output else { return XCTFail("expected 200, got \(output)") }
        let accepted = try ok.body.json
        XCTAssertEqual(accepted.measurementCount, 1)
        XCTAssertEqual(accepted.pairScoreCount, 1)
    }

    // MARK: - Judgment upload

    func testUploadJudgmentsEncodesPairsAndDecodesCount() async throws {
        let transport = OpenAPIStubTransport { _ in
            .json(.ok, #"{"capture_id":"cap_1","judgment_count":1}"#)
        }
        let client = ColorMatchingAPI.Client(serverURL: serverURL, transport: transport)

        let judgment = Components.Schemas.JudgmentUploadRequest.judgmentsPayload(
            pairId: "pair_1",
            judgment: "near_match"
        )
        let body = Components.Schemas.JudgmentUploadRequest(judgments: [judgment])

        let output = try await client.colorMatchingWeb_CaptureController_uploadJudgments(
            .init(path: .init(captureId: "cap_1"), body: .json(body))
        )

        let recorded = try XCTUnwrap(transport.recorded.single)
        XCTAssertEqual(recorded.method, "POST")
        XCTAssertEqual(recorded.path, "/api/v1/captures/cap_1/judgments")
        XCTAssertEqual(recorded.operationID, "ColorMatchingWeb.CaptureController.upload_judgments")

        let json = try Self.jsonObject(recorded.body)
        let judgmentJSON = try XCTUnwrap((json["judgments"] as? [[String: Any]])?.first)
        XCTAssertEqual(judgmentJSON["pair_id"] as? String, "pair_1")
        XCTAssertEqual(judgmentJSON["judgment"] as? String, "near_match")

        guard case .ok(let ok) = output else { return XCTFail("expected 200, got \(output)") }
        XCTAssertEqual(try ok.body.json.judgmentCount, 1)
    }

    // MARK: - Ranked results

    func testGetRankedResultsDecodesVersionedContract() async throws {
        let transport = OpenAPIStubTransport { _ in
            .json(.ok, #"{"schema_version":"lps-ranked-results/v1","sheet_id":"sheet_1"}"#)
        }
        let client = ColorMatchingAPI.Client(serverURL: serverURL, transport: transport)

        let output = try await client.colorMatchingWeb_TestSheetController_rankedResults(
            .init(path: .init(sheetId: "sheet_1"))
        )

        let recorded = try XCTUnwrap(transport.recorded.single)
        XCTAssertEqual(recorded.method, "GET")
        XCTAssertEqual(recorded.path, "/api/v1/test_sheets/sheet_1/ranked_results")
        XCTAssertEqual(recorded.operationID, "ColorMatchingWeb.TestSheetController.ranked_results")

        guard case .ok(let ok) = output else { return XCTFail("expected 200, got \(output)") }
        let results = try ok.body.json
        XCTAssertEqual(results.schemaVersion.rawValue, "lps-ranked-results/v1")
        XCTAssertEqual(results.sheetId, "sheet_1")
    }

    // MARK: - Bearer auth

    func testBearerTokenMiddlewareAppliesAuthorizationHeaderToGeneratedRequests() async throws {
        let transport = OpenAPIStubTransport { _ in
            .json(.ok, #"{"sheets":[]}"#)
        }
        let client = ColorMatchingAPI.Client(
            serverURL: serverURL,
            transport: transport,
            configuration: .init(middlewares: [ColorMatchingLPSAppCore.BearerTokenMiddleware(token: "token")])
        )

        _ = try await client.colorMatchingWeb_TestSheetController_recent(.init())

        XCTAssertEqual(
            transport.recorded.single?.authorization,
            "Bearer token",
            "the app's bearer auth must reach generated requests via a ClientMiddleware"
        )
    }

    // MARK: - Fixtures and helpers

    private static let manifestJSON = """
    {
      "schema_version": "lps-sheet-manifest/v1",
      "sheet_id": "sheet_1",
      "capture_profile": {"scoring_algorithm_version": "lps-distance-v1"}
    }
    """

    private static func isoDate(_ string: String) throws -> Date {
        try XCTUnwrap(ISO8601DateFormatter().date(from: string), "unparseable date \(string)")
    }

    private static func jsonObject(_ data: Data?) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(data)) as? [String: Any])
    }
}

private extension Array {
    var single: Element? { count == 1 ? first : nil }
}

private extension Optional where Wrapped == Any {
    func unwrapAsDouble() throws -> Double {
        try XCTUnwrap((self as? NSNumber)?.doubleValue)
    }
}
