import Foundation
import OpenAPIGenerated
import OpenAPIURLSession
import XCTest

final class GeneratedClientTests: XCTestCase {
    override func tearDown() {
        StubAPIURLProtocol.handler = nil
        super.tearDown()
    }

    func testGetTestSheetManifestDecodesServedManifest() async throws {
        var capturedRequest: URLRequest?
        StubAPIURLProtocol.handler = { request in
            capturedRequest = request
            return (StubAPIFixture.httpResponse(request, status: 200), Data(Self.manifestJSON.utf8))
        }

        let response = try await makeClient().getTestSheetManifest(.init(path: .init(sheet_id: "sheet_1")))

        XCTAssertEqual(capturedRequest?.url?.path, "/api/v1/test_sheets/sheet_1/manifest")
        XCTAssertEqual(capturedRequest?.httpMethod, "GET")
        guard case .ok(let output) = response else {
            return XCTFail("Expected .ok, got \(response)")
        }
        let manifest = try output.body.json
        XCTAssertEqual(manifest.schemaVersion.rawValue, "lps-sheet-manifest/v1")
        XCTAssertEqual(manifest.sheetId, "sheet_1")
        XCTAssertEqual(manifest.sheetVersion, "lps-letter-grid-v1")
        XCTAssertEqual(manifest.page?.units, "mm")
        XCTAssertEqual(manifest.page?.width, 215.9)
        XCTAssertEqual(manifest.registrationMarkers?.count, 1)
        XCTAssertEqual(manifest.captureProfile.scoringAlgorithmVersion.rawValue, "lps-distance-v1")
        let patch = try XCTUnwrap(manifest.patches?.first)
        XCTAssertEqual(patch.id, "pair_1#first")
        XCTAssertEqual(patch.role, "pair_color")
        XCTAssertEqual(patch.pairId, "pair_1")
        XCTAssertEqual(patch.sourceColor, "#FF0000")
        XCTAssertEqual(patch.rect.x, 16)
        XCTAssertNil(patch.referenceRole)
        let pair = try XCTUnwrap(manifest.pairs?.first)
        XCTAssertEqual(pair.id, "pair_1")
        XCTAssertEqual(pair.firstPatchId, "pair_1#first")
        XCTAssertEqual(pair.secondPatchId, "pair_1#second")
        XCTAssertEqual(pair.sourceColors, ["#FF0000", "#00FF00"])
        XCTAssertEqual(pair.gridRow, 0)
        XCTAssertEqual(pair.gridCol, 1)
    }

    func testGetTestSheetManifestMapsNotFound() async throws {
        StubAPIURLProtocol.handler = { request in
            (StubAPIFixture.httpResponse(request, status: 404), Data(#"{"errors":{"detail":"Sheet not found"}}"#.utf8))
        }

        let response = try await makeClient().getTestSheetManifest(.init(path: .init(sheet_id: "missing")))

        guard case .notFound = response else {
            return XCTFail("Expected .notFound, got \(response)")
        }
    }

    func testGetTestSheetManifestMapsUnauthorized() async throws {
        StubAPIURLProtocol.handler = { request in
            (StubAPIFixture.httpResponse(request, status: 401), Data(#"{"errors":{"detail":"Unauthorized"}}"#.utf8))
        }

        let response = try await makeClient().getTestSheetManifest(.init(path: .init(sheet_id: "sheet_1")))

        guard case .unauthorized = response else {
            return XCTFail("Expected .unauthorized, got \(response)")
        }
    }

    func testListRecentTestSheetsDecodesSheets() async throws {
        var capturedRequest: URLRequest?
        StubAPIURLProtocol.handler = { request in
            capturedRequest = request
            return (StubAPIFixture.httpResponse(request, status: 200), Data(Self.recentSheetsJSON.utf8))
        }

        let response = try await makeClient().listRecentTestSheets(.init())

        XCTAssertEqual(capturedRequest?.url?.path, "/api/v1/test_sheets/recent")
        XCTAssertEqual(capturedRequest?.httpMethod, "GET")
        guard case .ok(let output) = response else {
            return XCTFail("Expected .ok, got \(response)")
        }
        let sheets = try output.body.json.sheets
        XCTAssertEqual(sheets.count, 2)
        XCTAssertEqual(sheets.first?.sheetId, "sheet_1")
        XCTAssertEqual(sheets.first?.manifestUrl, "https://example.test/api/v1/test_sheets/sheet_1/manifest")
        XCTAssertNil(sheets.last?.title)
    }

    func testCreateCaptureEncodesNestedMetadataAndQuality() async throws {
        var capturedRequest: URLRequest?
        StubAPIURLProtocol.handler = { request in
            capturedRequest = request
            return (StubAPIFixture.httpResponse(request, status: 201), Data(#"{"capture_id":"cap_1"}"#.utf8))
        }

        let captureRequest = Components.Schemas.CaptureRequest(
            metadata: Components.Schemas.CaptureMetadata(
                deviceModel: "iPhone 15",
                lens: "built_in_wide_angle",
                exposureDurationSeconds: 0.016,
                iso: 100,
                focusLensPosition: 0.42,
                whiteBalanceGains: nil,
                imageWidth: 4032,
                imageHeight: 3024,
                appVersion: "0.1.0",
                timestamp: Date(timeIntervalSince1970: 0)
            ),
            quality: .init(
                detectedMarkerCount: 4,
                blurScore: 0.82,
                rejections: []
            )
        )

        let response = try await makeClient().createCapture(
            .init(path: .init(sheet_id: "sheet_1"), body: .json(captureRequest))
        )

        XCTAssertEqual(capturedRequest?.url?.path, "/api/v1/test_sheets/sheet_1/captures")
        XCTAssertEqual(capturedRequest?.httpMethod, "POST")
        let contentType = try XCTUnwrap(capturedRequest?.value(forHTTPHeaderField: "Content-Type"))
        XCTAssertTrue(contentType.hasPrefix("application/json"))
        let json = try XCTUnwrap(StubAPIFixture.jsonObject(from: StubAPIFixture.bodyData(of: capturedRequest)) as? [String: Any])
        let metadata = try XCTUnwrap(json["metadata"] as? [String: Any])
        XCTAssertEqual(metadata["device_model"] as? String, "iPhone 15")
        XCTAssertEqual(metadata["iso"] as? Int, 100)
        XCTAssertEqual(metadata["image_width"] as? Int, 4032)
        let timestamp = try XCTUnwrap(metadata["timestamp"] as? String)
        XCTAssertTrue(timestamp.hasPrefix("1970-01-01T00:00:00"))
        let quality = try XCTUnwrap(json["quality"] as? [String: Any])
        XCTAssertEqual(quality["detected_marker_count"] as? Int, 4)
        XCTAssertEqual(quality["blur_score"] as? Double, 0.82)
        XCTAssertEqual(quality["rejections"] as? [String], [])
        guard case .created(let output) = response else {
            return XCTFail("Expected .created, got \(response)")
        }
        XCTAssertEqual(try output.body.json.captureId, "cap_1")
    }

    func testUploadMeasurementsEncodesMediansAndScoresAndDecodesReceipt() async throws {
        var capturedRequest: URLRequest?
        StubAPIURLProtocol.handler = { request in
            capturedRequest = request
            return (
                StubAPIFixture.httpResponse(request, status: 200),
                Data(#"{"capture_id":"cap_9","measurement_count":2,"pair_score_count":1}"#.utf8)
            )
        }

        let median = Components.Schemas.RgbPayload(value2: .init(r: 0.12, g: 0.1, b: 0.02))
        let upload = Components.Schemas.MeasurementUploadRequest(
            measurements: [
                .init(
                    patchId: "pair_1#first",
                    linearRgbMedian: median,
                    normalizedLinearRgbMedian: median
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

        let response = try await makeClient().uploadMeasurements(
            .init(path: .init(capture_id: "cap_9"), body: .json(upload))
        )

        XCTAssertEqual(capturedRequest?.url?.path, "/api/v1/captures/cap_9/measurements")
        XCTAssertEqual(capturedRequest?.httpMethod, "POST")
        let json = try XCTUnwrap(StubAPIFixture.jsonObject(from: StubAPIFixture.bodyData(of: capturedRequest)) as? [String: Any])
        let measurement = try XCTUnwrap((json["measurements"] as? [[String: Any]])?.first)
        XCTAssertEqual(measurement["patch_id"] as? String, "pair_1#first")
        let linearMedian = try XCTUnwrap(measurement["linear_rgb_median"] as? [String: Any])
        XCTAssertEqual(linearMedian["r"] as? Double, 0.12)
        let normalizedMedian = try XCTUnwrap(measurement["normalized_linear_rgb_median"] as? [String: Any])
        XCTAssertEqual(normalizedMedian["b"] as? Double, 0.02)
        let score = try XCTUnwrap((json["pair_scores"] as? [[String: Any]])?.first)
        XCTAssertEqual(score["pair_id"] as? String, "pair_1")
        XCTAssertEqual(score["algorithm_version"] as? String, "lps-distance-v1")
        XCTAssertEqual(score["similarity"] as? Double, 0.965)
        guard case .ok(let output) = response else {
            return XCTFail("Expected .ok, got \(response)")
        }
        let receipt = try output.body.json
        XCTAssertEqual(receipt.captureId, "cap_9")
        XCTAssertEqual(receipt.measurementCount, 2)
        XCTAssertEqual(receipt.pairScoreCount, 1)
    }

    func testUploadMeasurementsMapsUnprocessableContent() async throws {
        StubAPIURLProtocol.handler = { request in
            (
                StubAPIFixture.httpResponse(request, status: 422),
                Data(
                    #"{"errors":{"measurements":[{"patch_id":"pair_1#first","index":0,"errors":{"linear_rgb_median":["is invalid"]}}]}}"#
                        .utf8
                )
            )
        }

        let median = Components.Schemas.RgbPayload(value2: .init(r: 0.12, g: 0.1, b: 0.02))
        let upload = Components.Schemas.MeasurementUploadRequest(
            measurements: [
                .init(patchId: "pair_1#first", linearRgbMedian: median, normalizedLinearRgbMedian: median)
            ]
        )

        let response = try await makeClient().uploadMeasurements(
            .init(path: .init(capture_id: "cap_9"), body: .json(upload))
        )

        guard case .unprocessableContent = response else {
            return XCTFail("Expected .unprocessableContent, got \(response)")
        }
    }

    func testUploadJudgmentsEncodesJudgmentsAndDecodesReceipt() async throws {
        var capturedRequest: URLRequest?
        StubAPIURLProtocol.handler = { request in
            capturedRequest = request
            return (
                StubAPIFixture.httpResponse(request, status: 200),
                Data(#"{"capture_id":"cap_9","judgment_count":1}"#.utf8)
            )
        }

        let upload = Components.Schemas.JudgmentUploadRequest(
            judgments: [.init(pairId: "pair_1", judgment: "near_match")]
        )

        let response = try await makeClient().uploadJudgments(
            .init(path: .init(capture_id: "cap_9"), body: .json(upload))
        )

        XCTAssertEqual(capturedRequest?.url?.path, "/api/v1/captures/cap_9/judgments")
        XCTAssertEqual(capturedRequest?.httpMethod, "POST")
        let json = try XCTUnwrap(StubAPIFixture.jsonObject(from: StubAPIFixture.bodyData(of: capturedRequest)) as? [String: Any])
        let judgment = try XCTUnwrap((json["judgments"] as? [[String: Any]])?.first)
        XCTAssertEqual(judgment["pair_id"] as? String, "pair_1")
        XCTAssertEqual(judgment["judgment"] as? String, "near_match")
        guard case .ok(let output) = response else {
            return XCTFail("Expected .ok, got \(response)")
        }
        XCTAssertEqual(try output.body.json.judgmentCount, 1)
    }

    func testGetRankedResultsDecodesServedResults() async throws {
        var capturedRequest: URLRequest?
        StubAPIURLProtocol.handler = { request in
            capturedRequest = request
            return (StubAPIFixture.httpResponse(request, status: 200), Data(Self.rankedResultsJSON.utf8))
        }

        let response = try await makeClient().getRankedResults(.init(path: .init(sheet_id: "sheet_1")))

        XCTAssertEqual(capturedRequest?.url?.path, "/api/v1/test_sheets/sheet_1/ranked_results")
        XCTAssertEqual(capturedRequest?.httpMethod, "GET")
        guard case .ok(let output) = response else {
            return XCTFail("Expected .ok, got \(response)")
        }
        let ranked = try output.body.json
        XCTAssertEqual(ranked.schemaVersion.rawValue, "lps-ranked-results/v1")
        XCTAssertEqual(ranked.sheetId, "sheet_1")
        XCTAssertEqual(ranked.scoringAlgorithmVersions, ["lps-distance-v1"])
        let top = try XCTUnwrap(ranked.results?.first)
        XCTAssertEqual(top.rank, 1)
        XCTAssertEqual(top.pairId, "pair_1")
        XCTAssertEqual(top.scoringAlgorithmVersion, "lps-distance-v1")
        XCTAssertEqual(top.sourceColors?.colorAHex, "#FF0000")
        XCTAssertEqual(top.sourceColors?.colorBHex, "#00FF00")
        XCTAssertEqual(top.score?.average, 0.04)
        XCTAssertEqual(top.score?.latest, 0.035)
        XCTAssertEqual(top.currentJudgment, "near_match")
    }

    private func makeClient() -> Client {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubAPIURLProtocol.self]
        return Client(
            serverURL: URL(string: "https://example.test")!,
            transport: URLSessionTransport(
                configuration: .init(session: URLSession(configuration: configuration))
            )
        )
    }

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
        },
        {
          "id": "pair_1#second",
          "role": "pair_color",
          "pair_id": "pair_1",
          "pair_side": "second",
          "reference_role": null,
          "source_color": "#00FF00",
          "safe_inset_mm": 1.5,
          "rect": {"x": 16, "y": 52, "width": 16, "height": 10}
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

    private static let recentSheetsJSON =
        #"{"sheets":[{"sheet_id":"sheet_1","manifest_url":"https://example.test/api/v1/test_sheets/sheet_1/manifest","title":null},{"sheet_id":"sheet_2","manifest_url":"https://example.test/api/v1/test_sheets/sheet_2/manifest","title":null}]}"#

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
      "capture_count": 3,
      "latest_capture_at": "2026-08-01T10:00:00Z",
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
            "capture_count": 3,
            "sample_count": 12,
            "algorithm_versions": ["lps-distance-v1"]
          },
          "current_judgment": "near_match",
          "current_judgment_observed_at": "2026-08-01T10:05:00Z",
          "observation_count": 4,
          "latest_observation": {"judgment": "near_match", "observed_at": "2026-08-01T10:05:00Z"},
          "capture_count": 3,
          "latest_capture_at": "2026-08-01T10:00:00Z",
          "earliest_capture_at": "2026-07-25T12:00:00Z"
        }
      ]
    }
    """
}
