// Exercises the swift-openapi-generator client generated from
// docs/api/color-matching-openapi.v1.json against local stubbed HTTP responses
// (no live color_matching server). Part of #5: replace the hand-written API
// layer with a generated OpenAPI Swift client.
//
// This file intentionally references a client package ("ColorMatchingAPI")
// and runtime (OpenAPIRuntime/HTTPTypes) that are not yet vendored into
// iOS/Package.swift. It is expected to fail to compile until that dependency
// and the generated sources exist — see docs/openapi-contract-deltas.md for
// the operationId/module-name assumptions this file pins for that follow-up
// work.

import Foundation
import HTTPTypes
import OpenAPIRuntime
import XCTest
@testable import ColorMatchingAPI

final class GeneratedAPIClientTests: XCTestCase {
    private let baseURL = URL(string: "https://example.test")!

    // MARK: - GET /api/v1/test_sheets/{sheet_id}/manifest

    func testGetTestSheetManifestDecodesFullSchema() async throws {
        let transport = MockClientTransport { request, _, _, operationID in
            XCTAssertEqual(operationID, "getTestSheetManifest")
            XCTAssertEqual(request.method, .get)
            XCTAssertEqual(request.path, "/api/v1/test_sheets/ABCD-2345/manifest")
            XCTAssertEqual(request.headerFields[.authorization], "Bearer token")
            return (HTTPResponse(status: .ok), HTTPBody(Self.manifestFixture))
        }

        let client = Client(serverURL: baseURL, transport: transport)
        let output = try await client.getTestSheetManifest(.init(path: .init(sheet_id: "ABCD-2345")))

        guard case let .ok(ok) = output, case let .json(manifest) = ok.body else {
            return XCTFail("expected .ok(.json) output")
        }

        XCTAssertEqual(manifest.schema_version, .lps_sheet_manifest_v1)
        XCTAssertEqual(manifest.sheet_id, "ABCD-2345")
        XCTAssertEqual(manifest.capture_profile.scoring_algorithm_version, .lps_distance_v1)
        XCTAssertEqual(manifest.printer_profile.printer_make_model, "Epson SureColor P900")
        XCTAssertEqual(manifest.printer_profile.paper_type, "Ultra Premium Luster")
        XCTAssertEqual(manifest.registration_markers.count, 4)
        XCTAssertEqual(manifest.patches.count, manifest.pairs.count * 2)
        XCTAssertEqual(manifest.patches.first?.pair_side, .first)
        XCTAssertEqual(manifest.patches.first?.reference_role, nil)
    }

    func testGetTestSheetManifestSurfacesNotFound() async throws {
        let transport = MockClientTransport { _, _, _, _ in
            (HTTPResponse(status: .notFound), HTTPBody(#"{"errors":{"detail":"Sheet not found"}}"#))
        }

        let client = Client(serverURL: baseURL, transport: transport)
        let output = try await client.getTestSheetManifest(.init(path: .init(sheet_id: "UNKN-0000")))

        guard case .notFound = output else {
            return XCTFail("expected .notFound output")
        }
    }

    // MARK: - GET /api/v1/test_sheets/recent

    func testListRecentTestSheetsDecodesAlwaysNullTitle() async throws {
        let transport = MockClientTransport { request, _, _, operationID in
            XCTAssertEqual(operationID, "listRecentTestSheets")
            XCTAssertEqual(request.path, "/api/v1/test_sheets/recent")
            let json = #"{"sheets":[{"sheet_id":"RCNT-2345","manifest_url":"https://example.test/api/v1/test_sheets/RCNT-2345/manifest","title":null}]}"#
            return (HTTPResponse(status: .ok), HTTPBody(json))
        }

        let client = Client(serverURL: baseURL, transport: transport)
        let output = try await client.listRecentTestSheets(.init())

        guard case let .ok(ok) = output, case let .json(body) = ok.body else {
            return XCTFail("expected .ok(.json) output")
        }

        XCTAssertEqual(body.sheets.count, 1)
        XCTAssertEqual(body.sheets.first?.sheet_id, "RCNT-2345")
        XCTAssertNil(body.sheets.first?.title)
    }

    // MARK: - POST /api/v1/test_sheets/{sheet_id}/captures

    func testCreateCaptureEncodesNestedMetadataAndQuality() async throws {
        var capturedBody: Data?
        let transport = MockClientTransport { request, body, _, operationID in
            XCTAssertEqual(operationID, "createCapture")
            XCTAssertEqual(request.method, .post)
            XCTAssertEqual(request.path, "/api/v1/test_sheets/sheet_1/captures")
            capturedBody = try await body.map { try await Data(collecting: $0, upTo: .max) }
            return (HTTPResponse(status: .created), HTTPBody(#"{"capture_id":"cap_1"}"#))
        }

        let client = Client(serverURL: baseURL, transport: transport)
        let output = try await client.createCapture(.init(
            path: .init(sheet_id: "sheet_1"),
            body: .json(.init(
                metadata: .init(
                    device_model: "iPhone",
                    lens: "wide",
                    exposure_duration_seconds: 0.01,
                    iso: 100,
                    focus_lens_position: 0.4,
                    white_balance_gains: .init(red: 1.1, green: 1.0, blue: 1.2),
                    image_width: 100,
                    image_height: 200,
                    app_version: "0.1.0",
                    timestamp: Date(timeIntervalSince1970: 0)
                ),
                quality: .init(detected_marker_count: 4, blur_score: 0.75, rejections: [])
            ))
        ))

        guard case let .created(created) = output, case let .json(response) = created.body else {
            return XCTFail("expected .created(.json) output")
        }
        XCTAssertEqual(response.capture_id, "cap_1")

        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(capturedBody)) as? [String: Any])
        let metadata = try XCTUnwrap(json["metadata"] as? [String: Any])
        XCTAssertEqual(metadata["device_model"] as? String, "iPhone")
        let quality = try XCTUnwrap(json["quality"] as? [String: Any])
        XCTAssertEqual(quality["detected_marker_count"] as? Int, 4)
    }

    // MARK: - POST /api/v1/captures/{capture_id}/measurements

    func testUploadMeasurementsDecodesCountsResponse() async throws {
        var capturedBody: Data?
        let transport = MockClientTransport { request, body, _, operationID in
            XCTAssertEqual(operationID, "uploadMeasurements")
            XCTAssertEqual(request.path, "/api/v1/captures/cap_1/measurements")
            capturedBody = try await body.map { try await Data(collecting: $0, upTo: .max) }
            let json = #"{"capture_id":"cap_1","measurement_count":1,"pair_score_count":1}"#
            return (HTTPResponse(status: .ok), HTTPBody(json))
        }

        let client = Client(serverURL: baseURL, transport: transport)
        let output = try await client.uploadMeasurements(.init(
            path: .init(capture_id: "cap_1"),
            body: .json(.init(
                measurements: [.init(
                    patch_id: "patch_1",
                    linear_rgb_median: .init(r: 0.2, g: 0.3, b: 0.4),
                    normalized_linear_rgb_median: .init(r: 0.2, g: 0.3, b: 0.4),
                    stats: .init(
                        sample_count: 9,
                        clipping_fraction: 0,
                        mean: .init(r: 0.2, g: 0.3, b: 0.4),
                        standard_deviation: .init(r: 0.01, g: 0.01, b: 0.01)
                    )
                )],
                pair_scores: [.init(pair_id: "pair_1", algorithm_version: "lps-distance-v1", score: nil, similarity: 0.9, distance: nil)]
            ))
        ))

        guard case let .ok(ok) = output, case let .json(response) = ok.body else {
            return XCTFail("expected .ok(.json) output")
        }
        XCTAssertEqual(response.capture_id, "cap_1")
        XCTAssertEqual(response.measurement_count, 1)
        XCTAssertEqual(response.pair_score_count, 1)

        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(capturedBody)) as? [String: Any])
        let measurement = try XCTUnwrap((json["measurements"] as? [[String: Any]])?.first)
        XCTAssertEqual(measurement["patch_id"] as? String, "patch_1")
        // Per docs/openapi-contract-deltas.md delta #3: there is no top-level
        // scoring_algorithm_version in the real request schema.
        XCTAssertNil(json["scoring_algorithm_version"])
        let pairScore = try XCTUnwrap((json["pair_scores"] as? [[String: Any]])?.first)
        XCTAssertEqual(pairScore["algorithm_version"] as? String, "lps-distance-v1")
        XCTAssertEqual(pairScore["similarity"] as? Double, 0.9)
    }

    // MARK: - POST /api/v1/captures/{capture_id}/judgments

    func testUploadJudgmentsDecodesCountResponse() async throws {
        let transport = MockClientTransport { request, _, _, operationID in
            XCTAssertEqual(operationID, "uploadJudgments")
            XCTAssertEqual(request.path, "/api/v1/captures/cap_1/judgments")
            let json = #"{"capture_id":"cap_1","judgment_count":1}"#
            return (HTTPResponse(status: .ok), HTTPBody(json))
        }

        let client = Client(serverURL: baseURL, transport: transport)
        let output = try await client.uploadJudgments(.init(
            path: .init(capture_id: "cap_1"),
            body: .json(.init(judgments: [.init(pair_id: "pair_1", judgment: .near_match)]))
        ))

        guard case let .ok(ok) = output, case let .json(response) = ok.body else {
            return XCTFail("expected .ok(.json) output")
        }
        XCTAssertEqual(response.capture_id, "cap_1")
        XCTAssertEqual(response.judgment_count, 1)
    }

    // MARK: - GET /api/v1/test_sheets/{sheet_id}/ranked_results

    func testGetRankedResultsDecodesPerAlgorithmVersionRows() async throws {
        let transport = MockClientTransport { request, _, _, operationID in
            XCTAssertEqual(operationID, "getRankedResults")
            XCTAssertEqual(request.path, "/api/v1/test_sheets/RNKD-2362/ranked_results")
            return (HTTPResponse(status: .ok), HTTPBody(Self.rankedResultsFixture))
        }

        let client = Client(serverURL: baseURL, transport: transport)
        let output = try await client.getRankedResults(.init(path: .init(sheet_id: "RNKD-2362")))

        guard case let .ok(ok) = output, case let .json(body) = ok.body else {
            return XCTFail("expected .ok(.json) output")
        }

        XCTAssertEqual(body.schema_version, .lps_ranked_results_v1)
        XCTAssertEqual(body.scoring_algorithm_versions, ["ios-score/v1", "ios-score/v2"])
        // The same pair_id appears twice: once per scoring algorithm version
        // (docs/openapi-contract-deltas.md delta #2).
        XCTAssertEqual(body.results.count, 2)
        XCTAssertEqual(Set(body.results.map(\.pair_id)).count, 1)
        XCTAssertEqual(Set(body.results.map(\.scoring_algorithm_version)).count, 2)
        XCTAssertEqual(body.results.first?.score.algorithm_versions, ["ios-score/v1"])
    }

    // MARK: - Fixtures

    private static let manifestFixture = Data(#"""
    {
      "schema_version": "lps-sheet-manifest/v1",
      "sheet_version": "lps-letter-grid-v1",
      "sheet_id": "ABCD-2345",
      "manifest_url": "https://example.test/api/v1/test_sheets/ABCD-2345/manifest",
      "created_at": "2026-07-25T12:00:00Z",
      "page": {"units": "mm", "width": 215.9, "height": 279.4},
      "registration_markers": [
        {"role": "top_left", "shape": "solid_square", "rect": {"x": 12, "y": 12, "width": 8, "height": 8}},
        {"role": "top_right", "shape": "solid_square", "rect": {"x": 195, "y": 12, "width": 8, "height": 8}},
        {"role": "bottom_right", "shape": "solid_square", "rect": {"x": 195, "y": 259, "width": 8, "height": 8}},
        {"role": "bottom_left", "shape": "solid_square", "rect": {"x": 12, "y": 259, "width": 8, "height": 8}}
      ],
      "printer_profile": {
        "printer_make_model": "Epson SureColor P900",
        "paper_type": "Ultra Premium Luster",
        "ink_type": "OEM UltraChrome PRO10",
        "icc_profile": null,
        "print_settings": null,
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
        {"id": "pair_1#first", "role": "pair_color", "pair_id": "pair_1", "pair_side": "first", "reference_role": null, "source_color": "#FF0000", "safe_inset_mm": 1.5, "rect": {"x": 16, "y": 38, "width": 16, "height": 10}},
        {"id": "pair_1#second", "role": "pair_color", "pair_id": "pair_1", "pair_side": "second", "reference_role": null, "source_color": "#00FF00", "safe_inset_mm": 1.5, "rect": {"x": 36, "y": 38, "width": 16, "height": 10}}
      ],
      "pairs": [
        {"id": "pair_1", "first_patch_id": "pair_1#first", "second_patch_id": "pair_1#second", "source_colors": ["#FF0000", "#00FF00"], "grid_row": 0, "grid_col": 1}
      ]
    }
    """#.utf8)

    private static let rankedResultsFixture = Data(#"""
    {
      "schema_version": "lps-ranked-results/v1",
      "sheet_id": "RNKD-2362",
      "printer_profile": {
        "printer_make_model": "Epson SureColor P900",
        "paper_type": "Ultra Premium Luster",
        "ink_type": "OEM UltraChrome PRO10",
        "icc_profile": null,
        "print_settings": null,
        "driver_name": null,
        "driver_version": null,
        "calibration_date": null,
        "calibration_version": null,
        "notes": null
      },
      "capture_count": 1,
      "latest_capture_at": "2026-07-28T12:34:56.123456Z",
      "earliest_capture_at": "2026-07-28T12:34:56.123456Z",
      "scoring_algorithm_versions": ["ios-score/v1", "ios-score/v2"],
      "results": [
        {
          "rank": 1, "pair_id": "pair_1", "scoring_algorithm_version": "ios-score/v1", "row": 0, "col": 0,
          "source_colors": {"color_a_hex": "#FF0000", "color_b_hex": "#00FFFF"},
          "score": {"average": 0.9, "latest": 0.9, "minimum": 0.9, "maximum": 0.9, "capture_count": 1, "sample_count": 1, "algorithm_versions": ["ios-score/v1"]},
          "current_judgment": null, "current_judgment_observed_at": null, "observation_count": 0, "latest_observation": null,
          "capture_count": 1, "latest_capture_at": "2026-07-28T12:34:56.123456Z", "earliest_capture_at": "2026-07-28T12:34:56.123456Z"
        },
        {
          "rank": 2, "pair_id": "pair_1", "scoring_algorithm_version": "ios-score/v2", "row": 0, "col": 0,
          "source_colors": {"color_a_hex": "#FF0000", "color_b_hex": "#00FFFF"},
          "score": {"average": 0.7, "latest": 0.7, "minimum": 0.7, "maximum": 0.7, "capture_count": 1, "sample_count": 1, "algorithm_versions": ["ios-score/v2"]},
          "current_judgment": null, "current_judgment_observed_at": null, "observation_count": 0, "latest_observation": null,
          "capture_count": 1, "latest_capture_at": "2026-07-28T12:34:56.123456Z", "earliest_capture_at": "2026-07-28T12:34:56.123456Z"
        }
      ]
    }
    """#.utf8)
}

/// Stubs `OpenAPIRuntime.ClientTransport` with an injectable handler, standing
/// in for a live color_matching server in CI.
private struct MockClientTransport: ClientTransport {
    var handler: (HTTPRequest, HTTPBody?, URL, String) async throws -> (HTTPResponse, HTTPBody?)

    func send(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String
    ) async throws -> (HTTPResponse, HTTPBody?) {
        try await handler(request, body, baseURL, operationID)
    }
}
