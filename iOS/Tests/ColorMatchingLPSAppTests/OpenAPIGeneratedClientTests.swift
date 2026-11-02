import ColorMatchingOpenAPI
import Foundation
import HTTPTypes
import OpenAPIRuntime
import XCTest

/// Exercises the swift-openapi-generator client directly against locally
/// stubbed responses (no live server). One test per surface the app uses
/// today: test-sheet manifest, recent sheets, capture session creation,
/// measurement upload, judgment upload, and ranked results.
///
/// Generated names are deterministic given the vendored spec — see
/// docs/openapi-generated-client-plan.md for the operationId → method
/// mapping (e.g. `ColorMatchingWeb.TestSheetController.ranked_results` →
/// `colorMatchingWeb_TestSheetController_rankedResults`).
final class OpenAPIGeneratedClientTests: XCTestCase {
    private var transport: RecordedTransport!

    override func tearDown() {
        transport = nil
        super.tearDown()
    }

    private func makeClient(stub: @escaping RecordedTransport.Stub) -> ColorMatchingOpenAPI.Client {
        transport = RecordedTransport(stub: stub)
        return ColorMatchingOpenAPI.Client(
            serverURL: URL(string: "https://example.test")!,
            transport: transport
        )
    }

    func testManifestRequestsSheetPathAndDecodesGeneratedManifest() async throws {
        let client = makeClient { request, body, operationID in
            XCTAssertEqual(operationID, "ColorMatchingWeb.TestSheetController.manifest")
            XCTAssertEqual(request.method, .get)
            XCTAssertEqual(request.path, "/api/v1/test_sheets/sheet_1/manifest")
            XCTAssertNil(body)
            return Self.jsonResponse(.ok, Self.manifestJSON)
        }

        let output = try await client.colorMatchingWeb_TestSheetController_manifest(
            .init(path: .init(sheetId: "sheet_1"))
        )

        guard case .ok(let ok) = output else {
            return XCTFail("expected .ok, got \(output)")
        }
        let manifest = ok.body.json
        XCTAssertEqual(manifest.schemaVersion, "lps-sheet-manifest/v1")
        XCTAssertEqual(manifest.sheetId, "sheet_1")
        XCTAssertEqual(manifest.captureProfile?.scoringAlgorithmVersion, "lps-distance-v1")
        XCTAssertEqual(manifest.page?.units, "mm")
        XCTAssertEqual(manifest.registrationMarkers?.first?.role, "top_left")
        XCTAssertEqual(manifest.patches?.first?.id, "pair_1#first")
        XCTAssertEqual(manifest.patches?.first?.sourceColor, "#FF0000")
        XCTAssertEqual(manifest.patches?.first?.safeInsetMm, 1.5)
        XCTAssertEqual(manifest.pairs?.first?.firstPatchId, "pair_1#first")
    }

    func testRecentSheetsDecodesNullableTitle() async throws {
        let client = makeClient { request, _, operationID in
            XCTAssertEqual(operationID, "ColorMatchingWeb.TestSheetController.recent")
            XCTAssertEqual(request.path, "/api/v1/test_sheets/recent")
            return Self.jsonResponse(
                .ok,
                #"""
                {"sheets": [
                  {"sheet_id": "sheet_1", "manifest_url": "https://example.test/api/v1/test_sheets/sheet_1/manifest", "title": null},
                  {"sheet_id": "sheet_2", "manifest_url": "https://example.test/api/v1/test_sheets/sheet_2/manifest", "title": "July LPS comparison sheet"}
                ]}
                """#
            )
        }

        let output = try await client.colorMatchingWeb_TestSheetController_recent()

        guard case .ok(let ok) = output else {
            return XCTFail("expected .ok, got \(output)")
        }
        let sheets = ok.body.json.sheets
        XCTAssertEqual(sheets.count, 2)
        XCTAssertEqual(sheets.first?.sheetId, "sheet_1")
        XCTAssertEqual(sheets.first?.title, nil)
        XCTAssertEqual(sheets.last?.title, "July LPS comparison sheet")
        XCTAssertEqual(sheets.last?.manifestUrl, "https://example.test/api/v1/test_sheets/sheet_2/manifest")
    }

    func testCreateCaptureSendsNestedMetadataAndQuality() async throws {
        let client = makeClient { request, body, operationID in
            XCTAssertEqual(operationID, "ColorMatchingWeb.CaptureController.create")
            XCTAssertEqual(request.method, .post)
            XCTAssertEqual(request.path, "/api/v1/test_sheets/sheet_1/captures")
            let json = try Self.jsonObject(from: body)
            let metadata = try XCTUnwrap(json["metadata"] as? [String: Any])
            XCTAssertEqual(metadata["device_model"] as? String, "iPhone 16")
            XCTAssertEqual(metadata["iso"] as? Int, 100)
            let gains = try XCTUnwrap(metadata["white_balance_gains"] as? [String: Any])
            XCTAssertEqual(gains["red"] as? Double, 1.1)
            let quality = try XCTUnwrap(json["quality"] as? [String: Any])
            XCTAssertEqual(quality["detected_marker_count"] as? Int, 4)
            XCTAssertEqual(quality["rejections"] as? [String], [])
            return Self.jsonResponse(.created, #"{"capture_id": "capture_9"}"#)
        }

        let input = Operations.ColorMatchingWeb_CaptureController_create.Input(
            path: .init(sheetId: "sheet_1"),
            body: .json(
                .init(
                    metadata: .init(
                        deviceModel: "iPhone 16",
                        lens: "built_in_wide_angle",
                        exposureDurationSeconds: 0.016,
                        iso: 100,
                        focusLensPosition: 0.42,
                        whiteBalanceGains: .init(red: 1.1, green: 1.0, blue: 1.2),
                        imageWidth: 4032,
                        imageHeight: 3024,
                        appVersion: "0.1.0",
                        timestamp: "2026-07-25T12:00:00Z"
                    ),
                    quality: .init(detectedMarkerCount: 4, blurScore: 0.75, rejections: [])
                )
            )
        )

        let output = try await client.colorMatchingWeb_CaptureController_create(input)

        guard case .created(let created) = output else {
            return XCTFail("expected .created, got \(output)")
        }
        XCTAssertEqual(created.body.json.captureId, "capture_9")
    }

    func testUploadMeasurementsSendsPublishedShapeAndDecodesCounts() async throws {
        let client = makeClient { request, body, operationID in
            XCTAssertEqual(operationID, "ColorMatchingWeb.CaptureController.upload_measurements")
            XCTAssertEqual(request.method, .post)
            XCTAssertEqual(request.path, "/api/v1/captures/9/measurements")
            let json = try Self.jsonObject(from: body)
            // Delta D3: the published schema has no top-level
            // scoring_algorithm_version and no per-measurement stats.
            XCTAssertEqual(Set(json.keys), ["measurements", "pair_scores"])
            let measurement = try XCTUnwrap((json["measurements"] as? [[String: Any]])?.first)
            XCTAssertEqual(
                Set(measurement.keys),
                ["patch_id", "linear_rgb_median", "normalized_linear_rgb_median"]
            )
            XCTAssertEqual(measurement["patch_id"] as? String, "pair_1#first")
            let median = try XCTUnwrap(measurement["linear_rgb_median"] as? [String: Any])
            XCTAssertEqual(median["r"] as? Double, 0.12)
            let score = try XCTUnwrap((json["pair_scores"] as? [[String: Any]])?.first)
            XCTAssertEqual(score["pair_id"] as? String, "pair_1")
            XCTAssertEqual(score["algorithm_version"] as? String, "lps-distance-v1")
            XCTAssertEqual(score["similarity"] as? Double, 0.965)
            XCTAssertEqual(score["distance"] as? Double, 0.035)
            return Self.jsonResponse(
                .ok,
                #"{"capture_id": "9", "measurement_count": 1, "pair_score_count": 1}"#
            )
        }

        let input = Operations.ColorMatchingWeb_CaptureController_uploadMeasurements.Input(
            path: .init(captureId: "9"),
            body: .json(
                .init(
                    measurements: [
                        .init(
                            patchId: "pair_1#first",
                            linearRgbMedian: .init(r: 0.12, g: 0.10, b: 0.02),
                            normalizedLinearRgbMedian: .init(r: 0.15, g: 0.12, b: 0.02)
                        )
                    ],
                    pairScores: [
                        .init(
                            pairId: "pair_1",
                            algorithmVersion: "lps-distance-v1",
                            similarity: 0.965,
                            distance: 0.035
                        )
                    ]
                )
            )
        )

        let output = try await client.colorMatchingWeb_CaptureController_uploadMeasurements(input)

        guard case .ok(let ok) = output else {
            return XCTFail("expected .ok, got \(output)")
        }
        let accepted = ok.body.json
        XCTAssertEqual(accepted.captureId, "9")
        XCTAssertEqual(accepted.measurementCount, 1)
        XCTAssertEqual(accepted.pairScoreCount, 1)
    }

    func testUploadJudgmentsSendsPairJudgmentsAndDecodesCount() async throws {
        let client = makeClient { request, body, operationID in
            XCTAssertEqual(operationID, "ColorMatchingWeb.CaptureController.upload_judgments")
            XCTAssertEqual(request.method, .post)
            XCTAssertEqual(request.path, "/api/v1/captures/9/judgments")
            let json = try Self.jsonObject(from: body)
            XCTAssertEqual(Set(json.keys), ["judgments"])
            let judgment = try XCTUnwrap((json["judgments"] as? [[String: Any]])?.first)
            XCTAssertEqual(judgment["pair_id"] as? String, "pair_1")
            XCTAssertEqual(judgment["judgment"] as? String, "near_match")
            return Self.jsonResponse(.ok, #"{"capture_id": "9", "judgment_count": 1}"#)
        }

        let input = Operations.ColorMatchingWeb_CaptureController_uploadJudgments.Input(
            path: .init(captureId: "9"),
            body: .json(
                .init(judgments: [.init(pairId: "pair_1", judgment: "near_match")])
            )
        )

        let output = try await client.colorMatchingWeb_CaptureController_uploadJudgments(input)

        guard case .ok(let ok) = output else {
            return XCTFail("expected .ok, got \(output)")
        }
        XCTAssertEqual(ok.body.json.captureId, "9")
        XCTAssertEqual(ok.body.json.judgmentCount, 1)
    }

    func testRankedResultsDecodesAggregatePayload() async throws {
        let client = makeClient { request, _, operationID in
            XCTAssertEqual(operationID, "ColorMatchingWeb.TestSheetController.ranked_results")
            XCTAssertEqual(request.path, "/api/v1/test_sheets/sheet_1/ranked_results")
            return Self.jsonResponse(.ok, Self.rankedResultsJSON)
        }

        let output = try await client.colorMatchingWeb_TestSheetController_rankedResults(
            .init(path: .init(sheetId: "sheet_1"))
        )

        guard case .ok(let ok) = output else {
            return XCTFail("expected .ok, got \(output)")
        }
        let results = ok.body.json
        XCTAssertEqual(results.schemaVersion, "lps-ranked-results/v1")
        XCTAssertEqual(results.sheetId, "sheet_1")
        XCTAssertEqual(results.printerProfile?.inkType, "ink set")
        XCTAssertEqual(results.scoringAlgorithmVersions, ["lps-distance-v1"])
        let pair = try XCTUnwrap(results.results.first)
        XCTAssertEqual(pair.rank, 1)
        XCTAssertEqual(pair.pairId, "pair_1")
        XCTAssertEqual(pair.sourceColors.colorAHex, "#FF0000")
        XCTAssertEqual(pair.score.average, 0.04)
        XCTAssertEqual(pair.score.sampleCount, 2)
        XCTAssertEqual(pair.currentJudgment, "near_match")
        XCTAssertEqual(pair.latestObservation?.judgment, "near_match")
    }

    func testManifestNotFoundSurfacesGeneratedNotFoundCase() async throws {
        let client = makeClient { request, _, operationID in
            XCTAssertEqual(operationID, "ColorMatchingWeb.TestSheetController.manifest")
            XCTAssertEqual(request.path, "/api/v1/test_sheets/missing/manifest")
            return Self.jsonResponse(.notFound, #"{"errors": {"detail": "Sheet not found"}}"#)
        }

        let output = try await client.colorMatchingWeb_TestSheetController_manifest(
            .init(path: .init(sheetId: "missing"))
        )

        guard case .notFound = output else {
            return XCTFail("expected .notFound, got \(output)")
        }
    }

    func testUploadMeasurementsSurfacesGeneratedUnprocessableContentCase() async throws {
        let client = makeClient { _, _, _ in
            Self.jsonResponse(.unprocessableContent, #"{"errors": {"measurements": [{"patch_id": "pair_1#first", "index": 0}]}}"#)
        }

        let input = Operations.ColorMatchingWeb_CaptureController_uploadMeasurements.Input(
            path: .init(captureId: "9"),
            body: .json(.init(measurements: [], pairScores: []))
        )

        let output = try await client.colorMatchingWeb_CaptureController_uploadMeasurements(input)

        guard case .unprocessableContent = output else {
            return XCTFail("expected .unprocessableContent, got \(output)")
        }
    }
}

/// A ClientTransport that records the outgoing request (with its body
/// collected into Data for inspection) and returns a canned response,
/// keeping the generated client under test isolated from any network or
/// URLSession behavior.
private final class RecordedTransport: ClientTransport, @unchecked Sendable {
    typealias Stub = (HTTPRequest, Data?, String) throws -> (HTTPResponse, Data?)

    private let stub: Stub

    init(stub: @escaping Stub) {
        self.stub = stub
    }

    func send(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String
    ) async throws -> (HTTPResponse, HTTPBody?) {
        let bodyData: Data?
        if let body {
            bodyData = try await Data(collecting: body, upTo: 1_048_576)
        } else {
            bodyData = nil
        }
        let (response, data) = try stub(request, bodyData, operationID)
        return (response, data.map { HTTPBody($0) })
    }
}

private extension OpenAPIGeneratedClientTests {
    static func jsonResponse(_ status: HTTPTypes.HTTPResponseStatus, _ json: String) -> (HTTPResponse, Data?) {
        let response = HTTPResponse(
            status: status,
            headerFields: [HTTPField(name: .contentType, value: "application/json")]
        )
        return (response, Data(json.utf8))
    }

    static func jsonObject(from body: Data?) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(body)) as? [String: Any])
    }

    static let manifestJSON = #"""
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
      "printer_profile": {"printer_make_model": "Research printer", "paper_type": "paper name", "ink_type": "ink set"},
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
    """#

    static let rankedResultsJSON = #"""
    {
      "schema_version": "lps-ranked-results/v1",
      "sheet_id": "sheet_1",
      "printer_profile": {"printer_make_model": "Research printer", "paper_type": "paper name", "ink_type": "ink set"},
      "capture_count": 2,
      "latest_capture_at": "2026-07-26T09:00:00Z",
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
            "average": 0.04,
            "latest": 0.035,
            "minimum": 0.03,
            "maximum": 0.05,
            "capture_count": 2,
            "sample_count": 2,
            "algorithm_versions": ["lps-distance-v1"]
          },
          "current_judgment": "near_match",
          "current_judgment_observed_at": "2026-07-26T10:00:00Z",
          "observation_count": 1,
          "latest_observation": {"judgment": "near_match", "observed_at": "2026-07-26T10:00:00Z"},
          "capture_count": 2,
          "latest_capture_at": "2026-07-26T09:00:00Z",
          "earliest_capture_at": "2026-07-25T12:00:00Z"
        }
      ]
    }
    """#
}
