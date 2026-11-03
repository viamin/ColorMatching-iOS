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

    func testFetchManifestDecodesStubbedManifest() async throws {
        var capturedRequest: URLRequest?
        MockURLProtocol.handler = { request in
            capturedRequest = request
            return (
                HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                Data(Self.manifestJSON.utf8)
            )
        }

        let manifest = try await client().fetchManifest(
            baseURL: URL(string: "https://example.test")!,
            sheetCode: "LPSM-DEV2"
        )

        XCTAssertEqual(capturedRequest?.url?.path, "/api/v1/test_sheets/LPSM-DEV2/manifest")
        XCTAssertEqual(capturedRequest?.value(forHTTPHeaderField: "Authorization"), "Bearer token")
        XCTAssertEqual(manifest.schemaVersion, "lps-sheet-manifest/v1")
        XCTAssertEqual(manifest.sheetID, "LPSM-DEV2")
        XCTAssertEqual(manifest.pairs.first?.id, "pair_1")
    }

    func testFetchRecentSheetsDecodesStubbedResponse() async throws {
        var capturedRequest: URLRequest?
        MockURLProtocol.handler = { request in
            capturedRequest = request
            return (
                HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                Data(#"{"sheets":[{"sheet_id":"LPSM-DEV2","manifest_url":"https://example.test/api/v1/test_sheets/LPSM-DEV2/manifest","title":null}]}"#.utf8)
            )
        }

        let sheets = try await client().fetchRecentSheets(baseURL: URL(string: "https://example.test")!)

        XCTAssertEqual(capturedRequest?.url?.path, "/api/v1/test_sheets/recent")
        XCTAssertEqual(sheets.map(\.sheetID), ["LPSM-DEV2"])
        XCTAssertNil(sheets.first?.title)
    }

    func testFetchRankedResultsDecodesPublishedResponse() async throws {
        var capturedRequest: URLRequest?
        MockURLProtocol.handler = { request in
            capturedRequest = request
            return (
                HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                Data(#"{"schema_version":"lps-ranked-results/v1","sheet_id":"LPSM-DEV2","printer_profile":{"printer_make_model":"Research printer","paper_type":"matte","ink_type":"pigment","icc_profile":null,"print_settings":null,"driver_name":null,"driver_version":null,"calibration_date":null,"calibration_version":null,"notes":null},"capture_count":1,"latest_capture_at":"2026-10-30T12:00:00Z","earliest_capture_at":"2026-10-30T12:00:00Z","scoring_algorithm_versions":["lps-distance-v1"],"results":[{"rank":1,"pair_id":"pair_1","scoring_algorithm_version":"lps-distance-v1","row":0,"col":1,"source_colors":{"color_a_hex":"#FF0000","color_b_hex":"#00FF00"},"score":{"average":0.965,"latest":0.965,"minimum":0.965,"maximum":0.965,"capture_count":1,"sample_count":1,"algorithm_versions":["lps-distance-v1"]},"current_judgment":"near_match","current_judgment_observed_at":"2026-10-30T12:00:00Z","observation_count":1,"latest_observation":{"judgment":"near_match","observed_at":"2026-10-30T12:00:00Z"},"capture_count":1,"latest_capture_at":"2026-10-30T12:00:00Z","earliest_capture_at":"2026-10-30T12:00:00Z"}]}"#.utf8)
            )
        }

        let rankedResults = try await client().fetchRankedResults(
            sheetID: "LPSM-DEV2",
            baseURL: URL(string: "https://example.test")!
        )

        XCTAssertEqual(capturedRequest?.url?.path, "/api/v1/test_sheets/LPSM-DEV2/ranked_results")
        XCTAssertEqual(rankedResults.schemaVersion, "lps-ranked-results/v1")
        XCTAssertEqual(rankedResults.sheetID, "LPSM-DEV2")
        XCTAssertEqual(rankedResults.results.first?.pairID, "pair_1")
    }

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

    private static let manifestJSON = #"""
    {
      "schema_version": "lps-sheet-manifest/v1",
      "sheet_version": "lps-letter-grid-v1",
      "sheet_id": "LPSM-DEV2",
      "manifest_url": "https://example.test/api/v1/test_sheets/LPSM-DEV2/manifest",
      "page": {"units": "mm", "width": 215.9, "height": 279.4},
      "registration_markers": [{"role": "top_left", "shape": "solid_square", "rect": {"x": 12, "y": 12, "width": 8, "height": 8}}],
      "patches": [
        {"id": "patch_1a", "role": "pair_color", "pair_id": "pair_1", "pair_side": "first", "reference_role": null, "source_color": "#FF0000", "safe_inset_mm": 1.5, "rect": {"x": 16, "y": 38, "width": 16, "height": 10}},
        {"id": "patch_1b", "role": "pair_color", "pair_id": "pair_1", "pair_side": "second", "reference_role": null, "source_color": "#00FF00", "safe_inset_mm": 1.5, "rect": {"x": 34, "y": 38, "width": 16, "height": 10}}
      ],
      "pairs": [{"id": "pair_1", "first_patch_id": "patch_1a", "second_patch_id": "patch_1b", "source_colors": ["#FF0000", "#00FF00"], "grid_row": 0, "grid_col": 1}]
    }
    """#
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
