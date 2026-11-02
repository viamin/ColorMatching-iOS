import ColorMatchingOpenAPI
import Foundation
import OpenAPIRuntime
import XCTest

final class GeneratedOpenAPIClientTests: XCTestCase {
    private static let serverURL = URL(string: "https://color-matching.example")!
    private static let iso8601 = ISO8601DateFormatter()

    private static func makeClient(transport: StubbedTransport) -> ColorMatchingOpenAPI.Client {
        ColorMatchingOpenAPI.Client(serverURL: serverURL, transport: transport)
    }

    private static func date(_ string: String) -> Date {
        guard let date = iso8601.date(from: string) else {
            preconditionFailure("Unparseable fixture timestamp: \(string)")
        }
        return date
    }

    func testFetchManifestDecodesRealSheetShape() async throws {
        let transport = StubbedTransport { request, _, baseURL, operationID in
            XCTAssertEqual(request.method, .get)
            XCTAssertEqual(request.path, "/api/v1/test_sheets/sheet_123/manifest")
            XCTAssertEqual(request.headerFields[.accept], "application/json")
            XCTAssertEqual(baseURL.absoluteString, "https://color-matching.example")
            XCTAssertEqual(operationID, "fetchManifest")
            return stubbedJSONResponse(Fixtures.manifestJSON, status: .ok)
        }
        let client = Self.makeClient(transport: transport)

        let output = try await client.fetchManifest(path: .init(sheetId: "sheet_123"))

        guard case .ok(let ok) = output else {
            return XCTFail("Expected .ok, got \(output)")
        }
        let manifest = try ok.body.json
        XCTAssertEqual(manifest.schemaVersion.rawValue, "lps-sheet-manifest/v1")
        XCTAssertEqual(manifest.sheetId, "sheet_123")
        XCTAssertEqual(manifest.sheetVersion, "lps-letter-grid-v1")
        XCTAssertEqual(manifest.createdAt, Self.date("2026-07-25T12:00:00Z"))
        XCTAssertEqual(manifest.page.units, "mm")
        XCTAssertEqual(manifest.page.width, 215.9, accuracy: 1e-9)
        XCTAssertEqual(manifest.page.height, 279.4, accuracy: 1e-9)

        XCTAssertEqual(manifest.registrationMarkers.count, 2)
        let marker = try XCTUnwrap(manifest.registrationMarkers.first)
        XCTAssertEqual(marker.role, "top_left")
        XCTAssertEqual(marker.shape, "solid_square")
        XCTAssertEqual(marker.rect.width, 8, accuracy: 1e-9)

        XCTAssertEqual(manifest.printerProfile.printerMakeModel, "Canon PIXMA PRO-200")
        XCTAssertEqual(manifest.printerProfile.paperType, "Photo Paper Plus Glossy II")
        XCTAssertEqual(manifest.printerProfile.inkType, "CLI-42")
        XCTAssertNil(manifest.printerProfile.iccProfile)

        XCTAssertEqual(manifest.captureProfile.expectedIlluminant, "low_pressure_sodium")
        XCTAssertEqual(manifest.captureProfile.preferredCamera, "built_in_wide_angle_rear")
        XCTAssertEqual(manifest.captureProfile.scoringAlgorithmVersion.rawValue, "lps-distance-v1")

        XCTAssertEqual(manifest.patches.map(\.id), ["pair_1#first", "pair_1#second"])
        let firstPatch = try XCTUnwrap(manifest.patches.first)
        XCTAssertEqual(firstPatch.role, "pair_color")
        XCTAssertEqual(firstPatch.pairId, "pair_1")
        XCTAssertEqual(firstPatch.pairSide, "first")
        XCTAssertNil(firstPatch.referenceRole)
        XCTAssertEqual(firstPatch.sourceColor, "#FF0000")
        XCTAssertEqual(firstPatch.safeInsetMm, 1.5, accuracy: 1e-9)
        XCTAssertEqual(firstPatch.rect.x, 16, accuracy: 1e-9)

        let pair = try XCTUnwrap(manifest.pairs.first)
        XCTAssertEqual(pair.id, "pair_1")
        XCTAssertEqual(pair.firstPatchId, "pair_1#first")
        XCTAssertEqual(pair.secondPatchId, "pair_1#second")
        XCTAssertEqual(pair.sourceColors, ["#FF0000", "#00FF00"])
        XCTAssertEqual(pair.gridRow, 0)
        XCTAssertEqual(pair.gridCol, 1)
    }

    func testFetchManifestDecodesNotFoundError() async throws {
        let transport = StubbedTransport { _, _, _, _ in
            stubbedJSONResponse(#"{"errors":{"detail":"Sheet not found"}}"#, status: .notFound)
        }
        let client = Self.makeClient(transport: transport)

        let output = try await client.fetchManifest(path: .init(sheetId: "missing"))

        guard case .notFound(let notFound) = output else {
            return XCTFail("Expected .notFound, got \(output)")
        }
        let error = try notFound.body.json
        XCTAssertEqual(error.errors["detail"]?.value(as: String.self), "Sheet not found")
    }

    func testFetchRecentSheetsDecodesNullableTitles() async throws {
        let transport = StubbedTransport { request, _, _, _ in
            XCTAssertEqual(request.method, .get)
            XCTAssertEqual(request.path, "/api/v1/test_sheets/recent")
            return stubbedJSONResponse(Fixtures.recentSheetsJSON, status: .ok)
        }
        let client = Self.makeClient(transport: transport)

        let output = try await client.fetchRecentSheets()

        guard case .ok(let ok) = output else {
            return XCTFail("Expected .ok, got \(output)")
        }
        let response = try ok.body.json
        XCTAssertEqual(response.sheets.count, 2)

        let untitled = try XCTUnwrap(response.sheets.first)
        XCTAssertEqual(untitled.sheetId, "sheet_123")
        XCTAssertEqual(untitled.manifestUrl, "https://color-matching.example/api/v1/test_sheets/sheet_123/manifest")
        XCTAssertNil(untitled.title)

        let titled = try XCTUnwrap(response.sheets.last)
        XCTAssertEqual(titled.sheetId, "sheet_456")
        XCTAssertEqual(titled.title, "July LPS comparison sheet")
    }

    func testCreateCaptureSendsNestedMetadataAndQuality() async throws {
        let capturedBody = Captured<HTTPBody>()
        let transport = StubbedTransport { request, body, _, operationID in
            capturedBody.value = body
            XCTAssertEqual(request.method, .post)
            XCTAssertEqual(request.path, "/api/v1/test_sheets/sheet_1/captures")
            XCTAssertEqual(request.headerFields[.contentType], "application/json")
            XCTAssertEqual(operationID, "createCapture")
            return stubbedJSONResponse(#"{"capture_id":"42"}"#, status: .created)
        }
        let client = Self.makeClient(transport: transport)

        let payload = Components.Schemas.CaptureRequest(
            metadata: .init(
                deviceModel: "iPhone 15 Pro",
                lens: "built_in_wide_angle",
                exposureDurationSeconds: 0.016,
                iso: 100,
                focusLensPosition: 0.42,
                whiteBalanceGains: .init(red: 1.2, green: 1.0, blue: 1.4),
                imageWidth: 4032,
                imageHeight: 3024,
                appVersion: "0.1.0",
                timestamp: Self.date("2026-07-25T12:00:00Z")
            ),
            quality: .init(detectedMarkerCount: 4, blurScore: 0.82, rejections: [])
        )

        let output = try await client.createCapture(
            path: .init(sheetId: "sheet_1"),
            body: .json(payload)
        )

        guard case .created(let created) = output else {
            return XCTFail("Expected .created, got \(output)")
        }
        let response = try created.body.json
        XCTAssertEqual(response.captureId, "42")

        let json = try await jsonObject(from: capturedBody.value)
        let metadata = try XCTUnwrap(json["metadata"] as? [String: Any])
        XCTAssertEqual(metadata["device_model"] as? String, "iPhone 15 Pro")
        XCTAssertEqual(metadata["lens"] as? String, "built_in_wide_angle")
        XCTAssertEqual(metadata["exposure_duration_seconds"] as? Double, 0.016, accuracy: 1e-9)
        XCTAssertEqual(metadata["iso"] as? Int, 100)
        XCTAssertEqual(metadata["focus_lens_position"] as? Double, 0.42, accuracy: 1e-9)
        XCTAssertEqual(metadata["image_width"] as? Int, 4032)
        XCTAssertEqual(metadata["image_height"] as? Int, 3024)
        XCTAssertEqual(metadata["app_version"] as? String, "0.1.0")
        XCTAssertNotNil(metadata["timestamp"] as? String)
        let gains = try XCTUnwrap(metadata["white_balance_gains"] as? [String: Any])
        XCTAssertEqual(gains["red"] as? Double, 1.2, accuracy: 1e-9)
        XCTAssertEqual(gains["blue"] as? Double, 1.4, accuracy: 1e-9)

        let quality = try XCTUnwrap(json["quality"] as? [String: Any])
        XCTAssertEqual(quality["detected_marker_count"] as? Int, 4)
        XCTAssertEqual(quality["blur_score"] as? Double, 0.82, accuracy: 1e-9)
        XCTAssertEqual(quality["rejections"] as? [String], [])
    }

    func testCreateCaptureDecodesValidationErrors() async throws {
        let transport = StubbedTransport { _, _, _, _ in
            stubbedJSONResponse(
                #"{"errors":{"device_model":["can't be blank"]}}"#,
                status: .unprocessableEntity
            )
        }
        let client = Self.makeClient(transport: transport)

        let payload = Components.Schemas.CaptureRequest(
            metadata: .init(
                deviceModel: "",
                lens: "built_in_wide_angle",
                exposureDurationSeconds: nil,
                iso: nil,
                focusLensPosition: nil,
                whiteBalanceGains: nil,
                imageWidth: 4032,
                imageHeight: 3024,
                appVersion: "0.1.0",
                timestamp: Self.date("2026-07-25T12:00:00Z")
            ),
            quality: .init(detectedMarkerCount: 4, blurScore: 0.82, rejections: [])
        )

        let output = try await client.createCapture(
            path: .init(sheetId: "sheet_1"),
            body: .json(payload)
        )

        guard case .unprocessableEntity(let unprocessable) = output else {
            return XCTFail("Expected .unprocessableEntity, got \(output)")
        }
        let error = try unprocessable.body.json
        XCTAssertNotNil(error.errors["device_model"])
    }

    func testUploadMeasurementsSendsStatsAndScoresAndDecodesCounters() async throws {
        let capturedBody = Captured<HTTPBody>()
        let transport = StubbedTransport { request, body, _, operationID in
            capturedBody.value = body
            XCTAssertEqual(request.method, .post)
            XCTAssertEqual(request.path, "/api/v1/captures/42/measurements")
            XCTAssertEqual(operationID, "uploadMeasurements")
            return stubbedJSONResponse(
                #"{"capture_id":"42","measurement_count":1,"pair_score_count":1}"#,
                status: .ok
            )
        }
        let client = Self.makeClient(transport: transport)

        let median = Components.Schemas.LinearRgb(r: 0.12, g: 0.10, b: 0.02)
        let payload = Components.Schemas.MeasurementUploadRequest(
            scoringAlgorithmVersion: "lps-distance-v1",
            measurements: [
                .init(
                    patchId: "pair_1#first",
                    linearRgbMedian: median,
                    normalizedLinearRgbMedian: nil,
                    stats: .init(
                        sampleCount: 900,
                        clippingFraction: 0.0,
                        mean: median,
                        standardDeviation: Components.Schemas.LinearRgb(r: 0.01, g: 0.01, b: 0.004)
                    )
                )
            ],
            pairScores: [
                .init(
                    pairId: "pair_1",
                    algorithmVersion: "lps-distance-v1",
                    score: nil,
                    similarity: 0.965,
                    distance: 0.035
                )
            ]
        )

        let output = try await client.uploadMeasurements(
            path: .init(captureId: "42"),
            body: .json(payload)
        )

        guard case .ok(let ok) = output else {
            return XCTFail("Expected .ok, got \(output)")
        }
        let response = try ok.body.json
        XCTAssertEqual(response.captureId, "42")
        XCTAssertEqual(response.measurementCount, 1)
        XCTAssertEqual(response.pairScoreCount, 1)

        let json = try await jsonObject(from: capturedBody.value)
        XCTAssertEqual(json["scoring_algorithm_version"] as? String, "lps-distance-v1")

        let measurement = try XCTUnwrap((json["measurements"] as? [[String: Any]])?.first)
        XCTAssertEqual(measurement["patch_id"] as? String, "pair_1#first")
        let linearMedian = try XCTUnwrap(measurement["linear_rgb_median"] as? [String: Any])
        XCTAssertEqual(linearMedian["r"] as? Double, 0.12, accuracy: 1e-9)
        XCTAssertEqual(linearMedian["b"] as? Double, 0.02, accuracy: 1e-9)
        XCTAssertNil(measurement["normalized_linear_rgb_median"])
        let stats = try XCTUnwrap(measurement["stats"] as? [String: Any])
        XCTAssertEqual(stats["sample_count"] as? Int, 900)
        XCTAssertEqual(stats["clipping_fraction"] as? Double, 0.0, accuracy: 1e-9)
        XCTAssertNotNil(stats["mean"] as? [String: Any])
        XCTAssertNotNil(stats["standard_deviation"] as? [String: Any])

        let pairScore = try XCTUnwrap((json["pair_scores"] as? [[String: Any]])?.first)
        XCTAssertEqual(pairScore["pair_id"] as? String, "pair_1")
        XCTAssertEqual(pairScore["algorithm_version"] as? String, "lps-distance-v1")
        XCTAssertEqual(pairScore["similarity"] as? Double, 0.965, accuracy: 1e-9)
        XCTAssertEqual(pairScore["distance"] as? Double, 0.035, accuracy: 1e-9)
        XCTAssertNil(pairScore["score"])
    }

    func testUploadMeasurementsDecodesRowValidationErrors() async throws {
        let transport = StubbedTransport { _, _, _, _ in
            stubbedJSONResponse(
                #"{"errors":{"measurements":[{"patch_id":"pair_1#first","index":0,"errors":{"linear_rgb_median":["is invalid"]}}]}}"#,
                status: .unprocessableEntity
            )
        }
        let client = Self.makeClient(transport: transport)

        let output = try await client.uploadMeasurements(
            path: .init(captureId: "42"),
            body: .json(
                .init(
                    scoringAlgorithmVersion: "lps-distance-v1",
                    measurements: [],
                    pairScores: []
                )
            )
        )

        guard case .unprocessableEntity(let unprocessable) = output else {
            return XCTFail("Expected .unprocessableEntity, got \(output)")
        }
        let error = try unprocessable.body.json
        XCTAssertNotNil(error.errors["measurements"])
    }

    func testUploadJudgmentsSendsPairsAndDecodesCount() async throws {
        let capturedBody = Captured<HTTPBody>()
        let transport = StubbedTransport { request, body, _, operationID in
            capturedBody.value = body
            XCTAssertEqual(request.method, .post)
            XCTAssertEqual(request.path, "/api/v1/captures/42/judgments")
            XCTAssertEqual(operationID, "uploadJudgments")
            return stubbedJSONResponse(#"{"capture_id":"42","judgment_count":1}"#, status: .ok)
        }
        let client = Self.makeClient(transport: transport)

        let output = try await client.uploadJudgments(
            path: .init(captureId: "42"),
            body: .json(.init(judgments: [.init(pairId: "pair_1", judgment: "near_match")]))
        )

        guard case .ok(let ok) = output else {
            return XCTFail("Expected .ok, got \(output)")
        }
        let response = try ok.body.json
        XCTAssertEqual(response.captureId, "42")
        XCTAssertEqual(response.judgmentCount, 1)

        let json = try await jsonObject(from: capturedBody.value)
        let judgment = try XCTUnwrap((json["judgments"] as? [[String: Any]])?.first)
        XCTAssertEqual(judgment["pair_id"] as? String, "pair_1")
        XCTAssertEqual(judgment["judgment"] as? String, "near_match")
    }

    func testFetchRankedResultsDecodesAggregateShape() async throws {
        let transport = StubbedTransport { request, _, _, _ in
            XCTAssertEqual(request.method, .get)
            XCTAssertEqual(request.path, "/api/v1/test_sheets/sheet_123/ranked_results")
            return stubbedJSONResponse(Fixtures.rankedResultsJSON, status: .ok)
        }
        let client = Self.makeClient(transport: transport)

        let output = try await client.fetchRankedResults(path: .init(sheetId: "sheet_123"))

        guard case .ok(let ok) = output else {
            return XCTFail("Expected .ok, got \(output)")
        }
        let results = try ok.body.json
        XCTAssertEqual(results.schemaVersion.rawValue, "lps-ranked-results/v1")
        XCTAssertEqual(results.sheetId, "sheet_123")
        XCTAssertEqual(results.captureCount, 2)
        XCTAssertEqual(results.scoringAlgorithmVersions, ["lps-distance-v1"])
        XCTAssertEqual(results.latestCaptureAt, Self.date("2026-07-26T09:30:00Z"))
        XCTAssertEqual(results.earliestCaptureAt, Self.date("2026-07-25T12:00:00Z"))

        XCTAssertEqual(results.results.count, 2)

        let unjudged = try XCTUnwrap(results.results.first)
        XCTAssertEqual(unjudged.rank, 1)
        XCTAssertEqual(unjudged.pairId, "pair_1")
        XCTAssertEqual(unjudged.scoringAlgorithmVersion, "lps-distance-v1")
        XCTAssertEqual(unjudged.row, 0)
        XCTAssertEqual(unjudged.col, 1)
        XCTAssertEqual(unjudged.sourceColors.colorAHex, "#FF0000")
        XCTAssertEqual(unjudged.sourceColors.colorBHex, "#00FF00")
        XCTAssertEqual(unjudged.score.average, 0.035, accuracy: 1e-9)
        XCTAssertEqual(unjudged.score.latest ?? -1, 0.03, accuracy: 1e-9)
        XCTAssertEqual(unjudged.score.minimum ?? -1, 0.03, accuracy: 1e-9)
        XCTAssertEqual(unjudged.score.maximum ?? -1, 0.04, accuracy: 1e-9)
        XCTAssertEqual(unjudged.score.captureCount, 2)
        XCTAssertEqual(unjudged.score.sampleCount, 2)
        XCTAssertEqual(unjudged.score.algorithmVersions, ["lps-distance-v1"])
        XCTAssertNil(unjudged.currentJudgment)
        XCTAssertNil(unjudged.currentJudgmentObservedAt)
        XCTAssertEqual(unjudged.observationCount, 0)
        XCTAssertNil(unjudged.latestObservation)
        XCTAssertEqual(unjudged.captureCount, 2)

        let judged = try XCTUnwrap(results.results.last)
        XCTAssertEqual(judged.rank, 2)
        XCTAssertEqual(judged.pairId, "pair_2")
        XCTAssertEqual(judged.currentJudgment, "near_match")
        XCTAssertEqual(judged.currentJudgmentObservedAt, Self.date("2026-07-26T10:00:00Z"))
        XCTAssertEqual(judged.observationCount, 1)
        let latestObservation = try XCTUnwrap(judged.latestObservation)
        XCTAssertEqual(latestObservation.judgment, "near_match")
        XCTAssertEqual(latestObservation.observedAt, Self.date("2026-07-26T10:00:00Z"))
    }
}

private enum Fixtures {
    static let manifestJSON = ##"""
    {
      "schema_version": "lps-sheet-manifest/v1",
      "sheet_id": "sheet_123",
      "sheet_version": "lps-letter-grid-v1",
      "manifest_url": "https://color-matching.example/api/v1/test_sheets/sheet_123/manifest",
      "created_at": "2026-07-25T12:00:00Z",
      "page": {"units": "mm", "width": 215.9, "height": 279.4},
      "registration_markers": [
        {"role": "top_left", "shape": "solid_square", "rect": {"x": 12, "y": 12, "width": 8, "height": 8}},
        {"role": "bottom_right", "shape": "solid_square", "rect": {"x": 199.9, "y": 259.4, "width": 8, "height": 8}}
      ],
      "printer_profile": {
        "printer_make_model": "Canon PIXMA PRO-200",
        "paper_type": "Photo Paper Plus Glossy II",
        "ink_type": "CLI-42",
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
    """##

    static let recentSheetsJSON = ##"""
    {
      "sheets": [
        {
          "sheet_id": "sheet_123",
          "manifest_url": "https://color-matching.example/api/v1/test_sheets/sheet_123/manifest",
          "title": null
        },
        {
          "sheet_id": "sheet_456",
          "manifest_url": "https://color-matching.example/api/v1/test_sheets/sheet_456/manifest",
          "title": "July LPS comparison sheet"
        }
      ]
    }
    """##

    static let rankedResultsJSON = ##"""
    {
      "schema_version": "lps-ranked-results/v1",
      "sheet_id": "sheet_123",
      "printer_profile": {
        "printer_make_model": "Canon PIXMA PRO-200",
        "paper_type": "Photo Paper Plus Glossy II",
        "ink_type": "CLI-42",
        "icc_profile": null,
        "print_settings": null,
        "driver_name": null,
        "driver_version": null,
        "calibration_date": null,
        "calibration_version": null,
        "notes": null
      },
      "capture_count": 2,
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
            "latest": 0.03,
            "minimum": 0.03,
            "maximum": 0.04,
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
        },
        {
          "rank": 2,
          "pair_id": "pair_2",
          "scoring_algorithm_version": "lps-distance-v1",
          "row": 1,
          "col": 0,
          "source_colors": {"color_a_hex": "#0000FF", "color_b_hex": "#00FFFF"},
          "score": {
            "average": 0.12,
            "latest": 0.11,
            "minimum": 0.11,
            "maximum": 0.13,
            "capture_count": 2,
            "sample_count": 2,
            "algorithm_versions": ["lps-distance-v1"]
          },
          "current_judgment": "near_match",
          "current_judgment_observed_at": "2026-07-26T10:00:00Z",
          "observation_count": 1,
          "latest_observation": {"judgment": "near_match", "observed_at": "2026-07-26T10:00:00Z"},
          "capture_count": 2,
          "latest_capture_at": "2026-07-26T09:30:00Z",
          "earliest_capture_at": "2026-07-25T12:00:00Z"
        }
      ]
    }
    """##
}
