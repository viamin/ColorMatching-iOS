#if canImport(OpenAPIGenerated) && canImport(OpenAPIRuntime) && canImport(HTTPTypes)

import Foundation
import HTTPTypes
import OpenAPIGenerated
import OpenAPIRuntime
import XCTest

/// Exercises the generated OpenAPI client against locally stubbed HTTP
/// responses, so CI needs no live `color_matching` server.
///
/// These tests compile only once the generated `OpenAPIGenerated` target
/// exists (see `docs/openapi-generated-client-plan.md`). Until the generation
/// pipeline lands they are compiled out; `OpenAPIDocumentCoverageTests`
/// carries the red-phase signal by failing on the missing vendored document.
final class GeneratedClientTests: XCTestCase {
    private var transport: StubTransport!
    private var client: Client!

    override func setUp() {
        super.setUp()
        transport = StubTransport()
        client = Client(
            serverURL: URL(string: "https://example.test")!,
            transport: transport
        )
    }

    override func tearDown() {
        transport = nil
        client = nil
        super.tearDown()
    }

    // MARK: - Test sheet manifest

    func testGetTestSheetManifestDecodesStubbedManifest() async throws {
        transport.stub(.ok, json: Self.manifestJSON, for: "getTestSheetManifest")

        let response = try await client.getTestSheetManifest(.init(path: .init(sheetId: "sheet_1")))

        guard case .ok(let ok) = response else {
            return XCTFail("Expected .ok for manifest fetch, got \(response)")
        }
        let manifest = try ok.body.json
        XCTAssertEqual(manifest.schemaVersion, .lpsSheetManifestV1)
        XCTAssertEqual(manifest.sheetId, "sheet_1")
        XCTAssertEqual(manifest.sheetVersion, "lps-letter-grid-v1")
        XCTAssertEqual(manifest.patches.count, 3)
        XCTAssertEqual(manifest.pairs.count, 1)
        XCTAssertEqual(manifest.pairs.first?.firstPatchId, "pair_1#first")
        XCTAssertEqual(manifest.page.units, "mm")
        XCTAssertEqual(manifest.registrationMarkers.count, 4)
        XCTAssertEqual(manifest.printerProfile.printerMakeModel, "Canon PIXMA Pro-200")
        XCTAssertEqual(manifest.captureProfile.scoringAlgorithmVersion, .lpsDistanceV1)

        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.method, .get)
        XCTAssertEqual(request.path, "/api/v1/test_sheets/sheet_1/manifest")
    }

    func testGetTestSheetManifestSurfacesDocumentedNotFoundResponse() async throws {
        transport.stub(.notFound, json: #"{"errors":{"detail":"Sheet not found"}}"#, for: "getTestSheetManifest")

        let response = try await client.getTestSheetManifest(.init(path: .init(sheetId: "missing")))

        guard case .notFound = response else {
            return XCTFail("Expected .notFound for a missing sheet, got \(response)")
        }
        XCTAssertEqual(transport.requests.first?.path, "/api/v1/test_sheets/missing/manifest")
    }

    // MARK: - Recent sheets

    func testListRecentTestSheetsDecodesTitlesIncludingNull() async throws {
        transport.stub(.ok, json: Self.recentSheetsJSON, for: "listRecentTestSheets")

        let response = try await client.listRecentTestSheets()

        guard case .ok(let ok) = response else {
            return XCTFail("Expected .ok for recent sheets, got \(response)")
        }
        let list = try ok.body.json
        XCTAssertEqual(list.sheets.count, 2)
        XCTAssertEqual(list.sheets.first?.sheetId, "sheet_1")
        XCTAssertNil(list.sheets.first?.title, "The server sends title: null when it has no display name")
        XCTAssertEqual(list.sheets.last?.title, "July LPS comparison sheet")

        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.method, .get)
        XCTAssertEqual(request.path, "/api/v1/test_sheets/recent")
    }

    // MARK: - Capture session creation

    func testCreateCapturePostsNestedMetadataAndQuality() async throws {
        transport.stub(.created, json: #"{"capture_id":"capture_1"}"#, for: "createCapture")

        let response = try await client.createCapture(
            .init(
                path: .init(sheetId: "sheet_1"),
                body: .json(
                    Components.Schemas.CaptureRequest(
                        metadata: .init(
                            deviceModel: "iPhone 15",
                            lens: "built_in_wide_angle",
                            exposureDurationSeconds: 0.016,
                            iso: 100,
                            focusLensPosition: 0.42,
                            whiteBalanceGains: .init(red: 1.2, green: 1, blue: 1.4),
                            imageWidth: 4032,
                            imageHeight: 3024,
                            appVersion: "0.1.0",
                            timestamp: Date(timeIntervalSince1970: 1_784_980_800)
                        ),
                        quality: .init(detectedMarkerCount: 4, blurScore: 0.82, rejections: ["glare"])
                    )
                )
            )
        )

        guard case .created(let created) = response else {
            return XCTFail("Expected .created for capture creation, got \(response)")
        }
        XCTAssertEqual(try created.body.json.captureId, "capture_1")

        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.method, .post)
        XCTAssertEqual(request.path, "/api/v1/test_sheets/sheet_1/captures")
        XCTAssertEqual(
            request.contentType?.split(separator: ";").first.map(String.init),
            "application/json"
        )

        let body = try XCTUnwrap(request.bodyJSON)
        let metadata = try XCTUnwrap(body["metadata"] as? [String: Any])
        XCTAssertEqual(metadata["device_model"] as? String, "iPhone 15")
        XCTAssertEqual(metadata["lens"] as? String, "built_in_wide_angle")
        XCTAssertEqual(metadata["iso"] as? Int, 100)
        XCTAssertEqual(metadata["image_width"] as? Int, 4032)
        XCTAssertEqual(metadata["app_version"] as? String, "0.1.0")
        let gains = try XCTUnwrap(metadata["white_balance_gains"] as? [String: Any])
        XCTAssertEqual((gains["red"] as? NSNumber)?.doubleValue ?? 0, 1.2, accuracy: 0.0001)
        XCTAssertEqual((gains["green"] as? NSNumber)?.doubleValue ?? 0, 1, accuracy: 0.0001)
        let timestamp = try XCTUnwrap(metadata["timestamp"] as? String)
        XCTAssertTrue(
            timestamp.hasPrefix("2026-07-25T12:00:00"),
            "timestamp must encode as RFC 3339, got \(timestamp)"
        )

        let quality = try XCTUnwrap(body["quality"] as? [String: Any])
        XCTAssertEqual(quality["detected_marker_count"] as? Int, 4)
        XCTAssertEqual((quality["blur_score"] as? NSNumber)?.doubleValue ?? 0, 0.82, accuracy: 0.0001)
        XCTAssertEqual(quality["rejections"] as? [String], ["glare"])
    }

    // MARK: - Measurement upload

    func testUploadMeasurementsEncodesStatsAndScoresAndDecodesAcceptance() async throws {
        transport.stub(
            .ok,
            json: #"{"capture_id":"capture_1","measurement_count":1,"pair_score_count":1}"#,
            for: "uploadMeasurements"
        )

        let response = try await client.uploadMeasurements(
            .init(
                path: .init(captureId: "capture_1"),
                body: .json(
                    Components.Schemas.MeasurementUploadRequest(
                        scoringAlgorithmVersion: "lps-distance-v1",
                        measurements: [
                            .init(
                                patchId: "pair_1#first",
                                linearRgbMedian: .init(r: 0.12, g: 0.1, b: 0.02),
                                normalizedLinearRgbMedian: .init(r: 0.15, g: 0.12, b: 0.02),
                                stats: .init(
                                    sampleCount: 900,
                                    clippingFraction: 0,
                                    mean: .init(r: 0.12, g: 0.1, b: 0.02),
                                    standardDeviation: .init(r: 0.01, g: 0.01, b: 0.004)
                                )
                            )
                        ],
                        pairScores: [
                            .init(
                                pairId: "pair_1",
                                distance: 0.035,
                                similarity: 0.965,
                                algorithmVersion: "lps-distance-v1"
                            )
                        ]
                    )
                )
            )
        )

        guard case .ok(let ok) = response else {
            return XCTFail("Expected .ok for measurement upload, got \(response)")
        }
        let accepted = try ok.body.json
        XCTAssertEqual(accepted.captureId, "capture_1")
        XCTAssertEqual(accepted.measurementCount, 1)
        XCTAssertEqual(accepted.pairScoreCount, 1)

        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.method, .post)
        XCTAssertEqual(request.path, "/api/v1/captures/capture_1/measurements")

        let body = try XCTUnwrap(request.bodyJSON)
        XCTAssertEqual(body["scoring_algorithm_version"] as? String, "lps-distance-v1")
        let measurement = try XCTUnwrap((body["measurements"] as? [[String: Any]])?.first)
        XCTAssertEqual(measurement["patch_id"] as? String, "pair_1#first")
        XCTAssertEqual(
            Set((measurement["linear_rgb_median"] as? [String: Any] ?? [:]).keys),
            ["r", "g", "b"]
        )
        let normalized = try XCTUnwrap(measurement["normalized_linear_rgb_median"] as? [String: Any])
        XCTAssertEqual((normalized["r"] as? NSNumber)?.doubleValue ?? 0, 0.15, accuracy: 0.0001)
        let stats = try XCTUnwrap(measurement["stats"] as? [String: Any])
        XCTAssertEqual(
            Set(stats.keys),
            ["sample_count", "clipping_fraction", "mean", "standard_deviation"]
        )
        XCTAssertEqual(stats["sample_count"] as? Int, 900)
        let score = try XCTUnwrap((body["pair_scores"] as? [[String: Any]])?.first)
        XCTAssertEqual(score["pair_id"] as? String, "pair_1")
        XCTAssertEqual((score["distance"] as? NSNumber)?.doubleValue ?? 0, 0.035, accuracy: 0.0001)
        XCTAssertEqual((score["similarity"] as? NSNumber)?.doubleValue ?? 0, 0.965, accuracy: 0.0001)
        XCTAssertEqual(score["algorithm_version"] as? String, "lps-distance-v1")
    }

    // MARK: - Judgment upload

    func testUploadJudgmentsEncodesLabelsAndDecodesAcceptance() async throws {
        transport.stub(
            .ok,
            json: #"{"capture_id":"capture_1","judgment_count":1}"#,
            for: "uploadJudgments"
        )

        let response = try await client.uploadJudgments(
            .init(
                path: .init(captureId: "capture_1"),
                body: .json(
                    Components.Schemas.JudgmentUploadRequest(
                        judgments: [.init(pairId: "pair_1", judgment: "near_match")]
                    )
                )
            )
        )

        guard case .ok(let ok) = response else {
            return XCTFail("Expected .ok for judgment upload, got \(response)")
        }
        let accepted = try ok.body.json
        XCTAssertEqual(accepted.captureId, "capture_1")
        XCTAssertEqual(accepted.judgmentCount, 1)

        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.method, .post)
        XCTAssertEqual(request.path, "/api/v1/captures/capture_1/judgments")
        let body = try XCTUnwrap(request.bodyJSON)
        XCTAssertEqual(
            (body["judgments"] as? [[String: Any]])?.first?["judgment"] as? String,
            "near_match"
        )
    }

    // MARK: - Ranked results

    func testGetRankedResultsDecodesStubbedResults() async throws {
        transport.stub(.ok, json: Self.rankedResultsJSON, for: "getRankedResults")

        let response = try await client.getRankedResults(.init(path: .init(sheetId: "sheet_1")))

        guard case .ok(let ok) = response else {
            return XCTFail("Expected .ok for ranked results, got \(response)")
        }
        let ranked = try ok.body.json
        XCTAssertEqual(ranked.schemaVersion, .lpsRankedResultsV1)
        XCTAssertEqual(ranked.sheetId, "sheet_1")
        XCTAssertEqual(ranked.results.count, 1)

        let first = try XCTUnwrap(ranked.results.first)
        XCTAssertEqual(first.rank, 1)
        XCTAssertEqual(first.pairId, "pair_1")
        XCTAssertEqual(first.currentJudgment, "near_match")
        XCTAssertEqual(first.sourceColors.colorBHex, "#00FF00")
        XCTAssertEqual(first.score.average ?? 0, 0.035, accuracy: 0.0001)

        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.method, .get)
        XCTAssertEqual(request.path, "/api/v1/test_sheets/sheet_1/ranked_results")
    }

    // MARK: - Stubbed response fixtures
    //
    // Shapes follow the real `color_matching` responses (lib/color_matching_web/controllers/test_sheet_json.ex)
    // intersected with the vendored spec overlay.

    private static let manifestJSON = """
        {
          "schema_version": "lps-sheet-manifest/v1",
          "sheet_version": "lps-letter-grid-v1",
          "sheet_id": "sheet_1",
          "manifest_url": "/api/v1/test_sheets/sheet_1/manifest",
          "created_at": "2026-07-25T12:00:00Z",
          "page": {"units": "mm", "width": 215.9, "height": 279.4},
          "registration_markers": [
            {"role": "top_left", "shape": "solid_square", "rect": {"x": 12, "y": 12, "width": 8, "height": 8}},
            {"role": "top_right", "shape": "solid_square", "rect": {"x": 195.9, "y": 12, "width": 8, "height": 8}},
            {"role": "bottom_right", "shape": "solid_square", "rect": {"x": 195.9, "y": 259.4, "width": 8, "height": 8}},
            {"role": "bottom_left", "shape": "solid_square", "rect": {"x": 12, "y": 259.4, "width": 8, "height": 8}}
          ],
          "printer_profile": {"printer_make_model": "Canon PIXMA Pro-200", "paper_type": "plain", "ink_type": "dye"},
          "capture_profile": {
            "expected_illuminant": "low_pressure_sodium",
            "preferred_camera": "built_in_wide_angle_rear",
            "scoring_algorithm_version": "lps-distance-v1"
          },
          "patches": [
            {"id": "pair_1#first", "role": "pair_color", "pair_id": "pair_1", "pair_side": "first", "reference_role": null, "source_color": "#FF0000", "safe_inset_mm": 1.5, "rect": {"x": 16, "y": 38, "width": 16, "height": 10}},
            {"id": "pair_1#second", "role": "pair_color", "pair_id": "pair_1", "pair_side": "second", "reference_role": null, "source_color": "#00FF00", "safe_inset_mm": 1.5, "rect": {"x": 36, "y": 38, "width": 16, "height": 10}},
            {"id": "reference_white", "role": "reference", "pair_id": null, "pair_side": null, "reference_role": "white", "source_color": null, "safe_inset_mm": 1.0, "rect": {"x": 56, "y": 38, "width": 16, "height": 10}}
          ],
          "pairs": [
            {"id": "pair_1", "first_patch_id": "pair_1#first", "second_patch_id": "pair_1#second", "source_colors": ["#FF0000", "#00FF00"], "grid_row": 0, "grid_col": 1}
          ]
        }
        """

    private static let recentSheetsJSON = """
        {
          "sheets": [
            {"sheet_id": "sheet_1", "manifest_url": "/api/v1/test_sheets/sheet_1/manifest", "title": null},
            {"sheet_id": "sheet_2", "manifest_url": "/api/v1/test_sheets/sheet_2/manifest", "title": "July LPS comparison sheet"}
          ]
        }
        """

    private static let rankedResultsJSON = """
        {
          "schema_version": "lps-ranked-results/v1",
          "sheet_id": "sheet_1",
          "printer_profile": {"printer_make_model": "Canon PIXMA Pro-200", "paper_type": "plain", "ink_type": "dye"},
          "capture_count": 2,
          "latest_capture_at": "2026-07-25T12:05:00Z",
          "earliest_capture_at": "2026-07-25T11:55:00Z",
          "scoring_algorithm_versions": ["lps-distance-v1"],
          "results": [
            {
              "rank": 1,
              "pair_id": "pair_1",
              "scoring_algorithm_version": "lps-distance-v1",
              "row": 0,
              "col": 1,
              "source_colors": {"color_a_hex": "#FF0000", "color_b_hex": "#00FF00"},
              "score": {"average": 0.035, "latest": 0.035, "minimum": 0.03, "maximum": 0.04, "capture_count": 2, "sample_count": 2, "algorithm_versions": ["lps-distance-v1"]},
              "current_judgment": "near_match",
              "current_judgment_observed_at": "2026-07-25T12:10:00Z",
              "observation_count": 1,
              "latest_observation": {"judgment": "near_match", "observed_at": "2026-07-25T12:10:00Z"},
              "capture_count": 2,
              "latest_capture_at": "2026-07-25T12:05:00Z",
              "earliest_capture_at": "2026-07-25T11:55:00Z"
            }
          ]
        }
        """
}

/// A `ClientTransport` that records outgoing requests and replies with canned
/// JSON, following the testing pattern documented by swift-openapi-runtime.
private final class StubTransport: ClientTransport, @unchecked Sendable {
    struct ReceivedRequest {
        let operationID: String
        let method: HTTPRequest.Method
        let path: String?
        let contentType: String?
        let bodyJSON: [String: Any]?
    }

    private struct Stub {
        let status: HTTPResponse.Status
        let body: String
    }

    private var stubs: [String: Stub] = [:]
    private(set) var requests: [ReceivedRequest] = []

    func stub(_ status: HTTPResponse.Status, json: String, for operationID: String) {
        stubs[operationID] = Stub(status: status, body: json)
    }

    func send(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String
    ) async throws -> (HTTPResponse, HTTPBody?) {
        let requestData: Data?
        if let body {
            requestData = try await Data(collecting: body, upTo: 1 << 20)
        } else {
            requestData = nil
        }
        let bodyJSON: [String: Any]? = requestData.flatMap { data in
            (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        }
        requests.append(
            ReceivedRequest(
                operationID: operationID,
                method: request.method,
                path: request.path,
                contentType: request.headerFields[.contentType],
                bodyJSON: bodyJSON
            )
        )

        let stub = stubs[operationID] ?? Stub(
            status: .internalServerError,
            body: #"{"errors":{"detail":"No stub configured for \#(operationID)"}}"#
        )
        return (
            HTTPResponse(
                status: stub.status,
                headerFields: [.contentType: "application/json"]
            ),
            HTTPBody(Data(stub.body.utf8))
        )
    }
}

#endif
