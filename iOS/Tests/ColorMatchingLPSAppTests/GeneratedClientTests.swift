#if canImport(ColorMatchingOpenAPI) && canImport(OpenAPIRuntime)
import ColorMatchingOpenAPI
import OpenAPIRuntime
import XCTest

final class GeneratedClientTests: XCTestCase {
    private typealias Handler = (HTTPRequest, HTTPBody?, String) async throws -> (HTTPResponse, HTTPBody?)

    func testGetTestSheetManifestDecodesSheetPatchesAndPairs() async throws {
        let client = makeClient { request, _, operationID in
            XCTAssertEqual(operationID, "getTestSheetManifest")
            XCTAssertEqual(request.method, .get)
            XCTAssertEqual(request.path, "/api/v1/test_sheets/sheet_1/manifest")
            return Self.jsonResponse(200, Self.manifestJSON)
        }

        let response = try await client.getTestSheetManifest(.init(path: .init(sheetId: "sheet_1")))

        guard case .ok(let ok) = response else { return XCTFail("Expected .ok, got \(response)") }
        guard case .json(let manifest) = ok.body else { return XCTFail("Expected JSON body, got \(String(describing: ok.body))") }
        XCTAssertEqual(manifest.sheetId, "sheet_1")
        XCTAssertEqual(manifest.patches.first?.id, "pair_1#first")
        XCTAssertEqual(manifest.patches.first?.pairId, "pair_1")
        XCTAssertEqual(manifest.pairs.first?.id, "pair_1")
        XCTAssertEqual(manifest.pairs.first?.sourceColors, ["#FF0000", "#00FF00"])
        XCTAssertEqual(manifest.registrationMarkers.first?.shape, "solid_square")
    }

    func testListRecentTestSheetsDecodesNullableTitle() async throws {
        let client = makeClient { request, _, operationID in
            XCTAssertEqual(operationID, "listRecentTestSheets")
            XCTAssertEqual(request.method, .get)
            XCTAssertEqual(request.path, "/api/v1/test_sheets/recent")
            return Self.jsonResponse(200, Self.recentSheetsJSON)
        }

        let response = try await client.listRecentTestSheets(.init())

        guard case .ok(let ok) = response else { return XCTFail("Expected .ok, got \(response)") }
        guard case .json(let body) = ok.body else { return XCTFail("Expected JSON body, got \(String(describing: ok.body))") }
        XCTAssertEqual(body.sheets.count, 1)
        XCTAssertEqual(body.sheets.first?.sheetId, "sheet_1")
        XCTAssertEqual(body.sheets.first?.manifestUrl, "https://example.test/api/v1/test_sheets/sheet_1/manifest")
        XCTAssertNil(body.sheets.first?.title)
    }

    func testCreateCaptureEncodesMetadataAndQualityAndDecodesCaptureID() async throws {
        var capturedBody: Data?
        let client = makeClient { request, body, operationID in
            XCTAssertEqual(operationID, "createCapture")
            XCTAssertEqual(request.method, .post)
            XCTAssertEqual(request.path, "/api/v1/test_sheets/sheet_1/captures")
            if let body {
                capturedBody = try await Data(collecting: body, upTo: Self.maximumBodyBytes)
            }
            return Self.jsonResponse(201, #"{"capture_id":"1"}"#)
        }

        let response = try await client.createCapture(.init(path: .init(sheetId: "sheet_1"), body: .json(Self.captureRequest)))

        let json = try Self.jsonObject(capturedBody)
        let metadata = try Self.object(json, "metadata")
        XCTAssertEqual(metadata["device_model"] as? String, "iPhone 15")
        XCTAssertEqual(metadata["lens"] as? String, "built_in_wide_angle")
        XCTAssertEqual(metadata["image_width"] as? Int, 4032)
        XCTAssertEqual(metadata["image_height"] as? Int, 3024)
        XCTAssertEqual(metadata["app_version"] as? String, "0.1.0")
        XCTAssertNotNil(metadata["timestamp"] as? String)
        let gains = try Self.object(metadata, "white_balance_gains")
        XCTAssertEqual(gains["red"] as? Double, 1.2)
        let quality = try Self.object(json, "quality")
        XCTAssertEqual(quality["detected_marker_count"] as? Int, 4)
        XCTAssertEqual(quality["blur_score"] as? Double, 0.82)
        XCTAssertEqual(quality["rejections"] as? [String], [])

        guard case .created(let created) = response else { return XCTFail("Expected .created, got \(response)") }
        guard case .json(let body) = created.body else { return XCTFail("Expected JSON body, got \(String(describing: created.body))") }
        XCTAssertEqual(body.captureId, "1")
    }

    func testUploadMeasurementsEncodesStatsAndScoresAndDecodesCounts() async throws {
        var capturedBody: Data?
        let client = makeClient { request, body, operationID in
            XCTAssertEqual(operationID, "uploadMeasurements")
            XCTAssertEqual(request.method, .post)
            XCTAssertEqual(request.path, "/api/v1/captures/1/measurements")
            if let body {
                capturedBody = try await Data(collecting: body, upTo: Self.maximumBodyBytes)
            }
            return Self.jsonResponse(200, #"{"capture_id":"1","measurement_count":1,"pair_score_count":1}"#)
        }

        let response = try await client.uploadMeasurements(
            .init(path: .init(captureId: "1"), body: .json(Self.measurementUploadRequest))
        )

        let json = try Self.jsonObject(capturedBody)
        XCTAssertEqual(json["scoring_algorithm_version"] as? String, "lps-distance-v1")
        let measurement = try Self.firstElement(of: json, "measurements")
        XCTAssertEqual(measurement["patch_id"] as? String, "pair_1#first")
        XCTAssertEqual(try Self.object(measurement, "linear_rgb_median")["r"] as? Double, 0.12)
        let stats = try Self.object(measurement, "stats")
        XCTAssertEqual(stats["sample_count"] as? Int, 900)
        XCTAssertEqual(stats["clipping_fraction"] as? Double, 0)
        let score = try Self.firstElement(of: json, "pair_scores")
        XCTAssertEqual(score["pair_id"] as? String, "pair_1")
        XCTAssertEqual(score["distance"] as? Double, 0.035)
        XCTAssertEqual(score["similarity"] as? Double, 0.965)
        XCTAssertEqual(score["algorithm_version"] as? String, "lps-distance-v1")

        guard case .ok(let ok) = response else { return XCTFail("Expected .ok, got \(response)") }
        guard case .json(let body) = ok.body else { return XCTFail("Expected JSON body, got \(String(describing: ok.body))") }
        XCTAssertEqual(body.captureId, "1")
        XCTAssertEqual(body.measurementCount, 1)
        XCTAssertEqual(body.pairScoreCount, 1)
    }

    func testUploadJudgmentsEncodesPairJudgmentsAndDecodesCount() async throws {
        var capturedBody: Data?
        let client = makeClient { request, body, operationID in
            XCTAssertEqual(operationID, "uploadJudgments")
            XCTAssertEqual(request.method, .post)
            XCTAssertEqual(request.path, "/api/v1/captures/1/judgments")
            if let body {
                capturedBody = try await Data(collecting: body, upTo: Self.maximumBodyBytes)
            }
            return Self.jsonResponse(200, #"{"capture_id":"1","judgment_count":1}"#)
        }

        let request = Operations.uploadJudgments.Input(
            path: .init(captureId: "1"),
            body: .json(
                Components.Schemas.JudgmentUploadRequest(
                    judgments: [Components.Schemas.PairJudgment(pairId: "pair_1", judgment: "near_match")]
                )
            )
        )
        let response = try await client.uploadJudgments(request)

        let json = try Self.jsonObject(capturedBody)
        let judgment = try Self.firstElement(of: json, "judgments")
        XCTAssertEqual(judgment["pair_id"] as? String, "pair_1")
        XCTAssertEqual(judgment["judgment"] as? String, "near_match")

        guard case .ok(let ok) = response else { return XCTFail("Expected .ok, got \(response)") }
        guard case .json(let body) = ok.body else { return XCTFail("Expected JSON body, got \(String(describing: ok.body))") }
        XCTAssertEqual(body.captureId, "1")
        XCTAssertEqual(body.judgmentCount, 1)
    }

    func testGetRankedResultsDecodesRankedPairs() async throws {
        let client = makeClient { request, _, operationID in
            XCTAssertEqual(operationID, "getRankedResults")
            XCTAssertEqual(request.method, .get)
            XCTAssertEqual(request.path, "/api/v1/test_sheets/sheet_1/ranked_results")
            return Self.jsonResponse(200, Self.rankedResultsJSON)
        }

        let response = try await client.getRankedResults(.init(path: .init(sheetId: "sheet_1")))

        guard case .ok(let ok) = response else { return XCTFail("Expected .ok, got \(response)") }
        guard case .json(let body) = ok.body else { return XCTFail("Expected JSON body, got \(String(describing: ok.body))") }
        XCTAssertEqual(body.sheetId, "sheet_1")
        XCTAssertEqual(body.scoringAlgorithmVersions, ["lps-distance-v1"])
        XCTAssertEqual(body.results.first?.rank, 1)
        XCTAssertEqual(body.results.first?.pairId, "pair_1")
        XCTAssertEqual(body.results.first?.currentJudgment, "near_match")
    }

    private func makeClient(_ handler: @escaping Handler) -> APIProtocol {
        Client(serverURL: Self.serverURL, transport: StubTransport(handler: handler))
    }

    private enum StubError: Error { case invalidBody }

    private static let serverURL = URL(string: "https://example.test")!
    private static let maximumBodyBytes = 1 << 20

    private static func jsonResponse(_ statusCode: Int, _ payload: String) -> (HTTPResponse, HTTPBody?) {
        (HTTPResponse(status: .init(code: statusCode), headerFields: [.contentType: "application/json"]), HTTPBody(payload))
    }

    private static func jsonObject(_ data: Data?, file: StaticString = #filePath, line: UInt = #line) throws -> [String: Any] {
        guard let data, let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            XCTFail("Captured request body is not a JSON object", file: file, line: line)
            throw StubError.invalidBody
        }
        return object
    }

    private static func object(_ json: [String: Any], _ key: String, file: StaticString = #filePath, line: UInt = #line) throws -> [String: Any] {
        guard let value = json[key] as? [String: Any] else {
            XCTFail("Key \"\(key)\" is missing or not an object in \(json)", file: file, line: line)
            throw StubError.invalidBody
        }
        return value
    }

    private static func firstElement(of json: [String: Any], _ key: String, file: StaticString = #filePath, line: UInt = #line) throws -> [String: Any] {
        guard let value = json[key] as? [[String: Any]], let first = value.first else {
            XCTFail("Key \"\(key)\" is missing or not a non-empty array in \(json)", file: file, line: line)
            throw StubError.invalidBody
        }
        return first
    }

    private static let captureRequest = Components.Schemas.CaptureRequest(
        metadata: Components.Schemas.CaptureMetadata(
            deviceModel: "iPhone 15",
            lens: "built_in_wide_angle",
            exposureDurationSeconds: 0.016,
            iso: 100,
            focusLensPosition: 0.42,
            whiteBalanceGains: Components.Schemas.WhiteBalanceGains(red: 1.2, green: 1.0, blue: 1.4),
            imageWidth: 4032,
            imageHeight: 3024,
            appVersion: "0.1.0",
            timestamp: Date(timeIntervalSince1970: 1_785_000_000)
        ),
        quality: Components.Schemas.CaptureQuality(detectedMarkerCount: 4, blurScore: 0.82, rejections: [])
    )

    private static let measurementUploadRequest = Components.Schemas.MeasurementUploadRequest(
        scoringAlgorithmVersion: "lps-distance-v1",
        measurements: [
            Components.Schemas.MeasurementUpload(
                patchId: "pair_1#first",
                linearRgbMedian: Components.Schemas.Rgb(r: 0.12, g: 0.10, b: 0.02),
                normalizedLinearRgbMedian: Components.Schemas.Rgb(r: 0.15, g: 0.12, b: 0.02),
                stats: Components.Schemas.MeasurementStats(
                    sampleCount: 900,
                    clippingFraction: 0,
                    mean: Components.Schemas.Rgb(r: 0.12, g: 0.10, b: 0.02),
                    standardDeviation: Components.Schemas.Rgb(r: 0.01, g: 0.01, b: 0.004)
                )
            )
        ],
        pairScores: [
            Components.Schemas.PairScoreUpload(
                pairId: "pair_1",
                distance: 0.035,
                similarity: 0.965,
                algorithmVersion: "lps-distance-v1"
            )
        ]
    )

    private static let manifestJSON = #"""
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
        "paper_type": "paper",
        "ink_type": "ink",
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
    """#

    private static let recentSheetsJSON = #"""
    {
      "sheets": [
        {
          "sheet_id": "sheet_1",
          "manifest_url": "https://example.test/api/v1/test_sheets/sheet_1/manifest",
          "title": null
        }
      ]
    }
    """#

    private static let rankedResultsJSON = #"""
    {
      "schema_version": "lps-ranked-results/v1",
      "sheet_id": "sheet_1",
      "printer_profile": {
        "printer_make_model": "Research printer",
        "paper_type": "paper",
        "ink_type": "ink",
        "icc_profile": null,
        "print_settings": {},
        "driver_name": null,
        "driver_version": null,
        "calibration_date": null,
        "calibration_version": null,
        "notes": null
      },
      "capture_count": 2,
      "latest_capture_at": "2026-08-01T10:00:00Z",
      "earliest_capture_at": "2026-07-30T09:00:00Z",
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
          "current_judgment_observed_at": "2026-08-01T11:00:00Z",
          "observation_count": 1,
          "latest_observation": {"judgment": "near_match", "observed_at": "2026-08-01T11:00:00Z"},
          "capture_count": 2,
          "latest_capture_at": "2026-08-01T10:00:00Z",
          "earliest_capture_at": "2026-07-30T09:00:00Z"
        }
      ]
    }
    """#
}

private struct StubTransport: ClientTransport {
    private let handler: (HTTPRequest, HTTPBody?, String) async throws -> (HTTPResponse, HTTPBody?)

    fileprivate init(handler: @escaping (HTTPRequest, HTTPBody?, String) async throws -> (HTTPResponse, HTTPBody?)) {
        self.handler = handler
    }

    fileprivate func send(_ request: HTTPRequest, body: HTTPBody?, baseURL: URL, operationID: String) async throws -> (HTTPResponse, HTTPBody?) {
        try await handler(request, body, operationID)
    }
}
#else
import XCTest

final class GeneratedOpenAPIClientNotWiredTests: XCTestCase {
    func testGeneratedOpenAPIClientModuleIsWiredIntoPackage() {
        XCTFail("ColorMatchingOpenAPI generated client target does not exist yet; vendor iOS/OpenAPI/openapi.json and add swift-openapi-generator + swift-openapi-runtime to iOS/Package.swift (see docs/openapi-generated-client-tests.md)")
    }
}
#endif
