#if canImport(ColorMatchingOpenAPI)
import ColorMatchingOpenAPI
import Foundation
import OpenAPIRuntime
import XCTest

final class GeneratedClientTests: XCTestCase {
    func testGetTestSheetManifestDecodesStubbedManifest() async throws {
        let manifestJSON = Data(##"""
        {
          "schema_version": "lps-sheet-manifest/v1",
          "sheet_version": "lps-letter-grid-v1",
          "sheet_id": "sheet_123",
          "manifest_url": "https://example.test/api/v1/test_sheets/sheet_123/manifest",
          "created_at": "2026-07-25T12:00:00Z",
          "page": {"units": "mm", "width": 215.9, "height": 279.4},
          "registration_markers": [
            {"role": "top_left", "shape": "solid_square", "rect": {"x": 12, "y": 12, "width": 8, "height": 8}}
          ],
          "printer_profile": {"id": "printer_profile_1", "name": "Research printer", "paper": "paper name", "ink": "ink set", "settings": {}},
          "capture_profile": {"expected_illuminant": "low_pressure_sodium", "preferred_camera": "built_in_wide_angle_rear", "scoring_algorithm_version": "lps-distance-v1"},
          "patches": [
            {"id": "patch_1", "role": "pair_color", "pair_id": "pair_1", "pair_side": "first", "reference_role": null, "source_color": "#FF0000", "safe_inset_mm": 1.5, "rect": {"x": 16, "y": 38, "width": 16, "height": 10}}
          ],
          "pairs": [
            {"id": "pair_1", "first_patch_id": "patch_1", "second_patch_id": "patch_2", "source_colors": ["#FF0000", "#00FF00"], "grid_row": 0, "grid_col": 1}
          ]
        }
        """##.utf8)

        let (client, transport) = Self.client(statusCode: 200, body: manifestJSON)
        let output = try await client.getTestSheetManifest(.init(path: .init(sheet_id: "sheet_123")))

        guard case .ok(let ok) = output else {
            return XCTFail("Expected 200 ok for manifest fetch, got \(output)")
        }
        guard case .json(let manifest) = ok.body else {
            return XCTFail("Expected JSON body for manifest fetch")
        }
        XCTAssertEqual(manifest.schema_version, "lps-sheet-manifest/v1")
        XCTAssertEqual(manifest.sheet_id, "sheet_123")
        XCTAssertEqual(manifest.patches.first?.source_color, "#FF0000")
        XCTAssertEqual(manifest.pairs.first?.source_colors, ["#FF0000", "#00FF00"])
        Self.assertRequest(transport, method: .get, path: "/api/v1/test_sheets/sheet_123/manifest")
    }

    func testListRecentTestSheetsDecodesNullableTitle() async throws {
        let recentJSON = Data(##"""
        {
          "sheets": [
            {"sheet_id": "sheet_123", "manifest_url": "https://example.test/api/v1/test_sheets/sheet_123/manifest", "title": null},
            {"sheet_id": "sheet_456", "manifest_url": "https://example.test/api/v1/test_sheets/sheet_456/manifest", "title": "July LPS comparison sheet"}
          ]
        }
        """##.utf8)

        let (client, transport) = Self.client(statusCode: 200, body: recentJSON)
        let output = try await client.listRecentTestSheets(.init())

        guard case .ok(let ok) = output else {
            return XCTFail("Expected 200 ok for recent sheets, got \(output)")
        }
        guard case .json(let body) = ok.body else {
            return XCTFail("Expected JSON body for recent sheets")
        }
        XCTAssertEqual(body.sheets.count, 2)
        XCTAssertEqual(body.sheets.first?.title, nil)
        XCTAssertEqual(body.sheets.last?.title, "July LPS comparison sheet")
        Self.assertRequest(transport, method: .get, path: "/api/v1/test_sheets/recent")
    }

    func testCreateCaptureSendsPayloadAndReturnsCaptureID() async throws {
        let (client, transport) = Self.client(statusCode: 201, body: Data(#"{"capture_id": "capture_123"}"#.utf8))
        let output = try await client.createCapture(.init(
            path: .init(sheet_id: "sheet_123"),
            body: .json(.init(
                metadata: .init(
                    device_model: "iPhone",
                    lens: "built_in_wide_angle",
                    exposure_duration_seconds: 0.016,
                    iso: 100,
                    focus_lens_position: 0.42,
                    white_balance_gains: .init(red: 1.2, green: 1.0, blue: 1.4),
                    image_width: 4032,
                    image_height: 3024,
                    app_version: "0.1.0",
                    timestamp: Date(timeIntervalSince1970: 1_784_942_400)
                ),
                quality: .init(
                    detected_marker_count: 4,
                    blur_score: 0.82,
                    rejections: []
                )
            ))
        ))

        guard case .ok(let ok) = output else {
            return XCTFail("Expected 201 ok for capture creation, got \(output)")
        }
        guard case .json(let body) = ok.body else {
            return XCTFail("Expected JSON body for capture creation")
        }
        XCTAssertEqual(body.capture_id, "capture_123")
        Self.assertRequest(transport, method: .post, path: "/api/v1/test_sheets/sheet_123/captures")
    }

    func testUploadMeasurementsReturnsNoContent() async throws {
        let (client, transport) = Self.client(statusCode: 204)
        let output = try await client.uploadMeasurements(.init(
            path: .init(capture_id: "capture_123"),
            body: .json(.init(
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
                    .init(
                        pair_id: "pair_1",
                        distance: 0.035,
                        similarity: 0.965,
                        algorithm_version: "lps-distance-v1"
                    )
                ]
            ))
        ))

        guard case .noContent = output else {
            return XCTFail("Expected 204 no content for measurement upload, got \(output)")
        }
        Self.assertRequest(transport, method: .post, path: "/api/v1/captures/capture_123/measurements")
    }

    func testUploadJudgmentsReturnsNoContent() async throws {
        let (client, transport) = Self.client(statusCode: 204)
        let output = try await client.uploadJudgments(.init(
            path: .init(capture_id: "capture_123"),
            body: .json(.init(
                judgments: [.init(pair_id: "pair_1", judgment: .near_match)]
            ))
        ))

        guard case .noContent = output else {
            return XCTFail("Expected 204 no content for judgment upload, got \(output)")
        }
        Self.assertRequest(transport, method: .post, path: "/api/v1/captures/capture_123/judgments")
    }

    func testGetRankedResultsDecodesStubbedResults() async throws {
        let rankedJSON = Data(##"""
        {
          "scoring_algorithm_version": "lps-distance-v1",
          "results": [
            {
              "pair_id": "pair_1",
              "source_colors": ["#FF0000", "#00FF00"],
              "distance": 0.035,
              "similarity": 0.965,
              "judgment": "near_match",
              "capture_id": "capture_123"
            }
          ]
        }
        """##.utf8)

        let (client, transport) = Self.client(statusCode: 200, body: rankedJSON)
        let output = try await client.getRankedResults(.init(path: .init(sheet_id: "sheet_123")))

        guard case .ok(let ok) = output else {
            return XCTFail("Expected 200 ok for ranked results, got \(output)")
        }
        guard case .json(let body) = ok.body else {
            return XCTFail("Expected JSON body for ranked results")
        }
        XCTAssertEqual(body.scoring_algorithm_version, "lps-distance-v1")
        XCTAssertEqual(body.results.count, 1)
        XCTAssertEqual(body.results.first?.pair_id, "pair_1")
        XCTAssertEqual(body.results.first?.judgment, .near_match)
        Self.assertRequest(transport, method: .get, path: "/api/v1/test_sheets/sheet_123/ranked_results")
    }

    private static func client(statusCode: Int, body: Data = Data()) -> (client: Client, transport: StubTransport) {
        let transport = StubTransport(statusCode: statusCode, body: body)
        let client = Client(serverURL: baseURL, transport: transport)
        return (client, transport)
    }

    private static var baseURL: URL {
        URL(string: "https://example.test")!
    }

    private static func assertRequest(
        _ transport: StubTransport,
        method: HTTPRequest.Method,
        path: String,
        line: UInt = #line
    ) {
        XCTAssertEqual(transport.lastRequest?.method, method, line: line)
        XCTAssertEqual(transport.lastRequest?.path, path, line: line)
    }
}

private final class StubTransport: ClientTransport {
    private let statusCode: Int
    private let body: Data
    private(set) var lastRequest: HTTPRequest?

    init(statusCode: Int, body: Data) {
        self.statusCode = statusCode
        self.body = body
    }

    func send(_ request: HTTPRequest, baseURL: URL, operationID: String) async throws -> (HTTPURLResponse, Data) {
        lastRequest = request
        let response = HTTPURLResponse(
            url: baseURL,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: body.isEmpty ? nil : ["Content-Type": "application/json"]
        )
        return (try XCTUnwrap(response), body)
    }
}
#endif
