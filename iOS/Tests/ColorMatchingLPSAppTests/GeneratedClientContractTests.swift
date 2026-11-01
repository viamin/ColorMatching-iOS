import Foundation
import HTTPTypes
import OpenAPIRuntime
import XCTest

import ColorMatchingOpenAPI

/// Wire-level contract tests for the OpenAPI-generated client.
///
/// The contract under test is the `color_matching` `/api/v1` API as published
/// at `GET /api/v1/openapi.json` (viamin/color_matching#113), vendored and
/// normalized per `docs/openapi-client-migration.md`. All responses are
/// stubbed in-process by operation ID, so no live server is required.
///
/// Red-phase note (issue #5): these tests intentionally fail to build until
/// the `ColorMatchingOpenAPI` target is generated. The generated names they
/// rely on are pinned in `docs/openapi-client-migration.md`.
final class GeneratedClientContractTests: XCTestCase {

    private let serverURL = URL(string: "https://example.test")!

    // MARK: - Test-sheet manifest

    func testManifestDecodesFullSheetManifest() async throws {
        let transport = StubTransport(stubs: [
            "ColorMatchingWeb.TestSheetController.manifest": .init(status: 200, json: Self.manifestJSON)
        ])
        let client = Client(serverURL: serverURL, transport: transport)

        let response = try await client.colorMatchingWeb_TestSheetController_manifest(
            .init(path: .init(sheetId: "sheet_1"))
        )

        guard case .ok(let ok) = response else {
            return XCTFail("Expected .ok, got: \(response)")
        }
        let manifest = try ok.body.json
        XCTAssertEqual(manifest.schemaVersion, .lpsSheetManifestV1)
        XCTAssertEqual(manifest.sheetId, "sheet_1")
        XCTAssertEqual(manifest.sheetVersion, "lps-letter-grid-v1")
        XCTAssertEqual(manifest.manifestUrl, "/api/v1/test_sheets/sheet_1/manifest")

        let expectedCreatedAt = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-07-25T12:00:00Z"))
        XCTAssertEqual(manifest.createdAt.timeIntervalSince1970, expectedCreatedAt.timeIntervalSince1970, accuracy: 0.001)

        XCTAssertEqual(manifest.page.units, "mm")
        XCTAssertEqual(manifest.page.width, 215.9, accuracy: 0.0001)
        XCTAssertEqual(manifest.page.height, 279.4, accuracy: 0.0001)

        let marker = try XCTUnwrap(manifest.registrationMarkers.first)
        XCTAssertEqual(marker.role, "top_left")
        XCTAssertEqual(marker.shape, "solid_square")
        XCTAssertEqual(marker.rect.x, 12, accuracy: 0.0001)

        XCTAssertEqual(manifest.printerProfile.printerMakeModel, "Research printer")
        XCTAssertEqual(manifest.printerProfile.paperType, "paper name")
        XCTAssertEqual(manifest.printerProfile.inkType, "ink set")

        XCTAssertEqual(manifest.captureProfile.expectedIlluminant, "low_pressure_sodium")
        XCTAssertEqual(manifest.captureProfile.preferredCamera, "built_in_wide_angle_rear")
        XCTAssertEqual(manifest.captureProfile.scoringAlgorithmVersion, .lpsDistanceV1)

        let patch = try XCTUnwrap(manifest.patches.first)
        XCTAssertEqual(patch.id, "pair_1#first")
        XCTAssertEqual(patch.role, "pair_color")
        XCTAssertEqual(patch.pairId, "pair_1")
        XCTAssertEqual(patch.pairSide, "first")
        XCTAssertNil(patch.referenceRole)
        XCTAssertEqual(patch.sourceColor, "#FF0000")
        XCTAssertEqual(patch.safeInsetMm, 1.5, accuracy: 0.0001)
        XCTAssertEqual(patch.rect.x, 16, accuracy: 0.0001)
        XCTAssertEqual(patch.rect.y, 38, accuracy: 0.0001)
        XCTAssertEqual(patch.rect.width, 16, accuracy: 0.0001)
        XCTAssertEqual(patch.rect.height, 10, accuracy: 0.0001)

        let pair = try XCTUnwrap(manifest.pairs.first)
        XCTAssertEqual(pair.id, "pair_1")
        XCTAssertEqual(pair.firstPatchId, "pair_1#first")
        XCTAssertEqual(pair.secondPatchId, "pair_1#second")
        XCTAssertEqual(pair.sourceColors, ["#FF0000", "#00FF00"])
        XCTAssertEqual(pair.gridRow, 0)
        XCTAssertEqual(pair.gridCol, 1)

        let recorded = await transport.recordedRequests
        XCTAssertEqual(recorded.map(\.operationID), ["ColorMatchingWeb.TestSheetController.manifest"])
        XCTAssertEqual(recorded.first?.method, "GET")
        XCTAssertEqual(recorded.first?.path, "/api/v1/test_sheets/sheet_1/manifest")
    }

    func testManifestSurfacesNotFoundAsTypedResponseCase() async throws {
        let transport = StubTransport(stubs: [
            "ColorMatchingWeb.TestSheetController.manifest": .init(
                status: 404,
                json: #"{"errors":{"detail":"Sheet not found"}}"#
            )
        ])
        let client = Client(serverURL: serverURL, transport: transport)

        let response = try await client.colorMatchingWeb_TestSheetController_manifest(
            .init(path: .init(sheetId: "missing_sheet"))
        )

        guard case .notFound = response else {
            return XCTFail("Expected .notFound, got: \(response)")
        }
    }

    // MARK: - Recent sheets

    func testRecentSheetsDecodesSheetsWithNullableTitle() async throws {
        let transport = StubTransport(stubs: [
            "ColorMatchingWeb.TestSheetController.recent": .init(
                status: 200,
                json: #"{"sheets":[{"sheet_id":"sheet_1","manifest_url":"/api/v1/test_sheets/sheet_1/manifest","title":null},{"sheet_id":"sheet_2","manifest_url":"/api/v1/test_sheets/sheet_2/manifest","title":"July LPS sheet"}]}"#
            )
        ])
        let client = Client(serverURL: serverURL, transport: transport)

        let response = try await client.colorMatchingWeb_TestSheetController_recent(.init())

        guard case .ok(let ok) = response else {
            return XCTFail("Expected .ok, got: \(response)")
        }
        let payload = try ok.body.json
        XCTAssertEqual(payload.sheets.count, 2)
        XCTAssertEqual(payload.sheets.map(\.sheetId), ["sheet_1", "sheet_2"])
        XCTAssertEqual(payload.sheets.first?.manifestUrl, "/api/v1/test_sheets/sheet_1/manifest")
        XCTAssertNil(payload.sheets.first?.title)
        XCTAssertEqual(payload.sheets.last?.title, "July LPS sheet")

        let recorded = await transport.recordedRequests
        XCTAssertEqual(recorded.map(\.operationID), ["ColorMatchingWeb.TestSheetController.recent"])
        XCTAssertEqual(recorded.first?.method, "GET")
        XCTAssertEqual(recorded.first?.path, "/api/v1/test_sheets/recent")
    }

    func testRecentSheetsSurfacesUnauthorizedAsTypedResponseCase() async throws {
        let transport = StubTransport(stubs: [
            "ColorMatchingWeb.TestSheetController.recent": .init(
                status: 401,
                json: #"{"errors":{"detail":"Unauthorized"}}"#
            )
        ])
        let client = Client(serverURL: serverURL, transport: transport)

        let response = try await client.colorMatchingWeb_TestSheetController_recent(.init())

        guard case .unauthorized = response else {
            return XCTFail("Expected .unauthorized, got: \(response)")
        }
    }

    // MARK: - Ranked results

    func testRankedResultsDecodesAggregatePayload() async throws {
        let transport = StubTransport(stubs: [
            "ColorMatchingWeb.TestSheetController.ranked_results": .init(status: 200, json: Self.rankedResultsJSON)
        ])
        let client = Client(serverURL: serverURL, transport: transport)

        let response = try await client.colorMatchingWeb_TestSheetController_rankedResults(
            .init(path: .init(sheetId: "sheet_1"))
        )

        guard case .ok(let ok) = response else {
            return XCTFail("Expected .ok, got: \(response)")
        }
        let results = try ok.body.json
        XCTAssertEqual(results.schemaVersion, .lpsRankedResultsV1)
        XCTAssertEqual(results.sheetId, "sheet_1")
        XCTAssertEqual(results.printerProfile.printerMakeModel, "Research printer")
        XCTAssertEqual(results.captureCount, 3)
        XCTAssertEqual(results.scoringAlgorithmVersions, ["lps-distance-v1"])

        let ranked = try XCTUnwrap(results.results.first)
        XCTAssertEqual(ranked.rank, 1)
        XCTAssertEqual(ranked.pairId, "pair_1")
        XCTAssertEqual(ranked.scoringAlgorithmVersion, "lps-distance-v1")
        XCTAssertEqual(ranked.row, 0)
        XCTAssertEqual(ranked.col, 1)
        XCTAssertEqual(ranked.sourceColors.colorAHex, "#FF0000")
        XCTAssertEqual(ranked.sourceColors.colorBHex, "#00FF00")
        XCTAssertEqual(ranked.score.average, 0.035, accuracy: 0.0001)
        XCTAssertEqual(ranked.score.latest, 0.035, accuracy: 0.0001)
        XCTAssertEqual(ranked.score.minimum, 0.03, accuracy: 0.0001)
        XCTAssertEqual(ranked.score.maximum, 0.04, accuracy: 0.0001)
        XCTAssertEqual(ranked.score.captureCount, 3)
        XCTAssertEqual(ranked.score.sampleCount, 9)
        XCTAssertEqual(ranked.currentJudgment, "near_match")
        XCTAssertEqual(ranked.observationCount, 1)
        XCTAssertEqual(ranked.latestObservation?.judgment, "near_match")
        XCTAssertEqual(ranked.captureCount, 3)

        let recorded = await transport.recordedRequests
        XCTAssertEqual(recorded.map(\.operationID), ["ColorMatchingWeb.TestSheetController.ranked_results"])
        XCTAssertEqual(recorded.first?.method, "GET")
        XCTAssertEqual(recorded.first?.path, "/api/v1/test_sheets/sheet_1/ranked_results")
    }

    // MARK: - Capture session creation

    func testCreateCaptureSendsNestedMetadataAndQualityAndDecodesCaptureID() async throws {
        let transport = StubTransport(stubs: [
            "ColorMatchingWeb.CaptureController.create": .init(status: 201, json: #"{"capture_id":"42"}"#)
        ])
        let client = Client(serverURL: serverURL, transport: transport)

        let response = try await client.colorMatchingWeb_CaptureController_create(
            .init(
                path: .init(sheetId: "sheet_1"),
                body: .json(
                    Components.Schemas.CaptureRequest(
                        metadata: Components.Schemas.CaptureMetadata(
                            deviceModel: "iPhone 15",
                            lens: "built_in_wide_angle",
                            exposureDurationSeconds: 0.016,
                            iso: 100,
                            focusLensPosition: 0.42,
                            whiteBalanceGains: .init(red: 1.2, green: 1.0, blue: 1.4),
                            imageWidth: 4032,
                            imageHeight: 3024,
                            appVersion: "0.1.0",
                            timestamp: Date(timeIntervalSince1970: 0)
                        ),
                        quality: Components.Schemas.CaptureQuality(
                            detectedMarkerCount: 4,
                            blurScore: 0.75,
                            rejections: []
                        )
                    )
                )
            )
        )

        guard case .created(let created) = response else {
            return XCTFail("Expected .created, got: \(response)")
        }
        let createdBody = try created.body.json
        XCTAssertEqual(createdBody.captureId, "42")

        let recorded = await transport.recordedRequests
        let request = try XCTUnwrap(recorded.first)
        XCTAssertEqual(request.operationID, "ColorMatchingWeb.CaptureController.create")
        XCTAssertEqual(request.method, "POST")
        XCTAssertEqual(request.path, "/api/v1/test_sheets/sheet_1/captures")
        XCTAssertEqual(request.contentType, "application/json")

        let body = try Self.jsonObject(request.body)
        let metadata = try XCTUnwrap(body["metadata"] as? [String: Any])
        XCTAssertEqual(metadata["device_model"] as? String, "iPhone 15")
        XCTAssertEqual(metadata["lens"] as? String, "built_in_wide_angle")
        let exposure = try XCTUnwrap(metadata["exposure_duration_seconds"] as? Double)
        XCTAssertEqual(exposure, 0.016, accuracy: 0.00001)
        XCTAssertEqual(metadata["iso"] as? Int, 100)
        let focusPosition = try XCTUnwrap(metadata["focus_lens_position"] as? Double)
        XCTAssertEqual(focusPosition, 0.42, accuracy: 0.0001)
        XCTAssertEqual(metadata["image_width"] as? Int, 4032)
        XCTAssertEqual(metadata["image_height"] as? Int, 3024)
        XCTAssertEqual(metadata["app_version"] as? String, "0.1.0")
        XCTAssertEqual(metadata["timestamp"] as? String, "1970-01-01T00:00:00Z")
        let gains = try XCTUnwrap(metadata["white_balance_gains"] as? [String: Any])
        let gainRed = try XCTUnwrap(gains["red"] as? Double)
        XCTAssertEqual(gainRed, 1.2, accuracy: 0.0001)
        let gainGreen = try XCTUnwrap(gains["green"] as? Double)
        XCTAssertEqual(gainGreen, 1.0, accuracy: 0.0001)
        let gainBlue = try XCTUnwrap(gains["blue"] as? Double)
        XCTAssertEqual(gainBlue, 1.4, accuracy: 0.0001)

        let quality = try XCTUnwrap(body["quality"] as? [String: Any])
        XCTAssertEqual(quality["detected_marker_count"] as? Int, 4)
        let blurScore = try XCTUnwrap(quality["blur_score"] as? Double)
        XCTAssertEqual(blurScore, 0.75, accuracy: 0.0001)
        XCTAssertEqual(quality["rejections"] as? [String], [])
    }

    // MARK: - Measurement upload

    func testUploadMeasurementsSendsChannelPayloadsStatsAndScores() async throws {
        let transport = StubTransport(stubs: [
            "ColorMatchingWeb.CaptureController.upload_measurements": .init(
                status: 200,
                json: #"{"capture_id":"42","measurement_count":1,"pair_score_count":1}"#
            )
        ])
        let client = Client(serverURL: serverURL, transport: transport)

        let response = try await client.colorMatchingWeb_CaptureController_uploadMeasurements(
            .init(
                body: .json(
                    Components.Schemas.MeasurementUploadRequest(
                        scoringAlgorithmVersion: "lps-distance-v1",
                        measurements: [
                            Components.Schemas.MeasurementUploadItem(
                                patchId: "pair_1#first",
                                linearRgbMedian: .init(value2: .init(r: 0.12, g: 0.10, b: 0.02)),
                                normalizedLinearRgbMedian: .init(value2: .init(r: 0.15, g: 0.12, b: 0.02)),
                                stats: Components.Schemas.MeasurementStatsUpload(
                                    sampleCount: 900,
                                    clippingFraction: 0,
                                    mean: .init(value2: .init(r: 0.12, g: 0.10, b: 0.02)),
                                    standardDeviation: .init(value2: .init(r: 0.01, g: 0.01, b: 0.004))
                                )
                            )
                        ],
                        pairScores: [
                            Components.Schemas.PairScoreRequest(
                                pairId: "pair_1",
                                algorithmVersion: "lps-distance-v1",
                                distance: 0.035,
                                similarity: 0.965,
                                score: nil
                            )
                        ]
                    )
                )
            )
        )

        guard case .ok(let ok) = response else {
            return XCTFail("Expected .ok, got: \(response)")
        }
        let payload = try ok.body.json
        XCTAssertEqual(payload.captureId, "42")
        XCTAssertEqual(payload.measurementCount, 1)
        XCTAssertEqual(payload.pairScoreCount, 1)

        let recorded = await transport.recordedRequests
        let request = try XCTUnwrap(recorded.first)
        XCTAssertEqual(request.operationID, "ColorMatchingWeb.CaptureController.upload_measurements")
        XCTAssertEqual(request.method, "POST")
        XCTAssertEqual(request.path, "/api/v1/captures/42/measurements")
        XCTAssertEqual(request.contentType, "application/json")

        let body = try Self.jsonObject(request.body)
        XCTAssertEqual(body["scoring_algorithm_version"] as? String, "lps-distance-v1")

        let measurement = try XCTUnwrap((body["measurements"] as? [[String: Any]])?.first)
        XCTAssertEqual(measurement["patch_id"] as? String, "pair_1#first")
        let median = try XCTUnwrap(measurement["linear_rgb_median"] as? [String: Any])
        XCTAssertEqual(Set(median.keys), ["r", "g", "b"])
        let medianRed = try XCTUnwrap(median["r"] as? Double)
        XCTAssertEqual(medianRed, 0.12, accuracy: 0.0001)
        let medianGreen = try XCTUnwrap(median["g"] as? Double)
        XCTAssertEqual(medianGreen, 0.10, accuracy: 0.0001)
        let medianBlue = try XCTUnwrap(median["b"] as? Double)
        XCTAssertEqual(medianBlue, 0.02, accuracy: 0.0001)
        let normalizedMedian = try XCTUnwrap(measurement["normalized_linear_rgb_median"] as? [String: Any])
        let normalizedRed = try XCTUnwrap(normalizedMedian["r"] as? Double)
        XCTAssertEqual(normalizedRed, 0.15, accuracy: 0.0001)
        let stats = try XCTUnwrap(measurement["stats"] as? [String: Any])
        XCTAssertEqual(stats["sample_count"] as? Int, 900)
        let clippingFraction = try XCTUnwrap(stats["clipping_fraction"] as? Double)
        XCTAssertEqual(clippingFraction, 0, accuracy: 0.0001)
        let mean = try XCTUnwrap(stats["mean"] as? [String: Any])
        let meanGreen = try XCTUnwrap(mean["g"] as? Double)
        XCTAssertEqual(meanGreen, 0.10, accuracy: 0.0001)

        let pairScore = try XCTUnwrap((body["pair_scores"] as? [[String: Any]])?.first)
        XCTAssertEqual(pairScore["pair_id"] as? String, "pair_1")
        XCTAssertEqual(pairScore["algorithm_version"] as? String, "lps-distance-v1")
        let distance = try XCTUnwrap(pairScore["distance"] as? Double)
        XCTAssertEqual(distance, 0.035, accuracy: 0.0001)
        let similarity = try XCTUnwrap(pairScore["similarity"] as? Double)
        XCTAssertEqual(similarity, 0.965, accuracy: 0.0001)
    }

    // MARK: - Judgment upload

    func testUploadJudgmentsSendsPairJudgmentsAndDecodesCounters() async throws {
        let transport = StubTransport(stubs: [
            "ColorMatchingWeb.CaptureController.upload_judgments": .init(
                status: 200,
                json: #"{"capture_id":"42","judgment_count":2}"#
            )
        ])
        let client = Client(serverURL: serverURL, transport: transport)

        let response = try await client.colorMatchingWeb_CaptureController_uploadJudgments(
            .init(
                body: .json(
                    Components.Schemas.JudgmentUploadRequest(
                        judgments: [
                            Components.Schemas.JudgmentUploadItem(pairId: "pair_1", judgment: "near_match"),
                            Components.Schemas.JudgmentUploadItem(pairId: "pair_2", judgment: "no_match")
                        ]
                    )
                )
            )
        )

        guard case .ok(let ok) = response else {
            return XCTFail("Expected .ok, got: \(response)")
        }
        let payload = try ok.body.json
        XCTAssertEqual(payload.captureId, "42")
        XCTAssertEqual(payload.judgmentCount, 2)

        let recorded = await transport.recordedRequests
        let request = try XCTUnwrap(recorded.first)
        XCTAssertEqual(request.operationID, "ColorMatchingWeb.CaptureController.upload_judgments")
        XCTAssertEqual(request.method, "POST")
        XCTAssertEqual(request.path, "/api/v1/captures/42/judgments")
        XCTAssertEqual(request.contentType, "application/json")

        let body = try Self.jsonObject(request.body)
        let judgments = try XCTUnwrap(body["judgments"] as? [[String: Any]])
        XCTAssertEqual(judgments.count, 2)
        XCTAssertEqual(judgments[0]["pair_id"] as? String, "pair_1")
        XCTAssertEqual(judgments[0]["judgment"] as? String, "near_match")
        XCTAssertEqual(judgments[1]["pair_id"] as? String, "pair_2")
        XCTAssertEqual(judgments[1]["judgment"] as? String, "no_match")
    }

    func testUploadJudgmentsSurfacesValidationErrorAsTypedResponseCase() async throws {
        let transport = StubTransport(stubs: [
            "ColorMatchingWeb.CaptureController.upload_judgments": .init(
                status: 422,
                json: #"{"errors":{"judgments":[{"pair_id":"pair_9","index":0,"errors":{"judgment":["is invalid"]}}]}}"#
            )
        ])
        let client = Client(serverURL: serverURL, transport: transport)

        let response = try await client.colorMatchingWeb_CaptureController_uploadJudgments(
            .init(
                body: .json(
                    Components.Schemas.JudgmentUploadRequest(
                        judgments: [Components.Schemas.JudgmentUploadItem(pairId: "pair_9", judgment: "maybe")]
                    )
                )
            )
        )

        guard case .unprocessableContent = response else {
            return XCTFail("Expected .unprocessableContent, got: \(response)")
        }
    }

    // MARK: - Fixtures and helpers

    private static let manifestJSON = ##"""
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
        "ink_type": "ink set",
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
    """##

    private static let rankedResultsJSON = ##"""
    {
      "schema_version": "lps-ranked-results/v1",
      "sheet_id": "sheet_1",
      "printer_profile": {
        "printer_make_model": "Research printer",
        "paper_type": "paper name",
        "ink_type": "ink set"
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
            "latest": 0.035,
            "minimum": 0.03,
            "maximum": 0.04,
            "capture_count": 3,
            "sample_count": 9,
            "algorithm_versions": ["lps-distance-v1"]
          },
          "current_judgment": "near_match",
          "current_judgment_observed_at": "2026-07-26T10:00:00Z",
          "observation_count": 1,
          "latest_observation": {"judgment": "near_match", "observed_at": "2026-07-26T10:00:00Z"},
          "capture_count": 3,
          "latest_capture_at": "2026-07-26T09:30:00Z",
          "earliest_capture_at": "2026-07-25T12:00:00Z"
        }
      ]
    }
    """##

    private static func jsonObject(_ data: Data?) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(data)) as? [String: Any])
    }
}

/// Records outbound requests and serves canned responses, keyed by OpenAPI
/// operation ID. Conforming to `ClientTransport` from `OpenAPIRuntime` keeps
/// these tests free of any live network dependency.
private actor StubTransport: ClientTransport {

    struct Stub: Sendable {
        var status: Int
        var json: String?
    }

    struct RecordedRequest: Sendable {
        var operationID: String
        var method: String
        var path: String
        var contentType: String?
        var body: Data?
    }

    private let stubs: [String: Stub]
    private(set) var recordedRequests: [RecordedRequest] = []

    init(stubs: [String: Stub]) {
        self.stubs = stubs
    }

    func send(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String
    ) async throws -> (HTTPResponse, HTTPBody?) {
        var requestBody: Data?
        if let body {
            requestBody = try await Data(collecting: body, upTo: 1 << 20)
        }
        recordedRequests.append(
            RecordedRequest(
                operationID: operationID,
                method: request.method.rawValue,
                path: request.path ?? "",
                contentType: request.headerFields[.contentType],
                body: requestBody
            )
        )

        guard let stub = stubs[operationID] else {
            throw MissingStubError(operationID: operationID)
        }

        var headerFields = HTTPFields()
        let responseBody: HTTPBody?
        if let json = stub.json {
            headerFields[.contentType] = "application/json"
            responseBody = HTTPBody(Data(json.utf8))
        } else {
            responseBody = nil
        }
        return (HTTPResponse(status: HTTPResponse.Status(code: stub.status), headerFields: headerFields), responseBody)
    }
}

private struct MissingStubError: Error, CustomStringConvertible {
    let operationID: String
    var description: String { "No stub registered for operation \(operationID)" }
}
