import Foundation
import MeasurementCore
import XCTest
@testable import ColorMatchingLPSAppCore

/// Pins the hand-written `APIClient` against the real `color_matching`
/// OpenAPI contract published in viamin/color_matching#113 (closing
/// viamin/color_matching#110), not the prose in
/// `docs/color-matching-api-contract.md`. See
/// `docs/openapi-contract-deltas.md` for the full list of deltas found.
///
/// These tests exist ahead of the swift-openapi-generator migration (#5) to
/// make server-side drift visible now, as a failing assertion, instead of as
/// a silent extra field today and a generator-time surprise later.
final class APIContractDriftTests: XCTestCase {
    override func tearDown() {
        DriftMockURLProtocol.handler = nil
        super.tearDown()
    }

    /// `ColorMatchingWeb.ApiSchemas.MeasurementUploadRequest` (the published
    /// schema backing `POST /api/v1/captures/:capture_id/measurements`) only
    /// defines a top-level `measurements` / `pair_scores`, and each
    /// measurement only `patch_id`, `linear_rgb_median`,
    /// `normalized_linear_rgb_median`. There is no top-level
    /// `scoring_algorithm_version` and no per-measurement `stats`. A request
    /// body type generated from that schema will have no field to carry
    /// either, so the hand-written client must stop sending them.
    func testUploadMeasurementsBodyMatchesPublishedMeasurementUploadRequestSchema() async throws {
        var capturedBody: Data?
        DriftMockURLProtocol.handler = { request in
            capturedBody = request.httpBodyStream.flatMap(Self.readBody) ?? request.httpBody
            return (
                HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                Data(#"{"capture_id":"1","measurement_count":1,"pair_score_count":1}"#.utf8)
            )
        }

        let rgb = RGB(r: 0.2, g: 0.3, b: 0.4)
        let stats = ChannelStats(median: rgb, mean: rgb, standardDeviation: RGB(r: 0.01, g: 0.01, b: 0.01), min: rgb, max: rgb, sampleCount: 9, clippingFraction: 0)
        try await client().uploadMeasurements(
            captureID: "1",
            baseURL: URL(string: "https://example.test")!,
            measurements: [PatchMeasurement(patchID: "patch_1", linearRGBMedian: rgb, normalizedLinearRGBMedian: rgb, stats: stats)],
            scores: [PairScore(pairID: "pair_1", distance: 0.1, similarity: 0.9, algorithmVersion: LPSScorer.algorithmVersion)]
        )

        let json = try XCTUnwrap(Self.jsonObject(from: capturedBody) as? [String: Any])
        XCTAssertEqual(
            Set(json.keys),
            ["measurements", "pair_scores"],
            "published MeasurementUploadRequest schema has no top-level scoring_algorithm_version field"
        )
        let measurement = try XCTUnwrap((json["measurements"] as? [[String: Any]])?.first)
        XCTAssertEqual(
            Set(measurement.keys),
            ["patch_id", "linear_rgb_median", "normalized_linear_rgb_median"],
            "published MeasurementUploadRequest schema has no per-measurement stats field"
        )
    }

    /// `ColorMatchingWeb.ApiSchemas.CaptureRequest` is `anyOf` the flat
    /// top-level device fields or a `metadata` object, so the app's current
    /// nested `{"metadata": {...}, "quality": {...}}` body already satisfies
    /// the real, published schema. This guards against the generated-client
    /// migration accidentally changing the request shape, which issue #5
    /// calls out as a non-goal.
    func testCreateCaptureNestedBodySatisfiesPublishedCaptureRequestSchema() async throws {
        var capturedBody: Data?
        DriftMockURLProtocol.handler = { request in
            capturedBody = request.httpBodyStream.flatMap(Self.readBody) ?? request.httpBody
            return (
                HTTPURLResponse(url: request.url!, statusCode: 201, httpVersion: nil, headerFields: nil)!,
                Data(#"{"capture_id":"1"}"#.utf8)
            )
        }

        _ = try await client().createCapture(
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

        let json = try XCTUnwrap(Self.jsonObject(from: capturedBody) as? [String: Any])
        let metadata = try XCTUnwrap(json["metadata"] as? [String: Any])

        // The real CaptureRequest's `metadata`-branch requires exactly these keys.
        let requiredMetadataKeys: Set<String> = ["device_model", "lens", "image_width", "image_height", "app_version", "timestamp"]
        XCTAssertTrue(
            requiredMetadataKeys.isSubset(of: Set(metadata.keys)),
            "CaptureRequest's metadata anyOf branch requires \(requiredMetadataKeys), got \(metadata.keys)"
        )
    }

    private func client() -> APIClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [DriftMockURLProtocol.self]
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

private final class DriftMockURLProtocol: URLProtocol {
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
