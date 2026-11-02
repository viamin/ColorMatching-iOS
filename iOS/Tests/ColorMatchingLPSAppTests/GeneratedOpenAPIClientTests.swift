#if canImport(ColorMatchingOpenAPI) && canImport(OpenAPIRuntime)
import ColorMatchingOpenAPI
import Foundation
import OpenAPIRuntime
import XCTest

/// Exercises the generated OpenAPI client (swift-openapi-generator, target
/// `ColorMatchingOpenAPI`) against a stubbed `ClientTransport` — no live
/// server in CI. The wire shapes pinned here mirror the published `/api/v1`
/// spec from viamin/color_matching#110; the expected generated names are
/// derived in `docs/openapi-generated-client.md`.
final class GeneratedOpenAPIClientTests: XCTestCase {
    private var transport: StubTransport!
    private var client: Client!

    override func setUp() {
        super.setUp()
        transport = StubTransport()
        client = Client(
            serverURL: URL(string: "https://color-matching.example.test")!,
            transport: transport
        )
    }

    // MARK: - Test sheet manifest

    func testFetchManifestSendsGetToManifestPathAndDecodesDocumentedFields() async throws {
        transport.respond(status: 200, json: Self.manifestJSON)

        let response = try await client.colorMatchingWeb_TestSheetController_manifest(
            .init(path: .init(sheetId: "sheet_123"))
        )

        try assertSent(method: "GET", path: "/api/v1/test_sheets/sheet_123/manifest")

        guard case .ok(let ok) = response else { return XCTFail("expected .ok, got \(response)") }
        guard case .json(let manifest) = ok.body else { return XCTFail("expected JSON body, got \(ok.body)") }
        XCTAssertEqual(manifest.schemaVersion, .lpsSheetManifestV1)
        XCTAssertEqual(manifest.sheetId, "sheet_123")
        XCTAssertEqual(manifest.captureProfile?.scoringAlgorithmVersion, .lpsDistanceV1)
    }

    func testFetchManifestSurfacesNotFoundError() async throws {
        transport.respond(status: 404, json: #"{"errors":{"detail":"Sheet not found"}}"#)

        let response = try await client.colorMatchingWeb_TestSheetController_manifest(
            .init(path: .init(sheetId: "missing_sheet"))
        )

        guard case .notFound = response else { return XCTFail("expected .notFound, got \(response)") }
    }

    func testFetchManifestSurfacesUndocumentedStatusAsUndocumented() async throws {
        transport.respond(status: 503, json: #"{"errors":{"detail":"upstream down"}}"#)

        let response = try await client.colorMatchingWeb_TestSheetController_manifest(
            .init(path: .init(sheetId: "sheet_123"))
        )

        guard case .undocumented(let statusCode, _) = response else {
            return XCTFail("expected .undocumented, got \(response)")
        }
        XCTAssertEqual(statusCode, 503)
    }

    // MARK: - Recent sheets

    func testFetchRecentSheetsDecodesSheetsAndNullableTitles() async throws {
        transport.respond(
            status: 200,
            json: #"{"sheets":[{"sheet_id":"sheet_123","manifest_url":"https://color-matching.example.test/api/v1/test_sheets/sheet_123/manifest","title":null},{"sheet_id":"sheet_9","manifest_url":"https://color-matching.example.test/api/v1/test_sheets/sheet_9/manifest","title":"July LPS sheet"}]}"#
        )

        let response = try await client.colorMatchingWeb_TestSheetController_recent(.init())

        try assertSent(method: "GET", path: "/api/v1/test_sheets/recent")

        guard case .ok(let ok) = response else { return XCTFail("expected .ok, got \(response)") }
        guard case .json(let body) = ok.body else { return XCTFail("expected JSON body, got \(ok.body)") }
        let sheets = body.sheets
        XCTAssertEqual(sheets.count, 2)
        XCTAssertEqual(sheets.first?.sheetId, "sheet_123")
        XCTAssertNil(sheets.first?.title, "an explicit JSON null title must decode as nil")
        XCTAssertEqual(sheets.last?.sheetId, "sheet_9")
        XCTAssertEqual(sheets.last?.title, "July LPS sheet")
    }

    // MARK: - Ranked results

    func testFetchRankedResultsDecodesVersionAndSheetID() async throws {
        transport.respond(
            status: 200,
            json: #"{"schema_version":"lps-ranked-results/v1","sheet_id":"sheet_123"}"#
        )

        let response = try await client.colorMatchingWeb_TestSheetController_rankedResults(
            .init(path: .init(sheetId: "sheet_123"))
        )

        try assertSent(method: "GET", path: "/api/v1/test_sheets/sheet_123/ranked_results")

        guard case .ok(let ok) = response else { return XCTFail("expected .ok, got \(response)") }
        guard case .json(let ranked) = ok.body else { return XCTFail("expected JSON body, got \(ok.body)") }
        XCTAssertEqual(ranked.schemaVersion, .lpsRankedResultsV1)
        XCTAssertEqual(ranked.sheetId, "sheet_123")
    }

    // MARK: - Capture session creation

    func testCreateCapturePostsNestedMetadataAndQualityAndDecodesCaptureID() async throws {
        transport.respond(status: 201, json: #"{"capture_id":"105"}"#)

        let metadata = Components.Schemas.CaptureMetadata(
            deviceModel: "iPhone 15 Pro",
            lens: "built_in_wide_angle",
            imageWidth: 4032,
            imageHeight: 3024,
            appVersion: "0.1.0",
            timestamp: Date(timeIntervalSince1970: 0)
        )
        let quality = Components.Schemas.CaptureRequest.Quality(
            detectedMarkerCount: 4,
            blurScore: 0.82,
            rejections: []
        )

        let response = try await client.colorMatchingWeb_CaptureController_create(
            .init(
                path: .init(sheetId: "sheet_123"),
                body: .json(Components.Schemas.CaptureRequest(metadata: metadata, quality: quality))
            )
        )

        try assertSent(method: "POST", path: "/api/v1/test_sheets/sheet_123/captures")

        let payload = try sentJSONObject()
        let metadataPayload = try XCTUnwrap(payload["metadata"] as? [String: Any])
        XCTAssertEqual(metadataPayload["device_model"] as? String, "iPhone 15 Pro")
        XCTAssertEqual(metadataPayload["lens"] as? String, "built_in_wide_angle")
        XCTAssertEqual(metadataPayload["image_width"] as? Int, 4032)
        XCTAssertEqual(metadataPayload["image_height"] as? Int, 3024)
        XCTAssertEqual(metadataPayload["app_version"] as? String, "0.1.0")
        XCTAssertEqual(metadataPayload["timestamp"] as? String, "1970-01-01T00:00:00Z")
        let qualityPayload = try XCTUnwrap(payload["quality"] as? [String: Any])
        XCTAssertEqual(qualityPayload["detected_marker_count"] as? Int, 4)
        XCTAssertEqual(qualityPayload["blur_score"] as? Double, 0.82)
        XCTAssertEqual(qualityPayload["rejections"] as? [String], [])

        guard case .created(let created) = response else { return XCTFail("expected .created, got \(response)") }
        guard case .json(let capture) = created.body else { return XCTFail("expected JSON body") }
        XCTAssertEqual(capture.captureId, "105")
    }

    // MARK: - Measurement upload

    func testUploadMeasurementsPostsSnakeCasePayloadAndDecodesCounts() async throws {
        transport.respond(
            status: 200,
            json: #"{"capture_id":"105","measurement_count":1,"pair_score_count":1}"#
        )

        let payload = try JSONDecoder().decode(
            Components.Schemas.MeasurementUploadRequest.self,
            from: Data(Self.measurementsJSON.utf8)
        )

        let response = try await client.colorMatchingWeb_CaptureController_uploadMeasurements(
            .init(path: .init(captureId: "105"), body: .json(payload))
        )

        try assertSent(method: "POST", path: "/api/v1/captures/105/measurements")

        let body = try sentJSONObject()
        let measurements = try XCTUnwrap(body["measurements"] as? [[String: Any]])
        let measurement = try XCTUnwrap(measurements.first)
        XCTAssertEqual(measurement["patch_id"] as? String, "patch_1")
        XCTAssertEqual(measurement["linear_rgb_median"] as? [String: Double], ["r": 0.12, "g": 0.1, "b": 0.02])
        XCTAssertNotNil(measurement["normalized_linear_rgb_median"])

        let pairScores = try XCTUnwrap(body["pair_scores"] as? [[String: Any]])
        let pairScore = try XCTUnwrap(pairScores.first)
        XCTAssertEqual(pairScore["pair_id"] as? String, "pair_1")
        XCTAssertEqual(pairScore["algorithm_version"] as? String, "lps-distance-v1")
        XCTAssertEqual(pairScore["similarity"] as? Double, 0.965)

        guard case .ok(let ok) = response else { return XCTFail("expected .ok, got \(response)") }
        guard case .json(let counts) = ok.body else { return XCTFail("expected JSON body") }
        XCTAssertEqual(counts.captureId, "105")
        XCTAssertEqual(counts.measurementCount, 1)
        XCTAssertEqual(counts.pairScoreCount, 1)
    }

    // MARK: - Judgment upload

    func testUploadJudgmentsPostsJudgmentsAndDecodesCount() async throws {
        transport.respond(status: 200, json: #"{"capture_id":"105","judgment_count":1}"#)

        let payload = try JSONDecoder().decode(
            Components.Schemas.JudgmentUploadRequest.self,
            from: Data(#"{"judgments":[{"pair_id":"pair_1","judgment":"near_match"}]}"#.utf8)
        )

        let response = try await client.colorMatchingWeb_CaptureController_uploadJudgments(
            .init(path: .init(captureId: "105"), body: .json(payload))
        )

        try assertSent(method: "POST", path: "/api/v1/captures/105/judgments")

        let body = try sentJSONObject()
        let judgments = try XCTUnwrap(body["judgments"] as? [[String: Any]])
        XCTAssertEqual(judgments.first?["pair_id"] as? String, "pair_1")
        XCTAssertEqual(judgments.first?["judgment"] as? String, "near_match")

        guard case .ok(let ok) = response else { return XCTFail("expected .ok, got \(response)") }
        guard case .json(let summary) = ok.body else { return XCTFail("expected JSON body") }
        XCTAssertEqual(summary.captureId, "105")
        XCTAssertEqual(summary.judgmentCount, 1)
    }
}

// MARK: - Fixtures

private extension GeneratedOpenAPIClientTests {
    /// Realistic manifest response: the documented fields plus the
    /// undocumented extras the server actually sends (page, patches, ...).
    /// Decoding must tolerate the extras until upstream documents them.
    static let manifestJSON = """
        {
          "schema_version": "lps-sheet-manifest/v1",
          "sheet_id": "sheet_123",
          "capture_profile": {"scoring_algorithm_version": "lps-distance-v1"},
          "sheet_version": "lps-letter-grid-v1",
          "manifest_url": "https://color-matching.example.test/api/v1/test_sheets/sheet_123/manifest",
          "page": {"units": "mm", "width": 215.9, "height": 279.4},
          "registration_markers": [],
          "printer_profile": {"id": 1, "name": "Research printer", "paper": "paper name", "ink": "ink set", "settings": {}},
          "patches": [
            {
              "id": "patch_1",
              "role": "pair_color",
              "pair_id": "pair_1",
              "pair_side": "first",
              "reference_role": null,
              "source_color": "#FF0000",
              "safe_inset_mm": 1.5,
              "rect": {"x": 16, "y": 38, "width": 16, "height": 10}
            }
          ],
          "pairs": [
            {
              "id": "pair_1",
              "first_patch_id": "patch_1",
              "second_patch_id": "patch_2",
              "source_colors": ["#FF0000", "#00FF00"],
              "grid_row": 0,
              "grid_col": 1
            }
          ]
        }
        """

    static let measurementsJSON = """
        {
          "measurements": [
            {
              "patch_id": "patch_1",
              "linear_rgb_median": {"r": 0.12, "g": 0.1, "b": 0.02},
              "normalized_linear_rgb_median": {"r": 0.15, "g": 0.12, "b": 0.02}
            }
          ],
          "pair_scores": [
            {
              "pair_id": "pair_1",
              "algorithm_version": "lps-distance-v1",
              "distance": 0.035,
              "similarity": 0.965
            }
          ]
        }
        """
}

// MARK: - Request assertions

private extension GeneratedOpenAPIClientTests {
    func assertSent(method: String, path: String, file: StaticString = #filePath, line: UInt = #line) throws {
        let request = try XCTUnwrap(transport.lastRequest, "no request was sent", file: file, line: line)
        XCTAssertEqual(request.method.rawValue, method, file: file, line: line)
        XCTAssertEqual(request.path, path, file: file, line: line)
    }

    func sentJSONObject(file: StaticString = #filePath, line: UInt = #line) throws -> [String: Any] {
        let body = try XCTUnwrap(transport.lastRequestBody, "no request body was sent", file: file, line: line)
        let object = try JSONSerialization.jsonObject(with: body)
        return try XCTUnwrap(object as? [String: Any], "request body is not a JSON object", file: file, line: line)
    }
}

// MARK: - Stub transport

/// A `ClientTransport` that records the outgoing request and returns a
/// locally stubbed response; guarantees the tests never touch the network.
private final class StubTransport: ClientTransport, @unchecked Sendable {
    private let lock = NSLock()
    private var responder: @Sendable (HTTPRequest) -> (HTTPResponse, HTTPBody?) = { _ in
        (HTTPResponse(status: .init(code: 500)), HTTPBody())
    }

    private(set) var lastRequest: HTTPRequest?
    private(set) var lastRequestBody: Data?
    private(set) var lastOperationID: String?

    func respond(status: Int, json: String) {
        lock.lock()
        defer { lock.unlock() }
        responder = { _ in
            var response = HTTPResponse(status: .init(code: status))
            response.headerFields[.contentType] = "application/json"
            return (response, HTTPBody(Data(json.utf8)))
        }
    }

    func send(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String
    ) async throws -> (HTTPResponse, HTTPBody?) {
        lastRequest = request
        lastOperationID = operationID
        lastRequestBody = try await Self.collect(body)
        lock.lock()
        let respond = responder
        lock.unlock()
        return respond(request)
    }

    private static func collect(_ body: HTTPBody?) async throws -> Data {
        guard let body else { return Data() }
        return Data(try await [UInt8](collecting: body, upTo: 1 << 20))
    }
}
#else
import XCTest

/// Red-phase marker: the generated OpenAPI client from issue #5 is not wired
/// into the Swift package yet. This test stops failing once the target
/// `ColorMatchingOpenAPI` (built by the OpenAPIGenerator plugin from
/// `iOS/OpenAPI/color-matching.json`) and `swift-openapi-runtime` are
/// dependencies of this test target.
final class GeneratedOpenAPIClientAvailabilityTests: XCTestCase {
    func testGeneratedOpenAPIClientIsWiredIntoPackage() {
        XCTFail(
            """
            The generated OpenAPI client is not available: \
            'ColorMatchingOpenAPI' and 'OpenAPIRuntime' are not importable from this test target. \
            See docs/openapi-generated-client.md for the implementation contract (issue #5).
            """
        )
    }
}
#endif
