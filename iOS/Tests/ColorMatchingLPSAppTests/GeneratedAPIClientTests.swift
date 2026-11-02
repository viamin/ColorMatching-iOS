import Foundation
import XCTest
import OpenAPIRuntime
import HTTPTypes
import ColorMatchingAPIClient

final class GeneratedAPIClientTests: XCTestCase {
    private static let serverURL = URL(string: "https://color-matching.example.test")!

    func testManifestUsesGetAndDecodesDocumentedFields() async throws {
        let transport = StubTransport(response: Self.jsonResponse(.ok, Self.manifestJSON))
        let client = Self.makeClient(transport)

        let output = try await client.colorMatchingWeb_TestSheetController_manifest(
            .init(path: .init(sheetId: "lps-7f3a"))
        )

        XCTAssertEqual(transport.recorded?.method, "GET")
        XCTAssertEqual(transport.recorded?.path, "/api/v1/test_sheets/lps-7f3a/manifest")
        XCTAssertEqual(transport.recorded?.operationID, "ColorMatchingWeb.TestSheetController.manifest")
        guard case .ok(let ok) = output else { return XCTFail("Expected .ok response") }
        let manifest = try ok.body.json
        XCTAssertEqual(manifest.schemaVersion, .lpsSheetManifestV1)
        XCTAssertEqual(manifest.sheetId, "lps-7f3a")
        XCTAssertEqual(manifest.captureProfile.scoringAlgorithmVersion, .lpsDistanceV1)
    }

    func testManifestNotFoundSurfacesDocumentedNotFoundCase() async throws {
        let transport = StubTransport(
            response: Self.jsonResponse(.notFound, #"{"errors":{"detail":"Sheet not found"}}"#)
        )
        let client = Self.makeClient(transport)

        let output = try await client.colorMatchingWeb_TestSheetController_manifest(
            .init(path: .init(sheetId: "missing"))
        )

        XCTAssertEqual(transport.recorded?.path, "/api/v1/test_sheets/missing/manifest")
        guard case .notFound = output else { return XCTFail("Expected .notFound response") }
    }

    func testRecentSheetsDecodesSheetsWithNullableTitle() async throws {
        let transport = StubTransport(
            response: Self.jsonResponse(
                .ok,
                #"{"sheets":[{"sheet_id":"lps-7f3a","manifest_url":"https://color-matching.example.test/api/v1/test_sheets/lps-7f3a/manifest","title":null}]}"#
            )
        )
        let client = Self.makeClient(transport)

        let output = try await client.colorMatchingWeb_TestSheetController_recent(.init())

        XCTAssertEqual(transport.recorded?.method, "GET")
        XCTAssertEqual(transport.recorded?.path, "/api/v1/test_sheets/recent")
        XCTAssertEqual(transport.recorded?.operationID, "ColorMatchingWeb.TestSheetController.recent")
        guard case .ok(let ok) = output else { return XCTFail("Expected .ok response") }
        let sheets = try ok.body.json.sheets
        XCTAssertEqual(sheets.count, 1)
        XCTAssertEqual(sheets.first?.sheetId, "lps-7f3a")
        XCTAssertEqual(
            sheets.first?.manifestUrl,
            "https://color-matching.example.test/api/v1/test_sheets/lps-7f3a/manifest"
        )
        XCTAssertNil(sheets.first?.title)
    }

    func testCreateCapturePostsToSheetCapturesPathAndDecodesCaptureID() async throws {
        let transport = StubTransport(
            response: Self.jsonResponse(.created, #"{"capture_id":"42"}"#)
        )
        let client = Self.makeClient(transport)

        let output = try await client.colorMatchingWeb_CaptureController_create(
            .init(path: .init(sheetId: "lps-7f3a"), body: .json(.init()))
        )

        XCTAssertEqual(transport.recorded?.method, "POST")
        XCTAssertEqual(transport.recorded?.path, "/api/v1/test_sheets/lps-7f3a/captures")
        XCTAssertEqual(transport.recorded?.operationID, "ColorMatchingWeb.CaptureController.create")
        guard case .created(let created) = output else { return XCTFail("Expected .created response") }
        XCTAssertEqual(try created.body.json.captureId, "42")
    }

    func testUploadMeasurementsEncodesRgbPayloadVariantsAndDecodesCounts() async throws {
        let transport = StubTransport(
            response: Self.jsonResponse(
                .ok,
                #"{"capture_id":"42","measurement_count":2,"pair_score_count":1}"#
            )
        )
        let client = Self.makeClient(transport)
        let objectRGB = Components.Schemas.RgbPayload(value2: .init(r: 0.12, g: 0.1, b: 0.02))

        let output = try await client.colorMatchingWeb_CaptureController_uploadMeasurements(
            .init(
                path: .init(captureId: "42"),
                body: .json(
                    .init(
                        measurements: [
                            .init(
                                patchId: "pair_1#first",
                                linearRgbMedian: objectRGB,
                                normalizedLinearRgbMedian: objectRGB
                            ),
                            .init(
                                patchId: "pair_1#second",
                                linearRgbMedian: Components.Schemas.RgbPayload(value1: [0.02, 0.1, 0.12]),
                                normalizedLinearRgbMedian: Components.Schemas.RgbPayload(value3: "0.02,0.1,0.12")
                            )
                        ]
                    )
                )
            )
        )

        XCTAssertEqual(transport.recorded?.method, "POST")
        XCTAssertEqual(transport.recorded?.path, "/api/v1/captures/42/measurements")
        XCTAssertEqual(transport.recorded?.operationID, "ColorMatchingWeb.CaptureController.upload_measurements")
        let json = try XCTUnwrap(Self.jsonObject(from: transport.recorded?.body) as? [String: Any])
        let measurements = try XCTUnwrap(json["measurements"] as? [[String: Any]])
        XCTAssertEqual(measurements.count, 2)
        XCTAssertEqual(measurements[0]["patch_id"] as? String, "pair_1#first")
        let median = try XCTUnwrap(measurements[0]["linear_rgb_median"] as? [String: Any])
        XCTAssertEqual(median["r"] as? Double ?? -1, 0.12, accuracy: 0.0001)
        XCTAssertEqual(median["g"] as? Double ?? -1, 0.1, accuracy: 0.0001)
        XCTAssertEqual(median["b"] as? Double ?? -1, 0.02, accuracy: 0.0001)
        XCTAssertEqual(measurements[1]["linear_rgb_median"] as? [Double] ?? [], [0.02, 0.1, 0.12])
        XCTAssertEqual(measurements[1]["normalized_linear_rgb_median"] as? String, "0.02,0.1,0.12")
        guard case .ok(let ok) = output else { return XCTFail("Expected .ok response") }
        let accepted = try ok.body.json
        XCTAssertEqual(accepted.captureId, "42")
        XCTAssertEqual(accepted.measurementCount, 2)
        XCTAssertEqual(accepted.pairScoreCount, 1)
    }

    func testUploadJudgmentsEncodesPairJudgmentsAndDecodesCount() async throws {
        let transport = StubTransport(
            response: Self.jsonResponse(.ok, #"{"capture_id":"42","judgment_count":1}"#)
        )
        let client = Self.makeClient(transport)

        let output = try await client.colorMatchingWeb_CaptureController_uploadJudgments(
            .init(
                path: .init(captureId: "42"),
                body: .json(.init(judgments: [.init(pairId: "pair_1", judgment: "near_match")]))
            )
        )

        XCTAssertEqual(transport.recorded?.method, "POST")
        XCTAssertEqual(transport.recorded?.path, "/api/v1/captures/42/judgments")
        XCTAssertEqual(transport.recorded?.operationID, "ColorMatchingWeb.CaptureController.upload_judgments")
        let json = try XCTUnwrap(Self.jsonObject(from: transport.recorded?.body) as? [String: Any])
        let judgments = try XCTUnwrap(json["judgments"] as? [[String: Any]])
        XCTAssertEqual(judgments.count, 1)
        XCTAssertEqual(judgments.first?["pair_id"] as? String, "pair_1")
        XCTAssertEqual(judgments.first?["judgment"] as? String, "near_match")
        guard case .ok(let ok) = output else { return XCTFail("Expected .ok response") }
        let accepted = try ok.body.json
        XCTAssertEqual(accepted.captureId, "42")
        XCTAssertEqual(accepted.judgmentCount, 1)
    }

    func testRankedResultsDecodesDocumentedFieldsFromFullServerPayload() async throws {
        let transport = StubTransport(response: Self.jsonResponse(.ok, Self.rankedResultsJSON))
        let client = Self.makeClient(transport)

        let output = try await client.colorMatchingWeb_TestSheetController_rankedResults(
            .init(path: .init(sheetId: "lps-7f3a"))
        )

        XCTAssertEqual(transport.recorded?.method, "GET")
        XCTAssertEqual(transport.recorded?.path, "/api/v1/test_sheets/lps-7f3a/ranked_results")
        XCTAssertEqual(transport.recorded?.operationID, "ColorMatchingWeb.TestSheetController.ranked_results")
        guard case .ok(let ok) = output else { return XCTFail("Expected .ok response") }
        let results = try ok.body.json
        XCTAssertEqual(results.schemaVersion, .lpsRankedResultsV1)
        XCTAssertEqual(results.sheetId, "lps-7f3a")
    }

    private static func makeClient(_ transport: StubTransport) -> Client {
        Client(serverURL: serverURL, transport: transport)
    }

    private static func jsonResponse(_ status: HTTPResponse.Status, _ payload: String) -> (HTTPResponse, HTTPBody) {
        (
            HTTPResponse(status: status, headerFields: [.contentType: "application/json"]),
            HTTPBody(Data(payload.utf8))
        )
    }

    private static func jsonObject(from data: Data?) throws -> Any {
        try JSONSerialization.jsonObject(with: XCTUnwrap(data))
    }

    private static let manifestJSON = """
        {
          "schema_version": "lps-sheet-manifest/v1",
          "sheet_id": "lps-7f3a",
          "sheet_version": "lps-letter-grid-v1",
          "manifest_url": "https://color-matching.example.test/api/v1/test_sheets/lps-7f3a/manifest",
          "created_at": "2026-10-01T12:00:00Z",
          "page": {"units": "mm", "width": 215.9, "height": 279.4},
          "registration_markers": [
            {"role": "top_left", "shape": "solid_square", "rect": {"x": 12, "y": 12, "width": 8, "height": 8}}
          ],
          "printer_profile": {
            "printer_make_model": "SureColor P700",
            "paper_type": "Premium Luster",
            "ink_type": "UltraChrome HD",
            "icc_profile": null,
            "print_settings": {},
            "driver_name": null,
            "driver_version": null,
            "calibration_date": null,
            "calibration_version": null,
            "notes": null
          },
          "capture_profile": {
            "expected_illuminant": "low_pressure_sodium",
            "preferred_camera": "built_in_wide_angle_rear",
            "scoring_algorithm_version": "lps-distance-v1"
          },
          "patches": [
            {
              "id": "pair_1#first",
              "role": "pair_color",
              "pair_id": "pair_1",
              "pair_side": "first",
              "reference_role": null,
              "source_color": "#FF0000",
              "safe_inset_mm": 1.5,
              "rect": {"x": 16, "y": 38, "width": 16, "height": 10}
            },
            {
              "id": "pair_1#second",
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
              "first_patch_id": "pair_1#first",
              "second_patch_id": "pair_1#second",
              "source_colors": ["#FF0000", "#00FF00"],
              "grid_row": 0,
              "grid_col": 1
            }
          ]
        }
        """

    private static let rankedResultsJSON = """
        {
          "schema_version": "lps-ranked-results/v1",
          "sheet_id": "lps-7f3a",
          "printer_profile": {
            "printer_make_model": "SureColor P700",
            "paper_type": "Premium Luster",
            "ink_type": "UltraChrome HD",
            "icc_profile": null,
            "print_settings": {},
            "driver_name": null,
            "driver_version": null,
            "calibration_date": null,
            "calibration_version": null,
            "notes": null
          },
          "capture_count": 2,
          "latest_capture_at": "2026-10-20T09:30:00Z",
          "earliest_capture_at": "2026-10-19T18:05:00Z",
          "scoring_algorithm_versions": ["lps-distance-v1"],
          "results": [
            {
              "rank": 1,
              "pair_id": "pair_1",
              "scoring_algorithm_version": "lps-distance-v1",
              "row": 0,
              "col": 1,
              "source_colors": {"color_a_hex": "#FF0000", "color_b_hex": "#00FF00"},
              "score": {
                "average": 0.035,
                "latest": 0.031,
                "minimum": 0.031,
                "maximum": 0.039,
                "capture_count": 2,
                "sample_count": 2,
                "algorithm_versions": ["lps-distance-v1"]
              },
              "current_judgment": "near_match",
              "current_judgment_observed_at": "2026-10-20T09:31:00Z",
              "observation_count": 1,
              "latest_observation": {"judgment": "near_match", "observed_at": "2026-10-20T09:31:00Z"},
              "capture_count": 2,
              "latest_capture_at": "2026-10-20T09:30:00Z",
              "earliest_capture_at": "2026-10-19T18:05:00Z"
            }
          ]
        }
        """
}

private final class StubTransport: ClientTransport, @unchecked Sendable {
    struct RecordedRequest {
        let method: String
        let path: String
        let operationID: String
        let body: Data?
    }

    private let response: (HTTPResponse, HTTPBody)
    private(set) var recorded: RecordedRequest?

    init(response: (HTTPResponse, HTTPBody)) {
        self.response = response
    }

    func send(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String
    ) async throws -> (HTTPResponse, HTTPBody?) {
        var bodyData: Data?
        if let body {
            bodyData = try await Data(collecting: body, upTo: 1_048_576)
        }
        recorded = RecordedRequest(
            method: request.method.rawValue,
            path: request.path,
            operationID: operationID,
            body: bodyData
        )
        return response
    }
}
