import Foundation
import MeasurementCore
import XCTest
@testable import ColorMatchingLPSAppCore

/// Red-phase coverage for issue #5 ("Replace hand-written API layer with a generated
/// OpenAPI Swift client"): each test below encodes a concrete divergence between the
/// hand-written contract (`docs/color-matching-api-contract.md`) and the published
/// `viamin/color_matching` OpenAPI spec (closed via viamin/color_matching#110, merged in
/// viamin/color_matching#113). See `docs/color-matching-api-contract-deltas.md` for the
/// full list of deltas and the sources used to find them.
///
/// These tests exercise the *current* hand-written `APIClient` and are expected to fail
/// until the generated client replaces it: they document what must change, not what
/// already works.
final class APIContractDeltaTests: XCTestCase {
    override func tearDown() {
        DeltaMockURLProtocol.handler = nil
        super.tearDown()
    }

    /// color_matching's `MeasurementUploadRequest.measurements[]` schema (api_schemas.ex)
    /// marks `normalized_linear_rgb_median` as a *required* field. The hand-written
    /// `MeasurementUpload` wrapper only emits it via `encodeIfPresent`, so a measurement
    /// captured before normalization (`normalizedLinearRGBMedian == nil`) silently drops
    /// the key instead of satisfying the contract.
    func testUploadMeasurementsOmitsNormalizedMedianWhenNilButRealContractRequiresIt() async throws {
        var capturedBody: Data?
        DeltaMockURLProtocol.handler = { request in
            capturedBody = request.httpBodyStream.flatMap(Self.readBody) ?? request.httpBody
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data(#"{"capture_id":"cap_1","measurement_count":1,"pair_score_count":0}"#.utf8))
        }

        let rgb = RGB(r: 0.2, g: 0.3, b: 0.4)
        let stats = ChannelStats(median: rgb, mean: rgb, standardDeviation: RGB(r: 0.01, g: 0.01, b: 0.01), min: rgb, max: rgb, sampleCount: 9, clippingFraction: 0)
        try await client().uploadMeasurements(
            captureID: "cap_1",
            baseURL: URL(string: "https://example.test")!,
            measurements: [PatchMeasurement(patchID: "patch_1", linearRGBMedian: rgb, normalizedLinearRGBMedian: nil, stats: stats)],
            scores: []
        )

        let json = try XCTUnwrap(Self.jsonObject(from: capturedBody) as? [String: Any])
        let measurement = try XCTUnwrap((json["measurements"] as? [[String: Any]])?.first)
        XCTAssertNotNil(
            measurement["normalized_linear_rgb_median"],
            "color_matching's MeasurementUploadRequest schema requires normalized_linear_rgb_median on every measurement"
        )
    }

    /// color_matching's `CaptureMetadata` schema (api_schemas.ex) requires `image_width`
    /// and `image_height`. The hand-written `CaptureMetadata` model types both as `Int?`,
    /// so a capture built without known dimensions silently omits required fields instead
    /// of failing fast or always populating them.
    func testCreateCaptureOmitsRequiredImageDimensionsWhenNil() async throws {
        var capturedBody: Data?
        DeltaMockURLProtocol.handler = { request in
            capturedBody = request.httpBodyStream.flatMap(Self.readBody) ?? request.httpBody
            return (HTTPURLResponse(url: request.url!, statusCode: 201, httpVersion: nil, headerFields: nil)!, Data(#"{"capture_id":"cap_1"}"#.utf8))
        }

        _ = try await client().createCapture(
            sheetID: "sheet_1",
            baseURL: URL(string: "https://example.test")!,
            metadata: CaptureMetadata(
                deviceModel: "iPhone",
                lens: "wide",
                exposureDurationSeconds: nil,
                iso: nil,
                focusLensPosition: nil,
                whiteBalanceGains: nil,
                imageWidth: nil,
                imageHeight: nil,
                appVersion: "0.1.0",
                timestamp: Date(timeIntervalSince1970: 0)
            ),
            quality: CaptureQuality(detectedMarkerCount: 0, blurScore: 0, rejections: [])
        )

        let json = try XCTUnwrap(Self.jsonObject(from: capturedBody) as? [String: Any])
        let metadata = try XCTUnwrap(json["metadata"] as? [String: Any])
        XCTAssertNotNil(metadata["image_width"], "color_matching's CaptureMetadata schema requires image_width")
        XCTAssertNotNil(metadata["image_height"], "color_matching's CaptureMetadata schema requires image_height")
    }

    /// color_matching's `MeasurementUploadRequest` schema (api_schemas.ex) only defines
    /// `measurements` and `pair_scores` at the top level, and each measurement only has
    /// `patch_id`, `linear_rgb_median`, and `normalized_linear_rgb_median` — there is no
    /// `scoring_algorithm_version` field on the request, and no per-measurement `stats`
    /// object. The hand-written client sends both anyway.
    func testUploadMeasurementsBodyIncludesFieldsAbsentFromRealSchema() async throws {
        var capturedBody: Data?
        DeltaMockURLProtocol.handler = { request in
            capturedBody = request.httpBodyStream.flatMap(Self.readBody) ?? request.httpBody
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data(#"{"capture_id":"cap_1","measurement_count":1,"pair_score_count":1}"#.utf8))
        }

        let rgb = RGB(r: 0.2, g: 0.3, b: 0.4)
        let stats = ChannelStats(median: rgb, mean: rgb, standardDeviation: RGB(r: 0.01, g: 0.01, b: 0.01), min: rgb, max: rgb, sampleCount: 9, clippingFraction: 0)
        try await client().uploadMeasurements(
            captureID: "cap_1",
            baseURL: URL(string: "https://example.test")!,
            measurements: [PatchMeasurement(patchID: "patch_1", linearRGBMedian: rgb, normalizedLinearRGBMedian: rgb, stats: stats)],
            scores: [PairScore(pairID: "pair_1", distance: 0.1, similarity: 0.9, algorithmVersion: "lps-distance-v1")]
        )

        let json = try XCTUnwrap(Self.jsonObject(from: capturedBody) as? [String: Any])
        XCTAssertNil(json["scoring_algorithm_version"], "color_matching's MeasurementUploadRequest schema has no top-level scoring_algorithm_version field")
        let measurement = try XCTUnwrap((json["measurements"] as? [[String: Any]])?.first)
        XCTAssertNil(measurement["stats"], "color_matching's measurements[] schema has no stats field")
    }

    private func client() -> APIClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [DeltaMockURLProtocol.self]
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

private final class DeltaMockURLProtocol: URLProtocol {
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
