#if canImport(GeneratedAPIClient)
#if canImport(HTTPTypes)
import HTTPTypes
#endif
import Foundation
import GeneratedAPIClient
import OpenAPIRuntime
import XCTest

final class GeneratedClientTests: XCTestCase {
    private static let serverURL = URL(string: "https://api.example.test")!

    func testGetTestSheetManifestSendsGETAndDecodesManifest() async throws {
        var capturedRequest: RecordedHTTPRequest?
        let (client, _) = Self.makeClient { request in
            capturedRequest = request
            return .init(statusCode: 200, body: Data(Self.manifestJSON.utf8))
        }

        let response = try await client.getTestSheetManifest(path: .init(sheet_id: "sheet_1"))

        let request = try XCTUnwrap(capturedRequest)
        XCTAssertEqual(request.method, "GET")
        XCTAssertEqual(request.path, "/api/v1/test_sheets/sheet_1/manifest")
        XCTAssertEqual(request.operationID, "getTestSheetManifest")
        XCTAssertTrue(request.headerFields["accept"]?.contains("application/json") ?? false)
        XCTAssertNil(request.headerFields["authorization"])
        XCTAssertTrue(request.body.isEmpty)

        guard case .ok(let ok) = response else {
            return XCTFail("Expected .ok for manifest fetch, got \(String(describing: response))")
        }
        guard case .json(let manifest) = ok.body else {
            return XCTFail("Expected JSON body for manifest fetch")
        }
        XCTAssertEqual(manifest.schema_version, "lps-sheet-manifest/v1")
        XCTAssertEqual(manifest.sheet_version, "lps-letter-grid-v1")
        XCTAssertEqual(manifest.sheet_id, "sheet_1")
        XCTAssertEqual(manifest.manifest_url, "https://api.example.test/api/v1/test_sheets/sheet_1/manifest")
        XCTAssertEqual(manifest.page.units, "mm")
        XCTAssertEqual(manifest.page.width, 215.9, accuracy: 0.0001)
        XCTAssertEqual(manifest.registration_markers.first?.rect.width, 8, accuracy: 0.0001)
        XCTAssertEqual(manifest.patches.count, 2)
        XCTAssertEqual(manifest.patches.first?.safe_inset_mm, 1.5, accuracy: 0.0001)
        XCTAssertEqual(manifest.patches.first?.pair_id, "pair_1")
        XCTAssertEqual(manifest.pairs.first?.first_patch_id, "patch_1")
        XCTAssertEqual(manifest.pairs.first?.second_patch_id, "patch_2")
        XCTAssertEqual(manifest.pairs.first?.source_colors, ["#FF0000", "#00FF00"])
    }

    func testListRecentTestSheetsDecodesSummariesWithOptionalTitle() async throws {
        let (client, _) = Self.makeClient { _ in
            .init(statusCode: 200, body: Data(Self.recentSheetsJSON.utf8))
        }

        let response = try await client.listRecentTestSheets()

        guard case .ok(let ok) = response else {
            return XCTFail("Expected .ok for recent sheets, got \(String(describing: response))")
        }
        guard case .json(let recent) = ok.body else {
            return XCTFail("Expected JSON body for recent sheets")
        }
        XCTAssertEqual(recent.sheets.count, 2)
        XCTAssertEqual(recent.sheets.first?.sheet_id, "sheet_1")
        XCTAssertNil(recent.sheets.first?.title)
        XCTAssertEqual(recent.sheets.last?.sheet_id, "sheet_2")
        XCTAssertEqual(recent.sheets.last?.title, "July LPS comparison sheet")
        XCTAssertEqual(recent.sheets.last?.manifest_url, "https://api.example.test/api/v1/test_sheets/sheet_2/manifest")
    }

    func testCreateCaptureEncodesMetadataQualityAndDecodesCaptureID() async throws {
        var capturedRequest: RecordedHTTPRequest?
        let (client, _) = Self.makeClient { request in
            capturedRequest = request
            return .init(statusCode: 201, body: Data(#"{"capture_id":"cap_123"}"#.utf8))
        }

        let payload = Components.Schemas.CreateCaptureRequest(
            metadata: .init(
                device_model: "iPhone 15",
                lens: "built_in_wide_angle",
                exposure_duration_seconds: 0.016,
                iso: 100,
                focus_lens_position: 0.42,
                white_balance_gains: .init(red: 1.2, green: 1.0, blue: 1.4),
                image_width: 4032,
                image_height: 3024,
                app_version: "0.1.0",
                timestamp: Date(timeIntervalSince1970: 1_785_000_000)
            ),
            quality: .init(
                detected_marker_count: 4,
                blur_score: 0.82,
                rejections: [try XCTUnwrap(Components.Schemas.CaptureRejection(rawValue: "excessiveBlur"))]
            )
        )

        let response = try await client.createCapture(path: .init(sheet_id: "sheet_1"), body: .json(payload))

        let request = try XCTUnwrap(capturedRequest)
        XCTAssertEqual(request.method, "POST")
        XCTAssertEqual(request.path, "/api/v1/test_sheets/sheet_1/captures")
        XCTAssertEqual(request.operationID, "createCapture")
        XCTAssertTrue(request.headerFields["content-type"]?.contains("application/json") ?? false)

        let body = try XCTUnwrap(Self.jsonObject(request.body) as? [String: Any])
        let metadata = try XCTUnwrap(body["metadata"] as? [String: Any])
        XCTAssertEqual(metadata["device_model"] as? String, "iPhone 15")
        XCTAssertEqual(metadata["lens"] as? String, "built_in_wide_angle")
        XCTAssertNotNil(metadata["timestamp"])
        let gains = try XCTUnwrap(metadata["white_balance_gains"] as? [String: Any])
        XCTAssertEqual(gains["red"] as? Double ?? 0, 1.2, accuracy: 0.0001)
        let quality = try XCTUnwrap(body["quality"] as? [String: Any])
        XCTAssertEqual(quality["detected_marker_count"] as? Int, 4)
        XCTAssertEqual(quality["rejections"] as? [String], ["excessiveBlur"])

        guard case .created(let created) = response else {
            return XCTFail("Expected .created for capture creation, got \(String(describing: response))")
        }
        guard case .json(let session) = created.body else {
            return XCTFail("Expected JSON body for capture creation")
        }
        XCTAssertEqual(session.capture_id, "cap_123")
    }

    func testUploadMeasurementsEncodesSnakeCasePayloadAndAcceptsNoContent() async throws {
        var capturedRequest: RecordedHTTPRequest?
        let (client, _) = Self.makeClient { request in
            capturedRequest = request
            return .init(statusCode: 204, body: Data())
        }

        let payload = Components.Schemas.MeasurementUploadRequest(
            scoring_algorithm_version: "lps-distance-v1",
            measurements: [
                .init(
                    patch_id: "patch_1",
                    linear_rgb_median: .init(r: 0.12, g: 0.10, b: 0.02),
                    normalized_linear_rgb_median: .init(r: 0.15, g: 0.12, b: 0.02),
                    stats: .init(
                        sample_count: 900,
                        clipping_fraction: 0,
                        mean: .init(r: 0.12, g: 0.10, b: 0.02),
                        standard_deviation: .init(r: 0.01, g: 0.01, b: 0.004)
                    )
                )
            ],
            pair_scores: [
                .init(pair_id: "pair_1", distance: 0.035, similarity: 0.965, algorithm_version: "lps-distance-v1")
            ]
        )

        let response = try await client.uploadMeasurements(path: .init(capture_id: "cap_1"), body: .json(payload))

        let request = try XCTUnwrap(capturedRequest)
        XCTAssertEqual(request.method, "POST")
        XCTAssertEqual(request.path, "/api/v1/captures/cap_1/measurements")
        XCTAssertEqual(request.operationID, "uploadMeasurements")

        let body = try XCTUnwrap(Self.jsonObject(request.body) as? [String: Any])
        XCTAssertEqual(body["scoring_algorithm_version"] as? String, "lps-distance-v1")
        let measurement = try XCTUnwrap((body["measurements"] as? [[String: Any]])?.first)
        XCTAssertEqual(measurement["patch_id"] as? String, "patch_1")
        let median = try XCTUnwrap(measurement["linear_rgb_median"] as? [String: Any])
        XCTAssertEqual(median["r"] as? Double ?? 0, 0.12, accuracy: 0.0001)
        let stats = try XCTUnwrap(measurement["stats"] as? [String: Any])
        XCTAssertEqual(stats["sample_count"] as? Int, 900)
        XCTAssertEqual(Set(stats.keys), ["sample_count", "clipping_fraction", "mean", "standard_deviation"])
        let score = try XCTUnwrap((body["pair_scores"] as? [[String: Any]])?.first)
        XCTAssertEqual(score["pair_id"] as? String, "pair_1")
        XCTAssertEqual(score["algorithm_version"] as? String, "lps-distance-v1")

        guard case .noContent = response else {
            return XCTFail("Expected .noContent for measurement upload, got \(String(describing: response))")
        }
    }

    func testUploadJudgmentsEncodesPairJudgments() async throws {
        var capturedRequest: RecordedHTTPRequest?
        let (client, _) = Self.makeClient { request in
            capturedRequest = request
            return .init(statusCode: 204, body: Data())
        }

        let payload = Components.Schemas.JudgmentUploadRequest(
            judgments: [
                .init(pair_id: "pair_1", judgment: try XCTUnwrap(Components.Schemas.Judgment(rawValue: "near_match")))
            ]
        )

        let response = try await client.uploadJudgments(path: .init(capture_id: "cap_1"), body: .json(payload))

        let request = try XCTUnwrap(capturedRequest)
        XCTAssertEqual(request.method, "POST")
        XCTAssertEqual(request.path, "/api/v1/captures/cap_1/judgments")
        XCTAssertEqual(request.operationID, "uploadJudgments")

        let body = try XCTUnwrap(Self.jsonObject(request.body) as? [String: Any])
        let judgment = try XCTUnwrap((body["judgments"] as? [[String: Any]])?.first)
        XCTAssertEqual(judgment["pair_id"] as? String, "pair_1")
        XCTAssertEqual(judgment["judgment"] as? String, "near_match")

        guard case .noContent = response else {
            return XCTFail("Expected .noContent for judgment upload, got \(String(describing: response))")
        }
    }

    func testGetRankedResultsDecodesRankedPairs() async throws {
        var capturedRequest: RecordedHTTPRequest?
        let (client, _) = Self.makeClient { request in
            capturedRequest = request
            return .init(statusCode: 200, body: Data(Self.rankedResultsJSON.utf8))
        }

        let response = try await client.getRankedResults(path: .init(sheet_id: "sheet_1"))

        let request = try XCTUnwrap(capturedRequest)
        XCTAssertEqual(request.method, "GET")
        XCTAssertEqual(request.path, "/api/v1/test_sheets/sheet_1/ranked_results")
        XCTAssertEqual(request.operationID, "getRankedResults")
        XCTAssertTrue(request.body.isEmpty)

        guard case .ok(let ok) = response else {
            return XCTFail("Expected .ok for ranked results, got \(String(describing: response))")
        }
        guard case .json(let ranked) = ok.body else {
            return XCTFail("Expected JSON body for ranked results")
        }
        XCTAssertEqual(ranked.sheet_id, "sheet_1")
        XCTAssertEqual(ranked.scoring_algorithm_version, "lps-distance-v1")
        XCTAssertEqual(ranked.results.count, 1)
        let result = try XCTUnwrap(ranked.results.first)
        XCTAssertEqual(result.pair_id, "pair_1")
        XCTAssertEqual(result.source_colors, ["#FF0000", "#00FF00"])
        XCTAssertEqual(result.distance, 0.035, accuracy: 0.0001)
        XCTAssertEqual(result.similarity, 0.965, accuracy: 0.0001)
        XCTAssertEqual(result.judgment?.rawValue, "near_match")
        XCTAssertEqual(result.capture_id, "cap_123")
    }

    func testGetTestSheetManifestSurfacesUnauthorizedResponse() async throws {
        let (client, _) = Self.makeClient { _ in
            .init(statusCode: 401, body: Data(#"{"error":"unauthorized"}"#.utf8))
        }

        let response = try await client.getTestSheetManifest(path: .init(sheet_id: "sheet_1"))

        guard case .unauthorized = response else {
            return XCTFail("Expected .unauthorized for missing token, got \(String(describing: response))")
        }
    }

    private static func makeClient(handler: @escaping StubTransport.Handler) -> (GeneratedAPIClient.Client, StubTransport) {
        let transport = StubTransport(handler: handler)
        let client = GeneratedAPIClient.Client(serverURL: serverURL, transport: transport)
        return (client, transport)
    }

    private static func jsonObject(_ data: Data) throws -> Any {
        try JSONSerialization.jsonObject(with: data)
    }

    private static let manifestJSON = """
    {
      "schema_version": "lps-sheet-manifest/v1",
      "sheet_version": "lps-letter-grid-v1",
      "sheet_id": "sheet_1",
      "manifest_url": "https://api.example.test/api/v1/test_sheets/sheet_1/manifest",
      "created_at": "2026-07-25T12:00:00Z",
      "page": {"units": "mm", "width": 215.9, "height": 279.4},
      "registration_markers": [
        {"role": "top_left", "shape": "solid_square", "rect": {"x": 12, "y": 12, "width": 8, "height": 8}}
      ],
      "printer_profile": {
        "id": "printer_profile_1",
        "name": "Research printer",
        "paper": "Research paper",
        "ink": "Dye ink set",
        "settings": {}
      },
      "capture_profile": {
        "expected_illuminant": "low_pressure_sodium",
        "preferred_camera": "built_in_wide_angle_rear",
        "scoring_algorithm_version": "lps-distance-v1"
      },
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
        },
        {
          "id": "patch_2",
          "role": "pair_color",
          "pair_id": "pair_1",
          "pair_side": "second",
          "reference_role": null,
          "source_color": "#00FF00",
          "safe_inset_mm": 1.5,
          "rect": {"x": 36, "y": 38, "width": 16, "height": 10}
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

    private static let recentSheetsJSON = """
    {
      "sheets": [
        {"sheet_id": "sheet_1", "manifest_url": "https://api.example.test/api/v1/test_sheets/sheet_1/manifest", "title": null},
        {"sheet_id": "sheet_2", "manifest_url": "https://api.example.test/api/v1/test_sheets/sheet_2/manifest", "title": "July LPS comparison sheet"}
      ]
    }
    """

    private static let rankedResultsJSON = """
    {
      "sheet_id": "sheet_1",
      "scoring_algorithm_version": "lps-distance-v1",
      "results": [
        {
          "pair_id": "pair_1",
          "source_colors": ["#FF0000", "#00FF00"],
          "distance": 0.035,
          "similarity": 0.965,
          "judgment": "near_match",
          "capture_id": "cap_123"
        }
      ]
    }
    """
}

struct RecordedHTTPRequest {
    let method: String
    let path: String
    let headerFields: [String: String]
    let body: Data
    let baseURL: URL
    let operationID: String
}

struct StubbedHTTPResponse {
    let statusCode: Int
    let body: Data
}

final class StubTransport: ClientTransport, @unchecked Sendable {
    typealias Handler = (RecordedHTTPRequest) throws -> StubbedHTTPResponse

    private let handler: Handler
    private(set) var recordedRequests: [RecordedHTTPRequest] = []

    init(handler: @escaping Handler) {
        self.handler = handler
    }

    func send(_ request: HTTPRequest, body: HTTPBody?, baseURL: URL, operationID: String) async throws -> (HTTPResponse, HTTPBody?) {
        let recorded = RecordedHTTPRequest(
            method: request.method.rawValue,
            path: request.path ?? "",
            headerFields: Self.lowercasedHeaders(request.headerFields),
            body: try await Self.collect(body),
            baseURL: baseURL,
            operationID: operationID
        )
        recordedRequests.append(recorded)
        let stubbed = try handler(recorded)
        let response = HTTPResponse(
            status: .init(code: stubbed.statusCode),
            headerFields: Self.responseHeaders(stubbed)
        )
        return (response, stubbed.body.isEmpty ? nil : HTTPBody(stubbed.body))
    }

    private static func lowercasedHeaders(_ fields: HTTPFields) -> [String: String] {
        var headers: [String: String] = [:]
        for field in fields {
            headers[field.name.canonicalName] = field.value
        }
        return headers
    }

    private static func responseHeaders(_ stubbed: StubbedHTTPResponse) -> HTTPFields {
        var fields = HTTPFields()
        if !stubbed.body.isEmpty {
            fields[.contentType] = "application/json"
        }
        return fields
    }

    private static func collect(_ body: HTTPBody?) async throws -> Data {
        guard let body else { return Data() }
        return try await Data(collecting: body, upTo: 1_024 * 1_024)
    }
}
#else
import XCTest

final class GeneratedClientMigrationTests: XCTestCase {
    func testGeneratedClientModuleIsAvailable() {
        XCTFail(
            "GeneratedAPIClient module is missing: issue #5 requires vendoring the OpenAPI document "
                + "and adding the swift-openapi-generator target. The guarded tests in this file "
                + "activate once the module is generated."
        )
    }
}
#endif
