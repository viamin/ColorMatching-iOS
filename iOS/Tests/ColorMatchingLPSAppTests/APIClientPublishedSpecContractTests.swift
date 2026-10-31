import Foundation
import MeasurementCore
import XCTest
@testable import ColorMatchingLPSAppCore

final class APIClientPublishedSpecContractTests: XCTestCase {
    override func tearDown() {
        SpecContractURLProtocol.handler = nil
        super.tearDown()
    }

    func testFetchManifestDecodesManifestsWithOnlyPublishedRequiredFields() async {
        stubSuccess(Self.minimalManifestJSON)

        await performWithoutError("a manifest carrying only the published required fields (schema_version, sheet_id, capture_profile.scoring_algorithm_version) must decode") {
            _ = try await self.makeClient().fetchManifest(baseURL: Self.baseURL, sheetCode: "sheet_1")
        }
    }

    func testFetchManifestDecodesFullManifestsWithUndocumentedExtras() async {
        stubSuccess(Self.fullManifestJSON)

        await performWithoutError("a manifest that additionally carries the undocumented prose fields (page, patches, pairs, ...) must still decode") {
            _ = try await self.makeClient().fetchManifest(baseURL: Self.baseURL, sheetCode: "sheet_1")
        }
    }

    func testFetchManifestSurfacesNotFoundResponsesAsErrors() async {
        stubFailure(status: 404, json: #"{"errors":{"detail":"Sheet not found"}}"#)

        await performWithError("a 404 manifest response must surface as an error") {
            _ = try await self.makeClient().fetchManifest(baseURL: Self.baseURL, sheetCode: "missing")
        }
    }

    func testFetchRecentSheetsDecodesNullableTitles() async {
        stubSuccess(#"{"sheets":[{"sheet_id":"sheet_1","manifest_url":"https://example.test/api/v1/test_sheets/sheet_1/manifest","title":null},{"sheet_id":"sheet_2","manifest_url":"https://example.test/api/v1/test_sheets/sheet_2/manifest","title":"July LPS comparison sheet"}]}"#)

        await performWithoutError("recent sheets with a null title must decode (title is required-but-nullable in the published spec)") {
            _ = try await self.makeClient().fetchRecentSheets(baseURL: Self.baseURL)
        }
    }

    func testCreateCaptureEncodesIntegerISOAndNestedSpecShape() async throws {
        var capturedRequest: URLRequest?
        var capturedBody: Data?
        SpecContractURLProtocol.handler = { request in
            capturedRequest = request
            capturedBody = Self.bodyData(of: request)
            return (HTTPURLResponse(url: request.url!, statusCode: 201, httpVersion: nil, headerFields: nil)!, Data(#"{"capture_id":"cap_1"}"#.utf8))
        }

        _ = try await makeClient().createCapture(
            sheetID: "sheet_1",
            baseURL: Self.baseURL,
            metadata: Self.captureMetadata(),
            quality: CaptureQuality(detectedMarkerCount: 4, blurScore: 0.75, rejections: [])
        )

        XCTAssertEqual(capturedRequest?.httpMethod, "POST")
        XCTAssertEqual(capturedRequest?.url?.path, "/api/v1/test_sheets/sheet_1/captures")
        XCTAssertEqual(capturedRequest?.value(forHTTPHeaderField: "Authorization"), "Bearer token")
        XCTAssertEqual(capturedRequest?.value(forHTTPHeaderField: "Content-Type"), "application/json")

        let body = try XCTUnwrap(capturedBody)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        let metadata = try XCTUnwrap(json["metadata"] as? [String: Any], "capture request must use the nested metadata form from the published CaptureRequest schema")
        XCTAssertEqual(metadata["device_model"] as? String, "iPhone")
        XCTAssertNotNil(metadata["iso"] as? NSNumber)
        let quality = try XCTUnwrap(json["quality"] as? [String: Any])
        XCTAssertEqual(quality["detected_marker_count"] as? Int, 4)
        XCTAssertFalse(
            String(decoding: body, as: UTF8.self).contains("\"iso\":100.0"),
            "published CaptureMetadata declares iso as an integer; fractional ISO encodings are rejected by the API"
        )
    }

    func testUploadMeasurementsSendsPublishedSpecBodyShape() async throws {
        var capturedBody: Data?
        SpecContractURLProtocol.handler = { request in
            capturedBody = Self.bodyData(of: request)
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data(#"{"capture_id":"cap_1","measurement_count":2,"pair_score_count":1}"#.utf8))
        }

        try await makeClient().uploadMeasurements(
            captureID: "cap_1",
            baseURL: Self.baseURL,
            measurements: [Self.normalizedMeasurement(patchID: "patch_1"), Self.unnormalizedMeasurement(patchID: "patch_2")],
            scores: [PairScore(pairID: "pair_1", distance: 0.1, similarity: 0.9, algorithmVersion: LPSScorer.algorithmVersion)]
        )

        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(capturedBody)) as? [String: Any])
        XCTAssertNil(
            json["scoring_algorithm_version"],
            "the published MeasurementUploadRequest has no top-level scoring_algorithm_version; the algorithm version travels on each pair score"
        )

        let measurements = try XCTUnwrap(json["measurements"] as? [[String: Any]])
        XCTAssertFalse(measurements.isEmpty)
        XCTAssertTrue(measurements.contains { $0["patch_id"] as? String == "patch_1" })
        for (index, measurement) in measurements.enumerated() {
            XCTAssertNotNil(measurement["patch_id"] as? String, "measurement \(index) must carry patch_id")
            XCTAssertNotNil(measurement["linear_rgb_median"] as? [String: Any], "measurement \(index) must carry linear_rgb_median")
            let normalized = try XCTUnwrap(
                measurement["normalized_linear_rgb_median"],
                "the published schema requires normalized_linear_rgb_median on every uploaded measurement (measurement \(index))"
            )
            XCTAssertFalse(normalized is NSNull)
            XCTAssertNil(measurement["stats"], "stats are not part of the published MeasurementUploadRequest and must not be sent")
        }

        let pairScores = try XCTUnwrap(json["pair_scores"] as? [[String: Any]])
        let score = try XCTUnwrap(pairScores.first)
        XCTAssertEqual(score["pair_id"] as? String, "pair_1")
        XCTAssertEqual(score["algorithm_version"] as? String, "lps-distance-v1")
        XCTAssertNotNil(score["similarity"], "published PairScoreRequest requires one of score/similarity/distance")
        XCTAssertNotNil(score["distance"])
    }

    func testUploadJudgmentsSendsPublishedBodyAndAcceptsCountedResponse() async throws {
        var capturedRequest: URLRequest?
        var capturedBody: Data?
        SpecContractURLProtocol.handler = { request in
            capturedRequest = request
            capturedBody = Self.bodyData(of: request)
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data(#"{"capture_id":"cap_1","judgment_count":1}"#.utf8))
        }

        try await makeClient().uploadJudgments(
            captureID: "cap_1",
            baseURL: Self.baseURL,
            judgments: [PairJudgment(pairID: "pair_1", judgment: "near_match")]
        )

        XCTAssertEqual(capturedRequest?.httpMethod, "POST")
        XCTAssertEqual(capturedRequest?.url?.path, "/api/v1/captures/cap_1/judgments")
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(capturedBody)) as? [String: Any])
        let judgment = try XCTUnwrap((json["judgments"] as? [[String: Any]])?.first)
        XCTAssertEqual(judgment["pair_id"] as? String, "pair_1")
        XCTAssertEqual(judgment["judgment"] as? String, "near_match")
    }

    private static let baseURL = URL(string: "https://example.test")!

    private static let minimalManifestJSON = #"{"schema_version":"lps-sheet-manifest/v1","sheet_id":"sheet_1","capture_profile":{"scoring_algorithm_version":"lps-distance-v1"}}"#

    private static let fullManifestJSON = #"""
    {
      "schema_version": "lps-sheet-manifest/v1",
      "sheet_version": "lps-letter-grid-v1",
      "sheet_id": "sheet_1",
      "manifest_url": "https://example.test/api/v1/test_sheets/sheet_1/manifest",
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
    """#

    private static func captureMetadata() -> CaptureMetadata {
        CaptureMetadata(
            deviceModel: "iPhone",
            lens: "wide",
            exposureDurationSeconds: 0.016,
            iso: 100,
            focusLensPosition: 0.42,
            whiteBalanceGains: WhiteBalanceGains(red: 1.2, green: 1.0, blue: 1.4),
            imageWidth: 4032,
            imageHeight: 3024,
            appVersion: "0.1.0",
            timestamp: Date(timeIntervalSince1970: 0)
        )
    }

    private static func makeStats() -> ChannelStats {
        let rgb = RGB(r: 0.2, g: 0.3, b: 0.4)
        return ChannelStats(
            median: rgb,
            mean: rgb,
            standardDeviation: RGB(r: 0.01, g: 0.01, b: 0.01),
            min: rgb,
            max: rgb,
            sampleCount: 9,
            clippingFraction: 0
        )
    }

    private static func normalizedMeasurement(patchID: String) -> PatchMeasurement {
        PatchMeasurement(
            patchID: patchID,
            linearRGBMedian: RGB(r: 0.2, g: 0.3, b: 0.4),
            normalizedLinearRGBMedian: RGB(r: 0.15, g: 0.25, b: 0.35),
            stats: makeStats()
        )
    }

    private static func unnormalizedMeasurement(patchID: String) -> PatchMeasurement {
        PatchMeasurement(patchID: patchID, linearRGBMedian: RGB(r: 0.2, g: 0.3, b: 0.4), stats: makeStats())
    }

    private func makeClient() -> APIClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [SpecContractURLProtocol.self]
        return APIClient(token: "token", session: URLSession(configuration: configuration))
    }

    private func stubSuccess(_ json: String) {
        stub(status: 200, json: json)
    }

    private func stubFailure(status: Int, json: String) {
        stub(status: status, json: json)
    }

    private func stub(status: Int, json: String) {
        SpecContractURLProtocol.handler = { request in
            (
                HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!,
                Data(json.utf8)
            )
        }
    }

    private func performWithoutError(
        _ expectation: String,
        file: StaticString = #filePath,
        line: UInt = #line,
        _ operation: () async throws -> Void
    ) async {
        do {
            try await operation()
        } catch {
            XCTFail("expected success: \(expectation), but threw: \(error)", file: file, line: line)
        }
    }

    private func performWithError(
        _ expectation: String,
        file: StaticString = #filePath,
        line: UInt = #line,
        _ operation: () async throws -> Void
    ) async {
        do {
            try await operation()
            XCTFail("expected failure: \(expectation), but no error was thrown", file: file, line: line)
        } catch {}
    }

    private static func bodyData(of request: URLRequest) -> Data {
        if let body = request.httpBody { return body }
        guard let stream = request.httpBodyStream else { return Data() }
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

private final class SpecContractURLProtocol: URLProtocol {
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
