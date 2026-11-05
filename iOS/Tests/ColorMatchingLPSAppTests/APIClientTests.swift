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
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data(#"{"capture_id":"1","measurement_count":1,"pair_score_count":1}"#.utf8))
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
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data(#"{"capture_id":"1","judgment_count":1}"#.utf8))
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

    func testFetchManifestUsesThePublishedEndpointAndDecodesItsVersionedResponse() async throws {
        var capturedRequest: URLRequest?
        MockURLProtocol.handler = { request in
            capturedRequest = request
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Self.manifestResponse)
        }

        let manifest = try await client().fetchManifest(
            baseURL: URL(string: "https://example.test")!,
            sheetCode: "LPSM-DEV2"
        )

        XCTAssertEqual(capturedRequest?.url?.path, "/api/v1/test_sheets/LPSM-DEV2/manifest")
        XCTAssertEqual(capturedRequest?.value(forHTTPHeaderField: "Authorization"), "Bearer token")
        XCTAssertEqual(manifest.schemaVersion, "lps-sheet-manifest/v1")
        XCTAssertEqual(manifest.sheetID, "LPSM-DEV2")
    }

    func testFetchRecentSheetsUsesThePublishedEndpointAndDecodesNullableTitles() async throws {
        var capturedRequest: URLRequest?
        MockURLProtocol.handler = { request in
            capturedRequest = request
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Self.recentSheetsResponse)
        }

        let sheets = try await client().fetchRecentSheets(baseURL: URL(string: "https://example.test")!)

        XCTAssertEqual(capturedRequest?.url?.path, "/api/v1/test_sheets/recent")
        XCTAssertEqual(capturedRequest?.value(forHTTPHeaderField: "Authorization"), "Bearer token")
        XCTAssertEqual(sheets.map(\.sheetID), ["LPSM-DEV2"])
        XCTAssertNil(sheets.first?.title)
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

    private static let manifestResponse = Data(#"""
    {
      "schema_version": "lps-sheet-manifest/v1",
      "sheet_version": "lps-letter-grid-v1",
      "sheet_id": "LPSM-DEV2",
      "manifest_url": "https://example.test/api/v1/test_sheets/LPSM-DEV2/manifest",
      "created_at": "2026-07-28T20:10:19Z",
      "page": {"units": "mm", "width": 215.9, "height": 279.4},
      "registration_markers": [
        {"role": "top_left", "shape": "solid_square", "rect": {"x": 12.7, "y": 12.7, "width": 10.0, "height": 10.0}}
      ],
      "printer_profile": {"printer_make_model": "Generic Inkjet", "paper_type": "Plain", "ink_type": "Dye"},
      "capture_profile": {"expected_illuminant": "low_pressure_sodium", "preferred_camera": "built_in_wide_angle_rear", "scoring_algorithm_version": "lps-distance-v1"},
      "patches": [
        {"id": "pair-abc#first", "role": "pair_color", "pair_id": "pair-abc", "pair_side": "first", "reference_role": null, "source_color": "#FF4444", "safe_inset_mm": 1.5, "rect": {"x": 75.95, "y": 107.7, "width": 10.0, "height": 10.0}},
        {"id": "pair-abc#second", "role": "pair_color", "pair_id": "pair-abc", "pair_side": "second", "reference_role": null, "source_color": "#BB55BB", "safe_inset_mm": 1.5, "rect": {"x": 85.95, "y": 117.7, "width": 10.0, "height": 10.0}}
      ],
      "pairs": [
        {"id": "pair-abc", "first_patch_id": "pair-abc#first", "second_patch_id": "pair-abc#second", "source_colors": ["#FF4444", "#BB55BB"], "grid_row": 0, "grid_col": 0}
      ]
    }
    """#.utf8)

    private static let recentSheetsResponse = Data(#"""
    {"sheets": [{"sheet_id": "LPSM-DEV2", "manifest_url": "https://example.test/api/v1/test_sheets/LPSM-DEV2/manifest", "title": null}]}
    """#.utf8)
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
