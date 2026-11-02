import ColorMatchingOpenAPI
import Foundation
import OpenAPIRuntime
import XCTest

/// Exercises the generated OpenAPI client for every API surface the app uses
/// today, against local stubbed responses — no live server.
///
/// Request bodies are built by decoding canned wire JSON into the generated
/// types (rather than memberwise inits) because schema property order comes
/// from an Elixir map and is not stable across regenerations. The canned
/// fixtures mirror what the Phoenix app actually renders.
final class GeneratedClientTests: XCTestCase {
    private let serverURL = URL(string: "https://example.test")!

    func testFetchManifestDecodesTypedEnvelopeFields() async throws {
        let transport = StubTransport { _, _ in
            StubTransport.jsonResponse(.ok, Self.manifestJSON)
        }
        let client = Client(serverURL: serverURL, transport: transport)

        let output = try await client.colorMatchingWeb_TestSheetController_manifest(
            .init(path: .init(sheetId: "sheet_1"))
        )

        let request = try XCTUnwrap(transport.recordedRequests.first)
        XCTAssertEqual(request.operationID, "ColorMatchingWeb.TestSheetController.manifest")
        XCTAssertEqual(request.method, "GET")
        XCTAssertEqual(request.path, "/api/v1/test_sheets/sheet_1/manifest")

        guard case .ok(let response) = output else {
            return XCTFail("expected .ok, got \(output)")
        }
        guard case .json(let manifest) = response.body else {
            return XCTFail("expected JSON body, got \(response.body)")
        }
        XCTAssertEqual(manifest.schema_version.rawValue, "lps-sheet-manifest/v1")
        XCTAssertEqual(manifest.sheet_id, "sheet_1")
        XCTAssertEqual(manifest.capture_profile.scoring_algorithm_version.rawValue, "lps-distance-v1")
    }

    func testFetchRecentSheetsDecodesSheetsWithNullableTitle() async throws {
        let transport = StubTransport { _, _ in
            StubTransport.jsonResponse(
                .ok,
                #"{"sheets":[{"sheet_id":"sheet_1","manifest_url":"https://example.test/api/v1/test_sheets/sheet_1/manifest","title":null}]}"#
            )
        }
        let client = Client(serverURL: serverURL, transport: transport)

        let output = try await client.colorMatchingWeb_TestSheetController_recent(.init())

        let request = try XCTUnwrap(transport.recordedRequests.first)
        XCTAssertEqual(request.operationID, "ColorMatchingWeb.TestSheetController.recent")
        XCTAssertEqual(request.method, "GET")
        XCTAssertEqual(request.path, "/api/v1/test_sheets/recent")

        guard case .ok(let response) = output else {
            return XCTFail("expected .ok, got \(output)")
        }
        guard case .json(let body) = response.body else {
            return XCTFail("expected JSON body, got \(response.body)")
        }
        let sheet = try XCTUnwrap(body.sheets.first)
        XCTAssertEqual(sheet.sheetId, "sheet_1")
        XCTAssertEqual(sheet.manifestUrl, "https://example.test/api/v1/test_sheets/sheet_1/manifest")
        XCTAssertEqual(sheet.title, nil, "title is required-but-nullable; the server renders null when unnamed")
    }

    func testFetchRankedResultsDecodesVersionEnvelope() async throws {
        let transport = StubTransport { _, _ in
            StubTransport.jsonResponse(.ok, Self.rankedResultsJSON)
        }
        let client = Client(serverURL: serverURL, transport: transport)

        let output = try await client.colorMatchingWeb_TestSheetController_rankedResults(
            .init(path: .init(sheetId: "sheet_1"))
        )

        let request = try XCTUnwrap(transport.recordedRequests.first)
        XCTAssertEqual(request.operationID, "ColorMatchingWeb.TestSheetController.ranked_results")
        XCTAssertEqual(request.method, "GET")
        XCTAssertEqual(request.path, "/api/v1/test_sheets/sheet_1/ranked_results")

        guard case .ok(let response) = output else {
            return XCTFail("expected .ok, got \(output)")
        }
        guard case .json(let ranked) = response.body else {
            return XCTFail("expected JSON body, got \(response.body)")
        }
        XCTAssertEqual(ranked.schema_version.rawValue, "lps-ranked-results/v1")
        XCTAssertEqual(ranked.sheet_id, "sheet_1")
    }

    func testCreateCaptureSendsNestedMetadataQualityFormAndDecodesCaptureID() async throws {
        let transport = StubTransport { _, _ in
            StubTransport.jsonResponse(.created, #"{"capture_id":"capture_1"}"#)
        }
        let client = Client(serverURL: serverURL, transport: transport)
        let requestBody = try Self.decode(Components.Schemas.CaptureRequest.self, from: Self.createCaptureJSON)

        let output = try await client.colorMatchingWeb_CaptureController_create(
            .init(path: .init(sheetId: "sheet_1"), body: .json(requestBody))
        )

        let request = try XCTUnwrap(transport.recordedRequests.first)
        XCTAssertEqual(request.operationID, "ColorMatchingWeb.CaptureController.create")
        XCTAssertEqual(request.method, "POST")
        XCTAssertEqual(request.path, "/api/v1/test_sheets/sheet_1/captures")

        let json = try request.bodyJSON
        XCTAssertEqual(
            Set(json.keys),
            ["metadata", "quality"],
            "the app sends the nested metadata+quality form, not the flat anyOf variant"
        )
        let metadata = try XCTUnwrap(json["metadata"] as? [String: Any])
        XCTAssertEqual(metadata["device_model"] as? String, "iPhone 15")
        XCTAssertEqual(metadata["iso"] as? Int, 100)
        let gains = try XCTUnwrap(metadata["white_balance_gains"] as? [String: Any])
        XCTAssertEqual(try Self.rounded(gains["red"]), 1.2)
        XCTAssertTrue(
            try XCTUnwrap(metadata["timestamp"] as? String).hasPrefix("2026-07-25T12:00:00"),
            "timestamp must round-trip as an RFC 3339 string"
        )
        let quality = try XCTUnwrap(json["quality"] as? [String: Any])
        XCTAssertEqual(quality["detected_marker_count"] as? Int, 4)
        XCTAssertEqual(quality["rejections"] as? [String], [])

        guard case .created(let response) = output else {
            return XCTFail("expected .created, got \(output)")
        }
        guard case .json(let body) = response.body else {
            return XCTFail("expected JSON body, got \(response.body)")
        }
        XCTAssertEqual(body.capture_id, "capture_1")
    }

    func testUploadMeasurementsSendsSpecShapedPayloadAndDecodesCounts() async throws {
        let transport = StubTransport { _, _ in
            StubTransport.jsonResponse(
                .ok,
                #"{"capture_id":"capture_1","measurement_count":1,"pair_score_count":1}"#
            )
        }
        let client = Client(serverURL: serverURL, transport: transport)
        let requestBody = try Self.decode(
            Components.Schemas.MeasurementUploadRequest.self,
            from: Self.measurementUploadJSON
        )

        let output = try await client.colorMatchingWeb_CaptureController_uploadMeasurements(
            .init(path: .init(captureId: "capture_1"), body: .json(requestBody))
        )

        let request = try XCTUnwrap(transport.recordedRequests.first)
        XCTAssertEqual(request.operationID, "ColorMatchingWeb.CaptureController.upload_measurements")
        XCTAssertEqual(request.method, "POST")
        XCTAssertEqual(request.path, "/api/v1/captures/capture_1/measurements")

        let json = try request.bodyJSON
        XCTAssertEqual(
            Set(json.keys),
            ["measurements", "pair_scores"],
            "the published spec has no top-level scoring_algorithm_version; generated types make that drift visible here"
        )
        let measurement = try XCTUnwrap((json["measurements"] as? [[String: Any]])?.first)
        XCTAssertEqual(
            Set(measurement.keys),
            ["patch_id", "linear_rgb_median", "normalized_linear_rgb_median"],
            "the published spec drops the per-measurement stats object the hand-written client sent"
        )
        XCTAssertEqual(measurement["patch_id"] as? String, "pair_1#first")
        let linearMedian = try XCTUnwrap(measurement["linear_rgb_median"] as? [String: Any])
        XCTAssertEqual(try Self.rounded(linearMedian["r"]), 0.12)
        let pairScore = try XCTUnwrap((json["pair_scores"] as? [[String: Any]])?.first)
        XCTAssertEqual(pairScore["algorithm_version"] as? String, "lps-distance-v1")

        guard case .ok(let response) = output else {
            return XCTFail("expected .ok, got \(output)")
        }
        guard case .json(let body) = response.body else {
            return XCTFail("expected JSON body, got \(response.body)")
        }
        XCTAssertEqual(body.capture_id, "capture_1")
        XCTAssertEqual(body.measurement_count, 1)
        XCTAssertEqual(body.pair_score_count, 1)
    }

    func testUploadJudgmentsSendsPairJudgmentsAndDecodesCount() async throws {
        let transport = StubTransport { _, _ in
            StubTransport.jsonResponse(.ok, #"{"capture_id":"capture_1","judgment_count":1}"#)
        }
        let client = Client(serverURL: serverURL, transport: transport)
        let requestBody = try Self.decode(
            Components.Schemas.JudgmentUploadRequest.self,
            from: #"{"judgments":[{"pair_id":"pair_1","judgment":"near_match"}]}"#
        )

        let output = try await client.colorMatchingWeb_CaptureController_uploadJudgments(
            .init(path: .init(captureId: "capture_1"), body: .json(requestBody))
        )

        let request = try XCTUnwrap(transport.recordedRequests.first)
        XCTAssertEqual(request.operationID, "ColorMatchingWeb.CaptureController.upload_judgments")
        XCTAssertEqual(request.method, "POST")
        XCTAssertEqual(request.path, "/api/v1/captures/capture_1/judgments")
        let judgments = try XCTUnwrap(try request.bodyJSON["judgments"] as? [[String: Any]])
        let judgment = try XCTUnwrap(judgments.first)
        XCTAssertEqual(judgment["pair_id"] as? String, "pair_1")
        XCTAssertEqual(judgment["judgment"] as? String, "near_match")

        guard case .ok(let response) = output else {
            return XCTFail("expected .ok, got \(output)")
        }
        guard case .json(let body) = response.body else {
            return XCTFail("expected JSON body, got \(response.body)")
        }
        XCTAssertEqual(body.judgment_count, 1)
    }

    func testManifestNotFoundSurfacesAsTypedNotFoundCase() async throws {
        let transport = StubTransport { _, _ in
            StubTransport.jsonResponse(.notFound, #"{"errors":{"detail":"Sheet not found"}}"#)
        }
        let client = Client(serverURL: serverURL, transport: transport)

        let output = try await client.colorMatchingWeb_TestSheetController_manifest(
            .init(path: .init(sheetId: "missing"))
        )

        guard case .notFound = output else {
            return XCTFail("expected .notFound, got \(output)")
        }
    }

    // MARK: - Helpers

    private static func decode<T: Decodable>(_ type: T.Type, from json: String) throws -> T {
        try JSONDecoder().decode(type, from: Data(json.utf8))
    }

    private static func rounded(_ value: Any?) throws -> Double {
        let number = try XCTUnwrap(value as? NSNumber)
        return (number.doubleValue * 1000).rounded() / 1000
    }

    // Mirrors ColorMatchingWeb.TestSheetJSON.manifest/1 — including the
    // "pair_1#first" patch id format and the printer profile shape that omits
    // the prose contract's `id` and `name` keys.
    private static let manifestJSON = """
    {
      "schema_version": "lps-sheet-manifest/v1",
      "sheet_id": "sheet_1",
      "sheet_version": "lps-letter-grid-v1",
      "manifest_url": "https://example.test/api/v1/test_sheets/sheet_1/manifest",
      "created_at": "2026-07-25T12:00:00Z",
      "page": {"units": "mm", "width": 215.9, "height": 279.4},
      "registration_markers": [
        {"role": "top_left", "shape": "solid_square", "rect": {"x": 12, "y": 12, "width": 8, "height": 8}}
      ],
      "printer_profile": {
        "printer_make_model": "Research printer",
        "paper_type": "paper name",
        "ink_type": "ink set",
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

    private static let createCaptureJSON = """
    {
      "metadata": {
        "device_model": "iPhone 15",
        "lens": "built_in_wide_angle_rear",
        "exposure_duration_seconds": 0.016,
        "iso": 100,
        "focus_lens_position": 0.42,
        "white_balance_gains": {"red": 1.2, "green": 1.0, "blue": 1.4},
        "image_width": 4032,
        "image_height": 3024,
        "app_version": "0.1.0",
        "timestamp": "2026-07-25T12:00:00Z"
      },
      "quality": {"detected_marker_count": 4, "blur_score": 0.82, "rejections": []}
    }
    """

    private static let measurementUploadJSON = """
    {
      "measurements": [
        {
          "patch_id": "pair_1#first",
          "linear_rgb_median": {"r": 0.12, "g": 0.10, "b": 0.02},
          "normalized_linear_rgb_median": {"r": 0.15, "g": 0.12, "b": 0.02}
        }
      ],
      "pair_scores": [
        {
          "pair_id": "pair_1",
          "algorithm_version": "lps-distance-v1",
          "similarity": 0.965,
          "distance": 0.035
        }
      ]
    }
    """

    // Mirrors ColorMatchingWeb.TestSheetJSON.ranked_results/1.
    private static let rankedResultsJSON = """
    {
      "schema_version": "lps-ranked-results/v1",
      "sheet_id": "sheet_1",
      "printer_profile": {
        "printer_make_model": "Research printer",
        "paper_type": "paper name",
        "ink_type": "ink set",
        "icc_profile": null,
        "print_settings": {},
        "driver_name": null,
        "driver_version": null,
        "calibration_date": null,
        "calibration_version": null,
        "notes": null
      },
      "capture_count": 1,
      "latest_capture_at": "2026-07-25T12:05:00Z",
      "earliest_capture_at": "2026-07-25T12:05:00Z",
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
            "latest": 0.035,
            "minimum": 0.035,
            "maximum": 0.035,
            "capture_count": 1,
            "sample_count": 1,
            "algorithm_versions": ["lps-distance-v1"]
          },
          "current_judgment": "near_match",
          "current_judgment_observed_at": "2026-07-25T12:06:00Z",
          "observation_count": 1,
          "latest_observation": {"judgment": "near_match", "observed_at": "2026-07-25T12:06:00Z"},
          "capture_count": 1,
          "latest_capture_at": "2026-07-25T12:05:00Z",
          "earliest_capture_at": "2026-07-25T12:05:00Z"
        }
      ]
    }
    """
}
