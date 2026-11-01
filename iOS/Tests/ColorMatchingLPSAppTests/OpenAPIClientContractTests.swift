#if canImport(OpenAPIClient) && canImport(OpenAPIRuntime)
import Foundation
import OpenAPIClient
import OpenAPIRuntime
import XCTest

/// Exercises the swift-openapi-generator client generated from the vendored
/// document at `iOS/Sources/OpenAPIClient/openapi.json` against a stubbed
/// `ClientTransport` — no live server (issue #5).
///
/// These tests only compile once the package wires the `OpenAPIClient` target
/// (generator plugin + OpenAPIRuntime); the `#if canImport` gate keeps the
/// red-phase suite building before that lands. The vendored document's
/// operationIds (`getTestSheetManifest`, `listRecentTestSheets`,
/// `getTestSheetRankedResults`, `createCaptureSession`, `uploadMeasurements`,
/// `uploadJudgments`) become the generated method names asserted here.
///
/// Response fixtures mirror the JSON actually rendered by
/// `ColorMatchingWeb.TestSheetJSON` / `ColorMatchingWeb.CaptureController` in
/// viamin/color_matching — including the 201/200 statuses and JSON bodies the
/// published spec declares (which the prose contract did not).
final class OpenAPIClientContractTests: XCTestCase {
    private var transport: StubTransport!

    override func setUp() {
        super.setUp()
        transport = StubTransport()
    }

    // MARK: - Test-sheet manifest

    func testGetTestSheetManifestDecodesServerRenderedPayload() async throws {
        transport.responseBody = Self.manifestJSON

        let output = try await makeClient().getTestSheetManifest(
            .init(path: .init(sheet_id: "sheet_1"), headers: .init(authorization: .bearer("token")))
        )

        guard case .ok(let ok) = output else {
            return XCTFail("Expected a 200 ok output for the manifest fetch")
        }
        guard case .json(let manifest) = ok.body else {
            return XCTFail("Expected a JSON manifest body")
        }

        XCTAssertEqual(manifest.schema_version, "lps-sheet-manifest/v1")
        XCTAssertEqual(manifest.sheet_id, "sheet_1")
        XCTAssertEqual(manifest.sheet_version, "lps-letter-grid-v1")
        XCTAssertEqual(manifest.manifest_url, "/api/v1/test_sheets/sheet_1/manifest")
        XCTAssertNotNil(manifest.created_at)
        XCTAssertEqual(manifest.page.units, "mm")
        XCTAssertEqual(manifest.registration_markers.first?.role, "top_left")
        XCTAssertEqual(manifest.printer_profile.printer_make_model, "Research printer")
        XCTAssertEqual(manifest.printer_profile.paper_type, "paper name")
        XCTAssertEqual(manifest.printer_profile.ink_type, "ink set")
        XCTAssertEqual(manifest.capture_profile.scoring_algorithm_version, "lps-distance-v1")
        XCTAssertEqual(manifest.patches.map(\.id), ["pair_1#first", "pair_1#second"])
        XCTAssertNil(manifest.patches.first?.reference_role)
        XCTAssertEqual(manifest.patches.first?.rect.x ?? 0, 16, accuracy: 0.0001)
        XCTAssertEqual(manifest.pairs.first?.first_patch_id, "pair_1#first")
        XCTAssertEqual(manifest.pairs.first?.second_patch_id, "pair_1#second")
        XCTAssertEqual(manifest.pairs.first?.source_colors, ["#FF0000", "#00FF00"])

        let sent = try XCTUnwrap(transport.sentRequests.first)
        XCTAssertEqual(sent.request.method, .get)
        XCTAssertEqual(sent.request.path, "/api/v1/test_sheets/sheet_1/manifest")
        XCTAssertEqual(sent.request.headerFields[.authorization], "Bearer token")
        XCTAssertEqual(sent.operationID, "getTestSheetManifest")
        XCTAssertEqual(sent.baseURL, URL(string: "https://example.test"))
    }

    // MARK: - Recent sheets

    func testListRecentTestSheetsDecodesNullableTitle() async throws {
        transport.responseBody = Self.recentSheetsJSON

        let output = try await makeClient().listRecentTestSheets(
            .init(headers: .init(authorization: .bearer("token")))
        )

        guard case .ok(let ok) = output else {
            return XCTFail("Expected a 200 ok output for recent sheets")
        }
        guard case .json(let recent) = ok.body else {
            return XCTFail("Expected a JSON recent-sheets body")
        }

        XCTAssertEqual(recent.sheets.count, 2)
        XCTAssertEqual(recent.sheets[0].sheet_id, "sheet_1")
        XCTAssertNil(recent.sheets[0].title, "The Phoenix app renders title as null today")
        XCTAssertEqual(recent.sheets[0].manifest_url, "/api/v1/test_sheets/sheet_1/manifest")
        XCTAssertEqual(recent.sheets[1].title, "July LPS comparison sheet")

        let sent = try XCTUnwrap(transport.sentRequests.first)
        XCTAssertEqual(sent.request.method, .get)
        XCTAssertEqual(sent.request.path, "/api/v1/test_sheets/recent")
        XCTAssertEqual(sent.request.headerFields[.authorization], "Bearer token")
        XCTAssertEqual(sent.operationID, "listRecentTestSheets")
    }

    // MARK: - Capture session creation

    func testCreateCaptureSessionEncodesNestedMetadataAndQuality() async throws {
        transport.responseStatus = .created
        transport.responseBody = #"{"capture_id": "42"}"#

        let output = try await makeClient().createCaptureSession(
            .init(
                path: .init(sheet_id: "sheet_1"),
                headers: .init(authorization: .bearer("token")),
                body: .json(Self.captureRequest)
            )
        )

        guard case .created(let created) = output else {
            return XCTFail("Expected a 201 created output for capture creation")
        }
        guard case .json(let payload) = created.body else {
            return XCTFail("Expected a JSON capture-created body")
        }
        XCTAssertEqual(payload.capture_id, "42")

        let sent = try XCTUnwrap(transport.sentRequests.first)
        XCTAssertEqual(sent.request.method, .post)
        XCTAssertEqual(sent.request.path, "/api/v1/test_sheets/sheet_1/captures")
        XCTAssertEqual(sent.operationID, "createCaptureSession")

        let json = try XCTUnwrap(Self.jsonObject(sent.body) as? [String: Any])
        let metadata = try XCTUnwrap(json["metadata"] as? [String: Any])
        XCTAssertEqual(metadata["device_model"] as? String, "iPhone")
        XCTAssertEqual(metadata["lens"] as? String, "built_in_wide_angle")
        XCTAssertEqual(metadata["exposure_duration_seconds"] as? Double, 0.016)
        XCTAssertEqual(metadata["iso"] as? Int, 100, "The published spec declares iso as an integer")
        XCTAssertEqual(metadata["focus_lens_position"] as? Double, 0.42)
        XCTAssertEqual(metadata["image_width"] as? Int, 4032)
        XCTAssertEqual(metadata["image_height"] as? Int, 3024)
        XCTAssertEqual(metadata["app_version"] as? String, "0.1.0")
        XCTAssertNotNil(metadata["timestamp"], "timestamp must be encoded as a date-time string")
        let gains = try XCTUnwrap(metadata["white_balance_gains"] as? [String: Any])
        XCTAssertEqual(gains["red"] as? Double ?? -1, 1.1, accuracy: 0.0001)

        let quality = try XCTUnwrap(json["quality"] as? [String: Any])
        XCTAssertEqual(quality["detected_marker_count"] as? Int, 4)
        XCTAssertEqual(quality["blur_score"] as? Double ?? -1, 0.82, accuracy: 0.0001)
        XCTAssertEqual(quality["rejections"] as? [String], [])
    }

    // MARK: - Measurement upload

    func testUploadMeasurementsEncodesAppPayloadAndDecodesCounts() async throws {
        transport.responseBody = #"{"capture_id": "42", "measurement_count": 1, "pair_score_count": 1}"#

        let output = try await makeClient().uploadMeasurements(
            .init(
                path: .init(capture_id: "42"),
                headers: .init(authorization: .bearer("token")),
                body: .json(Self.measurementUpload)
            )
        )

        guard case .ok(let ok) = output else {
            return XCTFail("Expected a 200 ok output for the measurement upload")
        }
        guard case .json(let accepted) = ok.body else {
            return XCTFail("Expected a JSON measurement-upload body")
        }
        XCTAssertEqual(accepted.capture_id, "42")
        XCTAssertEqual(accepted.measurement_count, 1)
        XCTAssertEqual(accepted.pair_score_count, 1)

        let sent = try XCTUnwrap(transport.sentRequests.first)
        XCTAssertEqual(sent.request.method, .post)
        XCTAssertEqual(sent.request.path, "/api/v1/captures/42/measurements")
        XCTAssertEqual(sent.operationID, "uploadMeasurements")

        let json = try XCTUnwrap(Self.jsonObject(sent.body) as? [String: Any])
        XCTAssertEqual(json["scoring_algorithm_version"] as? String, "lps-distance-v1")
        let measurement = try XCTUnwrap((json["measurements"] as? [[String: Any]])?.first)
        XCTAssertEqual(measurement["patch_id"] as? String, "pair_1#first")
        let linearMedian = try XCTUnwrap(measurement["linear_rgb_median"] as? [String: Any])
        XCTAssertEqual(linearMedian["r"] as? Double ?? -1, 0.12, accuracy: 0.0001)
        let stats = try XCTUnwrap(measurement["stats"] as? [String: Any])
        XCTAssertEqual(stats["sample_count"] as? Int, 900)
        XCTAssertEqual(stats["clipping_fraction"] as? Double ?? -1, 0, accuracy: 0.0001)
        let normalizedMedian = try XCTUnwrap(measurement["normalized_linear_rgb_median"] as? [String: Any])
        XCTAssertNotNil(normalizedMedian["g"], "The published spec requires normalized_linear_rgb_median")
        let score = try XCTUnwrap((json["pair_scores"] as? [[String: Any]])?.first)
        XCTAssertEqual(score["pair_id"] as? String, "pair_1")
        XCTAssertEqual(score["algorithm_version"] as? String, "lps-distance-v1")
        XCTAssertEqual(score["distance"] as? Double ?? -1, 0.035, accuracy: 0.0001)
        XCTAssertEqual(score["similarity"] as? Double ?? -1, 0.965, accuracy: 0.0001)
    }

    // MARK: - Judgment upload

    func testUploadJudgmentsEncodesPayloadAndDecodesCount() async throws {
        transport.responseBody = #"{"capture_id": "42", "judgment_count": 1}"#

        let output = try await makeClient().uploadJudgments(
            .init(
                path: .init(capture_id: "42"),
                headers: .init(authorization: .bearer("token")),
                body: .json(
                    .init(judgments: [.init(pair_id: "pair_1", judgment: "near_match")])
                )
            )
        )

        guard case .ok(let ok) = output else {
            return XCTFail("Expected a 200 ok output for the judgment upload")
        }
        guard case .json(let accepted) = ok.body else {
            return XCTFail("Expected a JSON judgment-upload body")
        }
        XCTAssertEqual(accepted.capture_id, "42")
        XCTAssertEqual(accepted.judgment_count, 1)

        let sent = try XCTUnwrap(transport.sentRequests.first)
        XCTAssertEqual(sent.request.method, .post)
        XCTAssertEqual(sent.request.path, "/api/v1/captures/42/judgments")
        XCTAssertEqual(sent.operationID, "uploadJudgments")

        let json = try XCTUnwrap(Self.jsonObject(sent.body) as? [String: Any])
        let judgment = try XCTUnwrap((json["judgments"] as? [[String: Any]])?.first)
        XCTAssertEqual(judgment["pair_id"] as? String, "pair_1")
        XCTAssertEqual(judgment["judgment"] as? String, "near_match")
    }

    // MARK: - Ranked results

    func testGetTestSheetRankedResultsDecodesRenderedPayload() async throws {
        transport.responseBody = Self.rankedResultsJSON

        let output = try await makeClient().getTestSheetRankedResults(
            .init(path: .init(sheet_id: "sheet_1"), headers: .init(authorization: .bearer("token")))
        )

        guard case .ok(let ok) = output else {
            return XCTFail("Expected a 200 ok output for ranked results")
        }
        guard case .json(let ranked) = ok.body else {
            return XCTFail("Expected a JSON ranked-results body")
        }

        XCTAssertEqual(ranked.schema_version, "lps-ranked-results/v1")
        XCTAssertEqual(ranked.sheet_id, "sheet_1")
        XCTAssertEqual(ranked.capture_count, 3)
        XCTAssertEqual(ranked.scoring_algorithm_versions, ["lps-distance-v1"])
        XCTAssertEqual(ranked.printer_profile.paper_type, "paper name")

        let best = try XCTUnwrap(ranked.results.first)
        XCTAssertEqual(best.rank, 1)
        XCTAssertEqual(best.pair_id, "pair_1")
        XCTAssertEqual(best.scoring_algorithm_version, "lps-distance-v1")
        XCTAssertEqual(best.source_colors.color_a_hex, "#FF0000")
        XCTAssertEqual(best.source_colors.color_b_hex, "#00FF00")
        XCTAssertEqual(best.score.average ?? -1, 0.035, accuracy: 0.0001)
        XCTAssertEqual(best.score.capture_count, 2)
        XCTAssertEqual(best.current_judgment, "near_match")
        XCTAssertEqual(best.observation_count, 2)
        XCTAssertNotNil(best.latest_capture_at)

        let other = try XCTUnwrap(ranked.results.last)
        XCTAssertNil(other.current_judgment, "current_judgment must be nullable")

        let sent = try XCTUnwrap(transport.sentRequests.first)
        XCTAssertEqual(sent.request.method, .get)
        XCTAssertEqual(sent.request.path, "/api/v1/test_sheets/sheet_1/ranked_results")
        XCTAssertEqual(sent.operationID, "getTestSheetRankedResults")
    }

    // MARK: - Fixtures

    private func makeClient() -> Client {
        Client(serverURL: URL(string: "https://example.test")!, transport: transport!)
    }

    private static var captureRequest: Components.Schemas.CaptureRequest {
        .init(
            metadata: .init(
                device_model: "iPhone",
                lens: "built_in_wide_angle",
                exposure_duration_seconds: 0.016,
                iso: 100,
                focus_lens_position: 0.42,
                white_balance_gains: .init(red: 1.1, green: 1.0, blue: 1.2),
                image_width: 4032,
                image_height: 3024,
                app_version: "0.1.0",
                timestamp: Date(timeIntervalSince1970: 0)
            ),
            quality: .init(detected_marker_count: 4, blur_score: 0.82, rejections: [])
        )
    }

    private static var measurementUpload: Components.Schemas.MeasurementUploadRequest {
        .init(
            scoring_algorithm_version: "lps-distance-v1",
            measurements: [
                .init(
                    patch_id: "pair_1#first",
                    linear_rgb_median: .init(r: 0.12, g: 0.1, b: 0.02),
                    normalized_linear_rgb_median: .init(r: 0.15, g: 0.12, b: 0.02),
                    stats: .init(
                        sample_count: 900,
                        clipping_fraction: 0,
                        mean: .init(r: 0.12, g: 0.1, b: 0.02),
                        standard_deviation: .init(r: 0.01, g: 0.01, b: 0.004)
                    )
                )
            ],
            pair_scores: [
                .init(
                    pair_id: "pair_1",
                    algorithm_version: "lps-distance-v1",
                    distance: 0.035,
                    similarity: 0.965
                )
            ]
        )
    }

    private static let manifestJSON = #"""
    {
      "schema_version": "lps-sheet-manifest/v1",
      "sheet_id": "sheet_1",
      "sheet_version": "lps-letter-grid-v1",
      "manifest_url": "/api/v1/test_sheets/sheet_1/manifest",
      "created_at": "2026-07-25T12:00:00Z",
      "page": {"units": "mm", "width": 215.9, "height": 279.4},
      "registration_markers": [
        {"role": "top_left", "shape": "solid_square", "rect": {"x": 12, "y": 12, "width": 8, "height": 8}}
      ],
      "printer_profile": {
        "printer_make_model": "Research printer",
        "paper_type": "paper name",
        "ink_type": "ink set"
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
          "rect": {"x": 40, "y": 38, "width": 16, "height": 10}
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
    """#

    private static let recentSheetsJSON = #"""
    {
      "sheets": [
        {
          "sheet_id": "sheet_1",
          "manifest_url": "/api/v1/test_sheets/sheet_1/manifest",
          "title": null
        },
        {
          "sheet_id": "sheet_2",
          "manifest_url": "/api/v1/test_sheets/sheet_2/manifest",
          "title": "July LPS comparison sheet"
        }
      ]
    }
    """#

    /// Mirrors `ColorMatchingWeb.TestSheetJSON.ranked_results/1`.
    private static let rankedResultsJSON = #"""
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
      "capture_count": 3,
      "latest_capture_at": "2026-07-26T09:30:00Z",
      "earliest_capture_at": "2026-07-25T12:00:00Z",
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
            "latest": 0.034,
            "minimum": 0.03,
            "maximum": 0.04,
            "capture_count": 2,
            "sample_count": 2,
            "algorithm_versions": ["lps-distance-v1"]
          },
          "current_judgment": "near_match",
          "current_judgment_observed_at": "2026-07-26T10:00:00Z",
          "observation_count": 2,
          "latest_observation": {"judgment": "near_match", "observed_at": "2026-07-26T10:00:00Z"},
          "capture_count": 2,
          "latest_capture_at": "2026-07-26T09:30:00Z",
          "earliest_capture_at": "2026-07-25T12:00:00Z"
        },
        {
          "rank": 2,
          "pair_id": "pair_2",
          "scoring_algorithm_version": "lps-distance-v1",
          "row": 1,
          "col": 1,
          "source_colors": {"color_a_hex": "#0000FF", "color_b_hex": "#00FFFF"},
          "score": {
            "average": 0.21,
            "latest": 0.2,
            "minimum": 0.19,
            "maximum": 0.24,
            "capture_count": 2,
            "sample_count": 2,
            "algorithm_versions": ["lps-distance-v1"]
          },
          "current_judgment": null,
          "current_judgment_observed_at": null,
          "observation_count": 0,
          "latest_observation": null,
          "capture_count": 2,
          "latest_capture_at": "2026-07-26T09:30:00Z",
          "earliest_capture_at": "2026-07-25T12:00:00Z"
        }
      ]
    }
    """#

    private static func jsonObject(_ data: Data?) throws -> Any {
        try JSONSerialization.jsonObject(with: XCTUnwrap(data))
    }
}

/// A `ClientTransport` that records outgoing requests and replays a canned
/// HTTP response — no network, no live server.
private final class StubTransport: ClientTransport, @unchecked Sendable {
    var responseStatus: HTTPResponse.Status = .ok
    var responseBody: String?
    private(set) var sentRequests: [SentRequest] = []

    struct SentRequest {
        let request: HTTPRequest
        let body: Data?
        let baseURL: URL
        let operationID: String
    }

    func send(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String
    ) async throws -> (HTTPResponse, HTTPBody?) {
        var collectedBody: Data?
        if let body {
            collectedBody = try await Data(collecting: body, upTo: 1 << 20)
        }
        sentRequests.append(
            SentRequest(request: request, body: collectedBody, baseURL: baseURL, operationID: operationID)
        )

        var fields = HTTPFields()
        if responseBody != nil {
            fields[.contentType] = "application/json"
        }
        return (
            HTTPResponse(status: responseStatus, headerFields: fields),
            responseBody.map { HTTPBody($0) }
        )
    }
}
#endif
