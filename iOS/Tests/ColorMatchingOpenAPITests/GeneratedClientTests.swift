import Foundation
import OpenAPIRuntime
import OpenAPIURLSession
import ColorMatchingOpenAPI
import XCTest

// Exercises the swift-openapi-generator client for the surfaces the app uses
// today against stubbed responses shaped like the real Phoenix payloads.
//
// The vendored document and generated surface contract these tests pin is
// defined in docs/openapi-client-test-plan.md; the contract deltas baked into
// the fixtures are recorded in docs/openapi-contract-deltas.md.
final class GeneratedClientTests: XCTestCase {
    override func tearDown() {
        StubbedURLProtocol.handler = nil
        super.tearDown()
    }

    // MARK: - GET /api/v1/test_sheets/{sheet_id}/manifest

    func testFetchTestSheetManifestDecodesSpecFieldsFromRealManifestJSON() async throws {
        StubbedURLProtocol.handler = { request in
            Stubbing.jsonResponse(for: request, status: 200, json: Fixtures.manifestJSON)
        }

        let response = try await client().fetchTestSheetManifest(
            .init(path: .init(sheetId: "sheet_123"))
        )

        guard case .ok(let ok) = response else {
            return XCTFail("Expected .ok, got: \(response)")
        }
        guard case .json(let manifest) = ok.body else {
            return XCTFail("Expected JSON body, got: \(ok.body)")
        }

        XCTAssertEqual(manifest.schemaVersion.rawValue, "lps-sheet-manifest/v1")
        XCTAssertEqual(manifest.sheetId, "sheet_123")
        XCTAssertEqual(manifest.captureProfile.scoringAlgorithmVersion.rawValue, "lps-distance-v1")
    }

    func testFetchTestSheetManifestSendsGETWithJSONAccept() async throws {
        var capturedRequest: URLRequest?
        StubbedURLProtocol.handler = { request in
            capturedRequest = request
            return Stubbing.jsonResponse(for: request, status: 200, json: Fixtures.manifestJSON)
        }

        _ = try await client().fetchTestSheetManifest(.init(path: .init(sheetId: "sheet_123")))

        XCTAssertEqual(capturedRequest?.httpMethod, "GET")
        XCTAssertEqual(capturedRequest?.url?.path, "/api/v1/test_sheets/sheet_123/manifest")
        XCTAssertTrue(capturedRequest?.value(forHTTPHeaderField: "Accept")?.contains("application/json") == true)
    }

    func testFetchTestSheetManifestReturnsDocumentedNotFoundCase() async throws {
        StubbedURLProtocol.handler = { request in
            Stubbing.jsonResponse(for: request, status: 404, json: Fixtures.notFoundErrorJSON)
        }

        let response = try await client().fetchTestSheetManifest(
            .init(path: .init(sheetId: "missing"))
        )

        guard case .notFound = response else {
            return XCTFail("Expected .notFound, got: \(response)")
        }
    }

    // MARK: - GET /api/v1/test_sheets/recent

    func testListRecentSheetsDecodesRealResponseIncludingNullTitle() async throws {
        StubbedURLProtocol.handler = { request in
            Stubbing.jsonResponse(for: request, status: 200, json: Fixtures.recentSheetsJSON)
        }

        let response = try await client().listRecentTestSheets(.init())

        guard case .ok(let ok) = response else {
            return XCTFail("Expected .ok, got: \(response)")
        }
        guard case .json(let recent) = ok.body else {
            return XCTFail("Expected JSON body, got: \(ok.body)")
        }

        XCTAssertEqual(recent.sheets.count, 1)
        XCTAssertEqual(recent.sheets.first?.sheetId, "sheet_123")
        XCTAssertEqual(
            recent.sheets.first?.manifestUrl,
            "https://example.test/api/v1/test_sheets/sheet_123/manifest"
        )
        // Delta vs prose contract: upstream currently renders title as null.
        XCTAssertNil(recent.sheets.first?.title)
    }

    // MARK: - POST /api/v1/test_sheets/{sheet_id}/captures

    func testCreateCapturePostsNestedMetadataAndQualityAndDecodes201() async throws {
        var capturedRequest: URLRequest?
        StubbedURLProtocol.handler = { request in
            capturedRequest = request
            return Stubbing.jsonResponse(for: request, status: 201, json: Fixtures.captureCreatedJSON)
        }

        let metadata = Components.Schemas.CaptureMetadata(
            deviceModel: "iPhone",
            lens: "built_in_wide_angle",
            exposureDurationSeconds: 0.01,
            iso: 100,
            focusLensPosition: 0.4,
            imageWidth: 4032,
            imageHeight: 3024,
            appVersion: "0.1.0",
            timestamp: Date(timeIntervalSince1970: 1_784_980_800)
        )
        let response = try await client().createCapture(
            .init(
                path: .init(sheetId: "sheet_123"),
                body: .json(
                    Components.Schemas.CaptureRequest(
                        metadata: metadata,
                        quality: .init(detectedMarkerCount: 4, blurScore: 0.82, rejections: [])
                    )
                )
            )
        )

        XCTAssertEqual(capturedRequest?.httpMethod, "POST")
        XCTAssertEqual(capturedRequest?.url?.path, "/api/v1/test_sheets/sheet_123/captures")
        XCTAssertTrue(
            capturedRequest?.value(forHTTPHeaderField: "Content-Type")?.contains("application/json") == true
        )
        let json = try XCTUnwrap(RequestBody.jsonObject(of: capturedRequest!) as? [String: Any])
        let metadataPayload = try XCTUnwrap(json["metadata"] as? [String: Any])
        XCTAssertEqual(metadataPayload["device_model"] as? String, "iPhone")
        XCTAssertNotNil(metadataPayload["timestamp"])
        let qualityPayload = try XCTUnwrap(json["quality"] as? [String: Any])
        XCTAssertEqual(qualityPayload["detected_marker_count"] as? Int, 4)

        guard case .created(let created) = response else {
            return XCTFail("Expected .created, got: \(response)")
        }
        guard case .json(let body) = created.body else {
            return XCTFail("Expected JSON body, got: \(created.body)")
        }
        // Delta vs prose contract: capture ids are stringified integer ids.
        XCTAssertEqual(body.captureId, "421")
    }

    // MARK: - POST /api/v1/captures/{capture_id}/measurements

    func testUploadMeasurementsRoundTripsPayloadAndDecodesServerCounts() async throws {
        var capturedRequest: URLRequest?
        StubbedURLProtocol.handler = { request in
            capturedRequest = request
            return Stubbing.jsonResponse(for: request, status: 200, json: Fixtures.measurementUploadResponseJSON)
        }

        let payload = try ConfiguredJSONDecoder().decode(
            Components.Schemas.MeasurementUploadRequest.self,
            from: Fixtures.measurementUploadRequestJSON
        )
        let response = try await client().uploadMeasurements(
            .init(path: .init(captureId: "421"), body: .json(payload))
        )

        XCTAssertEqual(capturedRequest?.httpMethod, "POST")
        XCTAssertEqual(capturedRequest?.url?.path, "/api/v1/captures/421/measurements")
        let json = try XCTUnwrap(RequestBody.jsonObject(of: capturedRequest!) as? [String: Any])
        let measurements = try XCTUnwrap(json["measurements"] as? [[String: Any]])
        XCTAssertEqual(measurements.first?["patch_id"] as? String, "pair_1#first")
        XCTAssertEqual((json["pair_scores"] as? [[String: Any]])?.first?["algorithm_version"] as? String, "lps-distance-v1")

        // Delta vs prose contract: upload responses now carry server counts.
        guard case .ok(let ok) = response else {
            return XCTFail("Expected .ok, got: \(response)")
        }
        guard case .json(let body) = ok.body else {
            return XCTFail("Expected JSON body, got: \(ok.body)")
        }
        XCTAssertEqual(body.captureId, "421")
        XCTAssertEqual(body.measurementCount, 2)
        XCTAssertEqual(body.pairScoreCount, 1)
    }

    // MARK: - POST /api/v1/captures/{capture_id}/judgments

    func testUploadJudgmentsEncodesSnakeCasePayloadAndDecodesCount() async throws {
        var capturedRequest: URLRequest?
        StubbedURLProtocol.handler = { request in
            capturedRequest = request
            return Stubbing.jsonResponse(for: request, status: 200, json: Fixtures.judgmentUploadResponseJSON)
        }

        let payload = Components.Schemas.JudgmentUploadRequest(
            judgments: [.init(pairId: "pair_1", judgment: "near_match")]
        )
        let response = try await client().uploadJudgments(
            .init(path: .init(captureId: "421"), body: .json(payload))
        )

        XCTAssertEqual(capturedRequest?.url?.path, "/api/v1/captures/421/judgments")
        let json = try XCTUnwrap(RequestBody.jsonObject(of: capturedRequest!) as? [String: Any])
        XCTAssertEqual(
            (json["judgments"] as? [[String: Any]])?.first?["judgment"] as? String,
            "near_match"
        )

        guard case .ok(let ok) = response else {
            return XCTFail("Expected .ok, got: \(response)")
        }
        guard case .json(let body) = ok.body else {
            return XCTFail("Expected JSON body, got: \(ok.body)")
        }
        XCTAssertEqual(body.judgmentCount, 1)
    }

    // MARK: - GET /api/v1/test_sheets/{sheet_id}/ranked_results

    func testFetchRankedResultsDecodesSchemaVersionAndSheetID() async throws {
        StubbedURLProtocol.handler = { request in
            Stubbing.jsonResponse(for: request, status: 200, json: Fixtures.rankedResultsJSON)
        }

        let response = try await client().fetchRankedResults(
            .init(path: .init(sheetId: "sheet_123"))
        )

        guard case .ok(let ok) = response else {
            return XCTFail("Expected .ok, got: \(response)")
        }
        guard case .json(let results) = ok.body else {
            return XCTFail("Expected JSON body, got: \(ok.body)")
        }

        XCTAssertEqual(results.schemaVersion.rawValue, "lps-ranked-results/v1")
        XCTAssertEqual(results.sheetId, "sheet_123")
    }

    // MARK: - Helpers

    private func client() -> ColorMatchingOpenAPI.Client {
        ColorMatchingOpenAPI.Client(
            serverURL: URL(string: "https://example.test")!,
            transport: URLSessionTransport(session: Stubbing.session())
        )
    }
}
