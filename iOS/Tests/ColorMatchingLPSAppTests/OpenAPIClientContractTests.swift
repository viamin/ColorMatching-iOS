import Foundation
import MeasurementCore
import XCTest
@testable import ColorMatchingLPSAppCore

final class OpenAPIClientContractTests: XCTestCase {
    override func tearDown() {
        StubAPIURLProtocol.handler = nil
        super.tearDown()
    }

    func testFetchManifestBySheetCodeDecodesGeneratedManifestResponse() async throws {
        var capturedRequest: URLRequest?
        StubAPIURLProtocol.handler = { request in
            capturedRequest = request
            return Self.jsonResponse(url: request.url!, status: 200, body: Self.manifestJSON)
        }

        let manifest = try await makeClient().fetchManifest(baseURL: Self.baseURL, sheetCode: "sheet_123")

        XCTAssertEqual(capturedRequest?.httpMethod, "GET")
        XCTAssertEqual(capturedRequest?.url?.path, "/api/v1/test_sheets/sheet_123/manifest")
        XCTAssertEqual(capturedRequest?.value(forHTTPHeaderField: "Authorization"), "Bearer token")
        XCTAssertTrue(capturedRequest?.value(forHTTPHeaderField: "Accept")?.contains("application/json") ?? false)
        XCTAssertEqual(manifest.schemaVersion, "lps-sheet-manifest/v1")
        XCTAssertEqual(manifest.sheetID, "sheet_123")
        XCTAssertEqual(manifest.patches.count, 1)
        XCTAssertEqual(manifest.patches.first?.pairID, "pair_1")
        XCTAssertEqual(manifest.patches.first?.sourceColor, "#FF0000")
        XCTAssertEqual(manifest.patches.first?.safeInsetMM ?? 0, 1.5, accuracy: 0.0001)
        XCTAssertEqual(manifest.pairs.first?.firstPatchID, "patch_1")
        XCTAssertEqual(manifest.pairs.first?.gridRow, 0)
        XCTAssertEqual(manifest.pairs.first?.gridCol, 1)
        XCTAssertTrue(manifest.manifestURL.absoluteString.hasSuffix("/api/v1/test_sheets/sheet_123/manifest"))
    }

    func testFetchManifestFromDirectURLDecodesGeneratedManifestResponse() async throws {
        StubAPIURLProtocol.handler = { request in
            Self.jsonResponse(url: request.url!, status: 200, body: Self.manifestJSON)
        }

        let manifest = try await makeClient().fetchManifest(
            from: URL(string: "https://sheets.example.test/api/v1/test_sheets/sheet_123/manifest")!
        )

        XCTAssertEqual(manifest.sheetID, "sheet_123")
        XCTAssertEqual(manifest.pairs.count, 1)
    }

    func testFetchRecentSheetsDecodesGeneratedTypesIncludingNullTitle() async throws {
        var capturedRequest: URLRequest?
        StubAPIURLProtocol.handler = { request in
            capturedRequest = request
            return Self.jsonResponse(url: request.url!, status: 200, body: Self.recentSheetsJSON)
        }

        let sheets = try await makeClient().fetchRecentSheets(baseURL: Self.baseURL)

        XCTAssertEqual(capturedRequest?.httpMethod, "GET")
        XCTAssertEqual(capturedRequest?.url?.path, "/api/v1/test_sheets/recent")
        XCTAssertEqual(capturedRequest?.value(forHTTPHeaderField: "Authorization"), "Bearer token")
        XCTAssertEqual(sheets.count, 2)
        XCTAssertEqual(sheets.first?.sheetID, "sheet_123")
        XCTAssertEqual(sheets.first?.title, "July LPS comparison sheet")
        XCTAssertEqual(sheets.last?.sheetID, "sheet_456")
        XCTAssertNil(sheets.last?.title)
    }

    func testCreateCaptureSendsContractWireFormatAndDecodesCaptureID() async throws {
        var capturedRequest: URLRequest?
        StubAPIURLProtocol.handler = { request in
            capturedRequest = request
            return Self.jsonResponse(url: request.url!, status: 201, body: #"{"capture_id":"cap_1"}"#)
        }

        let response = try await makeClient().createCapture(
            sheetID: "sheet_1",
            baseURL: Self.baseURL,
            metadata: Self.captureMetadata,
            quality: Self.captureQuality
        )

        XCTAssertEqual(response.captureID, "cap_1")
        XCTAssertEqual(capturedRequest?.httpMethod, "POST")
        XCTAssertEqual(capturedRequest?.url?.path, "/api/v1/test_sheets/sheet_1/captures")
        XCTAssertEqual(capturedRequest?.value(forHTTPHeaderField: "Authorization"), "Bearer token")
        XCTAssertEqual(capturedRequest?.value(forHTTPHeaderField: "Content-Type"), "application/json")
        let body = try Self.jsonBodyDictionary(capturedRequest)
        let metadata = try XCTUnwrap(body["metadata"] as? [String: Any])
        XCTAssertEqual(
            Set(metadata.keys),
            [
                "device_model", "lens", "exposure_duration_seconds", "iso", "focus_lens_position",
                "white_balance_gains", "image_width", "image_height", "app_version", "timestamp",
            ]
        )
        XCTAssertEqual(metadata["device_model"] as? String, "iPhone")
        XCTAssertNotNil(metadata["timestamp"] as? String)
        let quality = try XCTUnwrap(body["quality"] as? [String: Any])
        XCTAssertEqual(quality["detected_marker_count"] as? Int, 4)
        XCTAssertEqual(quality["rejections"] as? [String], ["clipping"])
    }

    func testUploadMeasurementsSendsContractWireFormat() async throws {
        var capturedRequest: URLRequest?
        StubAPIURLProtocol.handler = { request in
            capturedRequest = request
            return Self.emptyResponse(url: request.url!, status: 204)
        }

        try await makeClient().uploadMeasurements(
            captureID: "cap_1",
            baseURL: Self.baseURL,
            measurements: [Self.measurement],
            scores: [Self.score]
        )

        XCTAssertEqual(capturedRequest?.httpMethod, "POST")
        XCTAssertEqual(capturedRequest?.url?.path, "/api/v1/captures/cap_1/measurements")
        XCTAssertEqual(capturedRequest?.value(forHTTPHeaderField: "Authorization"), "Bearer token")
        let body = try Self.jsonBodyDictionary(capturedRequest)
        XCTAssertEqual(body["scoring_algorithm_version"] as? String, LPSScorer.algorithmVersion)
        let measurement = try XCTUnwrap((body["measurements"] as? [[String: Any]])?.first)
        XCTAssertEqual(
            Set(measurement.keys),
            ["patch_id", "linear_rgb_median", "normalized_linear_rgb_median", "stats"]
        )
        XCTAssertEqual(measurement["patch_id"] as? String, "patch_1")
        let median = try XCTUnwrap(measurement["linear_rgb_median"] as? [String: Any])
        XCTAssertEqual(median["r"] as? Double ?? -1, 0.2, accuracy: 0.0001)
        let stats = try XCTUnwrap(measurement["stats"] as? [String: Any])
        XCTAssertEqual(Set(stats.keys), ["sample_count", "clipping_fraction", "mean", "standard_deviation"])
        XCTAssertEqual(stats["sample_count"] as? Int, 9)
        let score = try XCTUnwrap((body["pair_scores"] as? [[String: Any]])?.first)
        XCTAssertEqual(Set(score.keys), ["pair_id", "distance", "similarity", "algorithm_version"])
        XCTAssertEqual(score["pair_id"] as? String, "pair_1")
        XCTAssertNotNil(score["distance"] as? Double)
        XCTAssertEqual(score["algorithm_version"] as? String, LPSScorer.algorithmVersion)
    }

    func testUploadJudgmentsSendsContractWireFormat() async throws {
        var capturedRequest: URLRequest?
        StubAPIURLProtocol.handler = { request in
            capturedRequest = request
            return Self.emptyResponse(url: request.url!, status: 204)
        }

        try await makeClient().uploadJudgments(
            captureID: "cap_1",
            baseURL: Self.baseURL,
            judgments: [PairJudgment(pairID: "pair_1", judgment: "near_match")]
        )

        XCTAssertEqual(capturedRequest?.httpMethod, "POST")
        XCTAssertEqual(capturedRequest?.url?.path, "/api/v1/captures/cap_1/judgments")
        XCTAssertEqual(capturedRequest?.value(forHTTPHeaderField: "Authorization"), "Bearer token")
        let body = try Self.jsonBodyDictionary(capturedRequest)
        let judgment = try XCTUnwrap((body["judgments"] as? [[String: Any]])?.first)
        XCTAssertEqual(Set(judgment.keys), ["pair_id", "judgment"])
        XCTAssertEqual(judgment["pair_id"] as? String, "pair_1")
        XCTAssertEqual(judgment["judgment"] as? String, "near_match")
    }

    func testFetchRankedResultsDecodesGeneratedTypes() async throws {
        var capturedRequest: URLRequest?
        StubAPIURLProtocol.handler = { request in
            capturedRequest = request
            return Self.jsonResponse(url: request.url!, status: 200, body: Self.rankedResultsJSON)
        }

        let results = try await makeClient().fetchRankedResults(sheetID: "sheet_1", baseURL: Self.baseURL)

        XCTAssertEqual(capturedRequest?.httpMethod, "GET")
        XCTAssertEqual(capturedRequest?.url?.path, "/api/v1/test_sheets/sheet_1/ranked_results")
        XCTAssertEqual(capturedRequest?.value(forHTTPHeaderField: "Authorization"), "Bearer token")
        XCTAssertEqual(results.scoringAlgorithmVersion, "lps-distance-v1")
        XCTAssertEqual(results.pairs.count, 2)
        let first = try XCTUnwrap(results.pairs.first)
        XCTAssertEqual(first.pairID, "pair_1")
        XCTAssertEqual(first.sourceColors, ["#FF0000", "#00FF00"])
        XCTAssertEqual(first.distance, 0.035, accuracy: 0.0001)
        XCTAssertEqual(first.similarity, 0.965, accuracy: 0.0001)
        XCTAssertEqual(first.label, "near_match")
        XCTAssertEqual(first.captureID, "cap_1")
        XCTAssertNil(results.pairs.last?.label)
        XCTAssertNil(results.pairs.last?.captureID)
    }

    func testUnauthorizedResponseSurfacesTypedAPIError() async throws {
        StubAPIURLProtocol.handler = { request in
            Self.jsonResponse(url: request.url!, status: 401, body: #"{"error":"unauthorized"}"#)
        }

        do {
            _ = try await makeClient().fetchManifest(baseURL: Self.baseURL, sheetCode: "sheet_123")
            XCTFail("Expected unauthorized error")
        } catch let error as APIError {
            guard case APIError.unauthorized = error else {
                return XCTFail("Expected APIError.unauthorized, got \(error)")
            }
        } catch {
            XCTFail("Expected APIError, got \(error)")
        }
    }

    private func makeClient() -> APIClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubAPIURLProtocol.self]
        return APIClient(token: "token", session: URLSession(configuration: configuration))
    }

    private static let baseURL = URL(string: "https://example.test")!

    private static let sampleRGB = RGB(r: 0.2, g: 0.3, b: 0.4)

    private static var measurement: PatchMeasurement {
        let stats = ChannelStats(
            median: sampleRGB,
            mean: sampleRGB,
            standardDeviation: RGB(r: 0.01, g: 0.01, b: 0.01),
            min: sampleRGB,
            max: sampleRGB,
            sampleCount: 9,
            clippingFraction: 0
        )
        return PatchMeasurement(
            patchID: "patch_1",
            linearRGBMedian: sampleRGB,
            normalizedLinearRGBMedian: sampleRGB,
            stats: stats
        )
    }

    private static var score: PairScore {
        PairScore(pairID: "pair_1", distance: 0.1, similarity: 0.9, algorithmVersion: LPSScorer.algorithmVersion)
    }

    private static var captureMetadata: CaptureMetadata {
        CaptureMetadata(
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
        )
    }

    private static var captureQuality: CaptureQuality {
        CaptureQuality(detectedMarkerCount: 4, blurScore: 0.75, rejections: [.clipping])
    }

    private static let manifestJSON = ##"""
    {
      "schema_version": "lps-sheet-manifest/v1",
      "sheet_version": "lps-letter-grid-v1",
      "sheet_id": "sheet_123",
      "manifest_url": "https://example.test/api/v1/test_sheets/sheet_123/manifest",
      "created_at": "2026-07-25T12:00:00Z",
      "page": {"units": "mm", "width": 215.9, "height": 279.4},
      "registration_markers": [
        {"role": "top_left", "shape": "solid_square", "rect": {"x": 12, "y": 12, "width": 8, "height": 8}}
      ],
      "printer_profile": {
        "id": "printer_profile_1",
        "name": "Research printer",
        "paper": "paper name",
        "ink": "ink set",
        "settings": {}
      },
      "capture_profile": {
        "expected_illuminant": "low_pressure_sodium",
        "preferred_camera": "built_in_wide_angle_rear",
        "scoring_algorithm_version": "lps-distance-v1"
      },
      "patches": [
        {
          "id": "patch_1",
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
          "first_patch_id": "patch_1",
          "second_patch_id": "patch_2",
          "source_colors": ["#FF0000", "#00FF00"],
          "grid_row": 0,
          "grid_col": 1
        }
      ]
    }
    """##

    private static let recentSheetsJSON = ##"""
    {
      "sheets": [
        {
          "sheet_id": "sheet_123",
          "manifest_url": "https://example.test/api/v1/test_sheets/sheet_123/manifest",
          "title": "July LPS comparison sheet"
        },
        {
          "sheet_id": "sheet_456",
          "manifest_url": "https://example.test/api/v1/test_sheets/sheet_456/manifest",
          "title": null
        }
      ]
    }
    """##

    private static let rankedResultsJSON = ##"""
    {
      "scoring_algorithm_version": "lps-distance-v1",
      "pairs": [
        {
          "pair_id": "pair_1",
          "source_colors": ["#FF0000", "#00FF00"],
          "distance": 0.035,
          "similarity": 0.965,
          "label": "near_match",
          "capture_id": "cap_1"
        },
        {
          "pair_id": "pair_2",
          "source_colors": ["#0000FF", "#00FFFF"],
          "distance": 0.12,
          "similarity": 0.88,
          "label": null,
          "capture_id": null
        }
      ]
    }
    """##

    private static func jsonResponse(url: URL, status: Int, body: String) -> (HTTPURLResponse, Data) {
        (
            HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!,
            Data(body.utf8)
        )
    }

    private static func emptyResponse(url: URL, status: Int) -> (HTTPURLResponse, Data) {
        (HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil)!, Data())
    }

    private static func jsonBodyDictionary(_ request: URLRequest?) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: requestBody(request)) as? [String: Any])
    }

    private static func requestBody(_ request: URLRequest?) throws -> Data {
        if let stream = request?.httpBodyStream {
            return readBody(stream)
        }
        return try XCTUnwrap(request?.httpBody)
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
}

private final class StubAPIURLProtocol: URLProtocol {
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
            client?.urlProtocol(self, didFinishLoading: self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
