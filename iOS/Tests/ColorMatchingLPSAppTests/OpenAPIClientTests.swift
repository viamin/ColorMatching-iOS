#if canImport(ColorMatchingOpenAPI)
import ColorMatchingOpenAPI
import Foundation
import OpenAPIRuntime
import XCTest

/// Exercises the generated OpenAPI client (swift-openapi-generator) against
/// local stubbed responses shaped like the published `color_matching` API.
/// No live server is contacted: every response comes from
/// OpenAPIStubURLProtocol, so these tests run in plain `swift test` CI.
///
/// This file activates automatically once the ColorMatchingOpenAPI target
/// exists (issue #5 implementation). OperationIds, component titles, and the
/// vendoring refinements it relies on are pinned in
/// docs/openapi-client-migration.md and guarded by
/// OpenAPIMigrationArtifactsTests.
final class OpenAPIClientTests: XCTestCase {
    override func tearDown() {
        OpenAPIStubURLProtocol.handler = nil
        super.tearDown()
    }

    func testFetchSheetManifestSendsGETAndDecodesPublishedManifest() async throws {
        var capturedRequest: URLRequest?
        OpenAPIStubURLProtocol.handler = { request in
            capturedRequest = request
            return (Self.httpResponse(request, status: 200), Data(Self.manifestJSON.utf8))
        }

        let output = try await makeClient().fetchSheetManifest(
            Operations.fetchSheetManifest.Input(path: .init(sheet_id: "sheet_123"))
        )

        XCTAssertEqual(capturedRequest?.httpMethod, "GET")
        XCTAssertEqual(capturedRequest?.url?.path, "/api/v1/test_sheets/sheet_123/manifest")
        guard case .ok(let ok) = output else {
            return XCTFail("Expected .ok response, got: \(output)")
        }
        let manifest = try ok.body.json
        XCTAssertEqual(manifest.schema_version, "lps-sheet-manifest/v1")
        XCTAssertEqual(manifest.sheet_id, "sheet_123")
        XCTAssertEqual(manifest.patches.first?.id, "pair_1#first")
        XCTAssertEqual(manifest.patches.first?.pair_id, "pair_1")
        XCTAssertEqual(manifest.patches.first?.rect.width, 16)
        XCTAssertEqual(manifest.pairs.first?.source_colors.first, "#FF0000")
    }

    func testFetchRecentSheetsDecodesNullableTitles() async throws {
        OpenAPIStubURLProtocol.handler = { request in
            (
                Self.httpResponse(request, status: 200),
                Data(#"{"sheets":[{"sheet_id":"sheet_1","manifest_url":"https://example.test/api/v1/test_sheets/sheet_1/manifest","title":null},{"sheet_id":"sheet_2","manifest_url":"https://example.test/api/v1/test_sheets/sheet_2/manifest","title":"July LPS comparison sheet"}]}"#.utf8)
            )
        }

        let output = try await makeClient().fetchRecentSheets(Operations.fetchRecentSheets.Input())

        guard case .ok(let ok) = output else {
            return XCTFail("Expected .ok response, got: \(output)")
        }
        let payload = try ok.body.json
        XCTAssertEqual(payload.sheets.count, 2)
        XCTAssertEqual(payload.sheets[0].sheet_id, "sheet_1")
        XCTAssertNil(payload.sheets[0].title)
        XCTAssertEqual(payload.sheets[1].title, "July LPS comparison sheet")
    }

    func testCreateCapturePostsMetadataAndQualityAndDecodesCaptureID() async throws {
        var capturedBody: Data?
        OpenAPIStubURLProtocol.handler = { request in
            capturedBody = request.httpBodyStream.flatMap(Self.readBody) ?? request.httpBody
            XCTAssertEqual(request.url?.path, "/api/v1/test_sheets/sheet_123/captures")
            XCTAssertEqual(request.httpMethod, "POST")
            return (
                Self.httpResponse(request, status: 201),
                Data(#"{"capture_id":"cap_1"}"#.utf8)
            )
        }

        let output = try await makeClient().createCapture(
            Operations.createCapture.Input(
                path: .init(sheet_id: "sheet_123"),
                body: .json(
                    Components.Schemas.CaptureRequest(
                        metadata: Components.Schemas.CaptureMetadata(
                            device_model: "iPhone 15",
                            lens: "built_in_wide_angle",
                            image_width: 4032,
                            image_height: 3024,
                            app_version: "0.1.0",
                            timestamp: Date(timeIntervalSince1970: 0)
                        ),
                        quality: Components.Schemas.CaptureRequest.QualityPayload(
                            detected_marker_count: 4,
                            blur_score: 0.82,
                            rejections: []
                        )
                    )
                )
            )
        )

        guard case .created(let created) = output else {
            return XCTFail("Expected .created response, got: \(output)")
        }
        XCTAssertEqual(try created.body.json.capture_id, "cap_1")
        let json = try XCTUnwrap(Self.jsonObject(from: capturedBody) as? [String: Any])
        let metadata = try XCTUnwrap(json["metadata"] as? [String: Any])
        XCTAssertEqual(metadata["device_model"] as? String, "iPhone 15")
        XCTAssertEqual(metadata["image_width"] as? Int, 4032)
        XCTAssertNotNil(metadata["timestamp"])
        let quality = try XCTUnwrap(json["quality"] as? [String: Any])
        XCTAssertEqual(quality["detected_marker_count"] as? Int, 4)
        XCTAssertEqual(quality["rejections"] as? [String], [])
    }

    func testUploadMeasurementsPostsMeasurementsAndScoresAndDecodesCounts() async throws {
        var capturedBody: Data?
        OpenAPIStubURLProtocol.handler = { request in
            capturedBody = request.httpBodyStream.flatMap(Self.readBody) ?? request.httpBody
            XCTAssertEqual(request.url?.path, "/api/v1/captures/cap_1/measurements")
            XCTAssertEqual(request.httpMethod, "POST")
            return (
                Self.httpResponse(request, status: 200),
                Data(#"{"capture_id":"cap_1","measurement_count":1,"pair_score_count":1}"#.utf8)
            )
        }

        let channels = Components.Schemas.RgbPayload(r: 0.12, g: 0.1, b: 0.02)
        let output = try await makeClient().uploadMeasurements(
            Operations.uploadMeasurements.Input(
                path: .init(capture_id: "cap_1"),
                body: .json(
                    Components.Schemas.MeasurementUploadRequest(
                        measurements: [
                            .init(
                                patch_id: "pair_1#first",
                                linear_rgb_median: channels,
                                normalized_linear_rgb_median: channels
                            )
                        ],
                        pair_scores: [
                            .init(
                                pair_id: "pair_1",
                                algorithm_version: "lps-distance-v1",
                                similarity: 0.965,
                                distance: 0.035
                            )
                        ]
                    )
                )
            )
        )

        guard case .ok(let ok) = output else {
            return XCTFail("Expected .ok response, got: \(output)")
        }
        let payload = try ok.body.json
        XCTAssertEqual(payload.capture_id, "cap_1")
        XCTAssertEqual(payload.measurement_count, 1)
        XCTAssertEqual(payload.pair_score_count, 1)
        let json = try XCTUnwrap(Self.jsonObject(from: capturedBody) as? [String: Any])
        let measurement = try XCTUnwrap((json["measurements"] as? [[String: Any]])?.first)
        XCTAssertEqual(measurement["patch_id"] as? String, "pair_1#first")
        let median = try XCTUnwrap(measurement["linear_rgb_median"] as? [String: Double])
        XCTAssertEqual(median["r"] ?? 0, 0.12, accuracy: 0.0001)
        let pairScore = try XCTUnwrap((json["pair_scores"] as? [[String: Any]])?.first)
        XCTAssertEqual(pairScore["pair_id"] as? String, "pair_1")
        XCTAssertEqual(pairScore["algorithm_version"] as? String, "lps-distance-v1")
    }

    func testUploadJudgmentsPostsJudgmentsAndDecodesCount() async throws {
        var capturedBody: Data?
        OpenAPIStubURLProtocol.handler = { request in
            capturedBody = request.httpBodyStream.flatMap(Self.readBody) ?? request.httpBody
            XCTAssertEqual(request.url?.path, "/api/v1/captures/cap_1/judgments")
            XCTAssertEqual(request.httpMethod, "POST")
            return (
                Self.httpResponse(request, status: 200),
                Data(#"{"capture_id":"cap_1","judgment_count":1}"#.utf8)
            )
        }

        let output = try await makeClient().uploadJudgments(
            Operations.uploadJudgments.Input(
                path: .init(capture_id: "cap_1"),
                body: .json(
                    Components.Schemas.JudgmentUploadRequest(
                        judgments: [.init(pair_id: "pair_1", judgment: "near_match")]
                    )
                )
            )
        )

        guard case .ok(let ok) = output else {
            return XCTFail("Expected .ok response, got: \(output)")
        }
        XCTAssertEqual(try ok.body.json.judgment_count, 1)
        let json = try XCTUnwrap(Self.jsonObject(from: capturedBody) as? [String: Any])
        let judgment = try XCTUnwrap((json["judgments"] as? [[String: Any]])?.first)
        XCTAssertEqual(judgment["pair_id"] as? String, "pair_1")
        XCTAssertEqual(judgment["judgment"] as? String, "near_match")
    }

    func testFetchRankedResultsSendsGETAndDecodesPublishedAggregate() async throws {
        var capturedRequest: URLRequest?
        OpenAPIStubURLProtocol.handler = { request in
            capturedRequest = request
            return (Self.httpResponse(request, status: 200), Data(Self.rankedResultsJSON.utf8))
        }

        let output = try await makeClient().fetchRankedResults(
            Operations.fetchRankedResults.Input(path: .init(sheet_id: "sheet_123"))
        )

        XCTAssertEqual(capturedRequest?.httpMethod, "GET")
        XCTAssertEqual(capturedRequest?.url?.path, "/api/v1/test_sheets/sheet_123/ranked_results")
        guard case .ok(let ok) = output else {
            return XCTFail("Expected .ok response, got: \(output)")
        }
        let payload = try ok.body.json
        XCTAssertEqual(payload.schema_version, "lps-ranked-results/v1")
        XCTAssertEqual(payload.sheet_id, "sheet_123")
        XCTAssertEqual(payload.capture_count, 2)
        let result = try XCTUnwrap(payload.results.first)
        XCTAssertEqual(result.rank, 1)
        XCTAssertEqual(result.pair_id, "pair_1")
        XCTAssertEqual(result.source_colors.color_a_hex, "#FF0000")
        XCTAssertEqual(result.source_colors.color_b_hex, "#00FF00")
        XCTAssertEqual(result.current_judgment, "near_match")
        XCTAssertEqual(result.observation_count, 1)
        XCTAssertEqual(result.score.average ?? 0, 0.035, accuracy: 0.0001)
        XCTAssertEqual(result.latest_observation?.judgment, "near_match")
    }

    private func makeClient() -> Client {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [OpenAPIStubURLProtocol.self]
        return Client(
            serverURL: URL(string: "https://example.test")!,
            transport: URLSessionTransport(configuration: configuration)
        )
    }

    private static func httpResponse(_ request: URLRequest, status: Int) -> HTTPURLResponse {
        HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
    }

    private static func jsonObject(from data: Data?) throws -> Any {
        try JSONSerialization.jsonObject(with: XCTUnwrap(data))
    }

    private static func readBody(_ stream: InputStream) -> Data {
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 1024)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            if count > 0 {
                data.append(buffer, count)
            } else {
                break
            }
        }
        return data
    }

    private static let manifestJSON = #"""
    {
      "schema_version": "lps-sheet-manifest/v1",
      "sheet_id": "sheet_123",
      "sheet_version": "lps-letter-grid-v1",
      "manifest_url": "https://example.test/api/v1/test_sheets/sheet_123/manifest",
      "created_at": "2026-07-25T12:00:00Z",
      "page": {"units": "mm", "width": 215.9, "height": 279.4},
      "registration_markers": [
        {"role": "top_left", "shape": "solid_square", "rect": {"x": 12, "y": 12, "width": 8, "height": 8}}
      ],
      "printer_profile": {
        "printer_make_model": "Research printer",
        "paper_type": "Research paper",
        "ink_type": "Research ink set",
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
    """#

    private static let rankedResultsJSON = #"""
    {
      "schema_version": "lps-ranked-results/v1",
      "sheet_id": "sheet_123",
      "printer_profile": {
        "printer_make_model": "Research printer",
        "paper_type": "Research paper",
        "ink_type": "Research ink set",
        "icc_profile": null,
        "print_settings": {},
        "driver_name": null,
        "driver_version": null,
        "calibration_date": null,
        "calibration_version": null,
        "notes": null
      },
      "capture_count": 2,
      "latest_capture_at": "2026-07-25T12:30:00Z",
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
            "capture_count": 2,
            "sample_count": 2,
            "algorithm_versions": ["lps-distance-v1"]
          },
          "current_judgment": "near_match",
          "current_judgment_observed_at": "2026-07-25T12:31:00Z",
          "observation_count": 1,
          "latest_observation": {"judgment": "near_match", "observed_at": "2026-07-25T12:31:00Z"},
          "capture_count": 2,
          "latest_capture_at": "2026-07-25T12:30:00Z",
          "earliest_capture_at": "2026-07-25T12:00:00Z"
        }
      ]
    }
    """#
}

private final class OpenAPIStubURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
#endif
