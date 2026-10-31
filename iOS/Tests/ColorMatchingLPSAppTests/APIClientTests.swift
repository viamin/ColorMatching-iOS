import Foundation
import MeasurementCore
import XCTest
@testable import ColorMatchingLPSAppCore

final class APIClientTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.handler = nil
        super.tearDown()
    }

    func testCreateCaptureEncodesMetadataAndQuality() async throws {
        var capturedRequest: URLRequest?
        var capturedBody: Data?
        MockURLProtocol.handler = { request in
            capturedRequest = request
            capturedBody = request.httpBodyStream.flatMap(Self.readBody) ?? request.httpBody
            return (HTTPURLResponse(url: request.url!, statusCode: 201, httpVersion: nil, headerFields: nil)!, Data(#"{"capture_id":"cap_1"}"#.utf8))
        }

        let response = try await client().createCapture(
            sheetID: "sheet_1",
            baseURL: URL(string: "https://example.test")!,
            metadata: CaptureMetadata(
                deviceModel: "iPhone",
                lens: "wide",
                exposureDurationSeconds: 0.01,
                iso: 100,
                focusLensPosition: 0.4,
                whiteBalanceGains: WhiteBalanceGains(red: 1.1, green: 1.0, blue: 1.2),
                imageWidth: 100,
                imageHeight: 200,
                appVersion: "0.1.0",
                timestamp: Date(timeIntervalSince1970: 0)
            ),
            quality: CaptureQuality(detectedMarkerCount: 4, blurScore: 0.75, rejections: [])
        )

        XCTAssertEqual(response.captureID, "cap_1")
        XCTAssertEqual(capturedRequest?.url?.path, "/api/v1/test_sheets/sheet_1/captures")
        XCTAssertEqual(capturedRequest?.value(forHTTPHeaderField: "Authorization"), "Bearer token")
        let json = try XCTUnwrap(Self.jsonObject(from: capturedBody) as? [String: Any])
        XCTAssertNotNil(json["metadata"])
        let quality = try XCTUnwrap(json["quality"] as? [String: Any])
        XCTAssertEqual(quality["detected_marker_count"] as? Int, 4)
        XCTAssertEqual(quality["rejections"] as? [String], [])
    }

    func testUploadMeasurementsEncodesScoresWithAlgorithmVersion() async throws {
        var capturedBody: Data?
        MockURLProtocol.handler = { request in
            capturedBody = request.httpBodyStream.flatMap(Self.readBody) ?? request.httpBody
            return (HTTPURLResponse(url: request.url!, statusCode: 204, httpVersion: nil, headerFields: nil)!, Data())
        }

        let rgb = RGB(r: 0.2, g: 0.3, b: 0.4)
        let stats = ChannelStats(median: rgb, mean: rgb, standardDeviation: RGB(r: 0.01, g: 0.01, b: 0.01), min: rgb, max: rgb, sampleCount: 9, clippingFraction: 0)
        try await client().uploadMeasurements(
            captureID: "cap_1",
            baseURL: URL(string: "https://example.test")!,
            measurements: [PatchMeasurement(patchID: "patch_1", linearRGBMedian: rgb, normalizedLinearRGBMedian: rgb, stats: stats)],
            scores: [PairScore(pairID: "pair_1", distance: 0.1, similarity: 0.9, algorithmVersion: LPSScorer.algorithmVersion)]
        )

        let json = try XCTUnwrap(Self.jsonObject(from: capturedBody) as? [String: Any])
        XCTAssertEqual(json["scoring_algorithm_version"] as? String, "lps-distance-v1")
        let measurement = try XCTUnwrap((json["measurements"] as? [[String: Any]])?.first)
        XCTAssertEqual(measurement["patch_id"] as? String, "patch_1")
        let statsPayload = try XCTUnwrap(measurement["stats"] as? [String: Any])
        XCTAssertEqual(Set(statsPayload.keys), ["sample_count", "clipping_fraction", "mean", "standard_deviation"])
        XCTAssertEqual((json["pair_scores"] as? [[String: Any]])?.first?["pair_id"] as? String, "pair_1")
    }

    func testUploadJudgmentsEncodesPathAndPayload() async throws {
        var capturedRequest: URLRequest?
        var capturedBody: Data?
        MockURLProtocol.handler = { request in
            capturedRequest = request
            capturedBody = request.httpBodyStream.flatMap(Self.readBody) ?? request.httpBody
            return (HTTPURLResponse(url: request.url!, statusCode: 204, httpVersion: nil, headerFields: nil)!, Data())
        }

        try await client().uploadJudgments(
            captureID: "cap_1",
            baseURL: URL(string: "https://example.test")!,
            judgments: [PairJudgment(pairID: "pair_1", judgment: "near_match")]
        )

        XCTAssertEqual(capturedRequest?.httpMethod, "POST")
        XCTAssertEqual(capturedRequest?.url?.path, "/api/v1/captures/cap_1/judgments")
        let json = try XCTUnwrap(Self.jsonObject(from: capturedBody) as? [String: Any])
        XCTAssertEqual((json["judgments"] as? [[String: Any]])?.first?["judgment"] as? String, "near_match")
    }

    // MARK: - Real `color_matching` contract fixtures (issue #5)
    //
    // The bodies below are transcribed field-for-field from the published
    // OpenAPI 3 spec and JSON renderer merged in viamin/color_matching#113
    // (commit 094bd6d3443ddacbda7e63354299867eb5bdfa9f: `lib/color_matching_web/api_schemas.ex`,
    // `lib/color_matching_web/controllers/test_sheet_json.ex`), not from the
    // hand-written prose contract in `docs/color-matching-api-contract.md`.
    // See `docs/openapi-client-contract-deltas.md` for the full list of
    // deltas these fixtures surfaced.

    func testFetchManifestDecodesRealServerPayload() async throws {
        MockURLProtocol.handler = { request in
            (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data(Self.realManifestJSON.utf8))
        }

        let manifest = try await client().fetchManifest(baseURL: URL(string: "https://example.test")!, sheetCode: "sheet_abc123")

        XCTAssertEqual(manifest.sheetID, "sheet_abc123")
        XCTAssertEqual(manifest.sheetVersion, "lps-letter-grid-v1")
        XCTAssertEqual(manifest.manifestURL, URL(string: "https://example.test/api/v1/test_sheets/sheet_abc123/manifest"))
        XCTAssertEqual(manifest.patches.map(\.id), ["pair_1#first", "pair_1#second"])
        XCTAssertEqual(manifest.pairs.first?.sourceColors, ["#FF0000", "#00FF00"])
    }

    func testFetchRecentSheetsDecodesRealServerAlwaysNullTitle() async throws {
        // The real `recent` renderer (`render_recent_sheet/1`) hardcodes `title: nil`
        // today; the prose contract's "title may be null" undersells that it is
        // *always* null in the current server implementation.
        MockURLProtocol.handler = { request in
            (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data(Self.realRecentSheetsJSON.utf8))
        }

        let sheets = try await client().fetchRecentSheets(baseURL: URL(string: "https://example.test")!)

        XCTAssertEqual(sheets.first?.sheetID, "sheet_abc123")
        XCTAssertNil(sheets.first?.title)
    }

    func testRankedResultsEndpointHasNoClientSurfaceYet() throws {
        // GET /api/v1/test_sheets/:sheet_id/ranked_results is a documented iOS
        // consumption surface in issue #5 ("ranked results"), and the real server
        // returns a rich `lps-ranked-results/v1` payload (see `realRankedResultsJSON`
        // below), but neither `APIClient` nor `MeasurementCore` has any type or
        // method that decodes it. This is an intentional failing assertion
        // (red phase) recording that gap; it should be replaced with a real
        // decode assertion once the generated client adds this surface.
        _ = Self.realRankedResultsJSON
        XCTFail("APIClient has no method decoding GET /api/v1/test_sheets/:sheet_id/ranked_results (issue #5 ranked-results surface is unimplemented)")
    }

    private static let realManifestJSON = #"""
    {
      "schema_version": "lps-sheet-manifest/v1",
      "sheet_id": "sheet_abc123",
      "sheet_version": "lps-letter-grid-v1",
      "manifest_url": "https://example.test/api/v1/test_sheets/sheet_abc123/manifest",
      "created_at": "2026-07-25T12:00:00Z",
      "page": {"units": "mm", "width": 215.9, "height": 279.4},
      "registration_markers": [
        {"role": "top_left", "shape": "solid_square", "rect": {"x": 12, "y": 12, "width": 8, "height": 8}}
      ],
      "printer_profile": {
        "printer_make_model": "Epson ET-8550",
        "paper_type": "Luster 260",
        "ink_type": "Claria",
        "icc_profile": null,
        "print_settings": {"quality": "best"},
        "driver_name": "AirPrint",
        "driver_version": "1.0",
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
        {"id": "pair_1#second", "role": "pair_color", "pair_id": "pair_1", "pair_side": "second", "reference_role": null, "source_color": "#00FF00", "safe_inset_mm": 1.5, "rect": {"x": 40, "y": 38, "width": 16, "height": 10}}
      ],
      "pairs": [
        {"id": "pair_1", "first_patch_id": "pair_1#first", "second_patch_id": "pair_1#second", "source_colors": ["#FF0000", "#00FF00"], "grid_row": 0, "grid_col": 1}
      ]
    }
    """#

    private static let realRecentSheetsJSON = #"""
    {
      "sheets": [
        {"sheet_id": "sheet_abc123", "manifest_url": "https://example.test/api/v1/test_sheets/sheet_abc123/manifest", "title": null}
      ]
    }
    """#

    private static let realRankedResultsJSON = #"""
    {
      "schema_version": "lps-ranked-results/v1",
      "sheet_id": "sheet_abc123",
      "printer_profile": {
        "printer_make_model": "Epson ET-8550",
        "paper_type": "Luster 260",
        "ink_type": "Claria",
        "icc_profile": null,
        "print_settings": {"quality": "best"},
        "driver_name": "AirPrint",
        "driver_version": "1.0",
        "calibration_date": null,
        "calibration_version": null,
        "notes": null
      },
      "capture_count": 3,
      "latest_capture_at": "2026-07-26T10:00:00Z",
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
          "score": {"average": 0.03, "latest": 0.035, "minimum": 0.02, "maximum": 0.04, "capture_count": 3, "sample_count": 3, "algorithm_versions": ["lps-distance-v1"]},
          "current_judgment": "near_match",
          "current_judgment_observed_at": "2026-07-26T10:00:00Z",
          "observation_count": 3,
          "latest_observation": {"judgment": "near_match", "observed_at": "2026-07-26T10:00:00Z"},
          "capture_count": 3,
          "latest_capture_at": "2026-07-26T10:00:00Z",
          "earliest_capture_at": "2026-07-25T12:00:00Z"
        }
      ]
    }
    """#

    private func client() -> APIClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        return APIClient(token: "token", session: URLSession(configuration: configuration))
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
                data.append(buffer, count: count)
            } else {
                break
            }
        }
        return data
    }
}

private final class MockURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        do {
            let (response, data) = try XCTUnwrap(Self.handler)(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
