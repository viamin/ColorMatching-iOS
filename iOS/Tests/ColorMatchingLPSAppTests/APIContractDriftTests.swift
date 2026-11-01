import Foundation
import MeasurementCore
import XCTest
@testable import ColorMatchingLPSAppCore

/// Red-phase tests for deltas discovered between `docs/color-matching-api-contract.md`
/// and the real `/api/v1` API published by `viamin/color_matching` once
/// `viamin/color_matching#110` ("Publish OpenAPI 3 spec for the /api/v1 API and enforce it
/// in CI") was closed via `viamin/color_matching#113`.
///
/// These tests exercise the *current* hand-written `APIClient` against stubbed responses
/// shaped like the real server (per `ColorMatchingWeb.ApiSchemas`), not the prose contract.
/// They are expected to fail until the generated OpenAPI client replaces the hand-written
/// models; see `docs/color-matching-api-contract-deltas.md` for the full delta list.
final class APIContractDriftTests: XCTestCase {
    override func tearDown() {
        DriftMockURLProtocol.handler = nil
        super.tearDown()
    }

    /// `docs/color-matching-api-contract.md` documents a top-level `scoring_algorithm_version`
    /// field on the measurement upload payload. The real `MeasurementUploadRequest` schema
    /// (`ColorMatchingWeb.ApiSchemas`) has no such field: each `pair_scores` item carries its
    /// own required `algorithm_version` instead. The hand-written client still sends the
    /// undocumented-in-the-real-schema top-level field.
    func testUploadMeasurementsOmitsTopLevelScoringAlgorithmVersion() async throws {
        var capturedBody: Data?
        DriftMockURLProtocol.handler = { request in
            capturedBody = request.httpBodyStream.flatMap(Self.readBody) ?? request.httpBody
            return (
                HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                Data(#"{"capture_id":"cap_1","measurement_count":1,"pair_score_count":1}"#.utf8)
            )
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
        XCTAssertNil(
            json["scoring_algorithm_version"],
            "real MeasurementUploadRequest schema has no top-level scoring_algorithm_version field; it belongs on each pair_scores item"
        )
    }

    /// The real API returns structured error bodies shaped `{"errors": {"detail": "..."}}`
    /// (confirmed from the `api_auth` plug and `ApiSchemas.ErrorResponse`). The hand-written
    /// client discards the response body on failure and throws a bare `APIError.badStatus`
    /// with no detail, so callers can't surface *why* a request failed.
    func testServerErrorDetailIsSurfacedInsteadOfGenericBadStatus() async throws {
        DriftMockURLProtocol.handler = { request in
            (
                HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!,
                Data(#"{"errors":{"detail":"Unauthorized"}}"#.utf8)
            )
        }

        do {
            _ = try await client().fetchRecentSheets(baseURL: URL(string: "https://example.test")!)
            XCTFail("expected an error to be thrown for a 401 response")
        } catch {
            XCTAssertTrue(
                String(describing: error).contains("Unauthorized"),
                "real API error responses are shaped {\"errors\":{\"detail\":...}}; the client should surface that detail instead of a bare APIError.badStatus"
            )
        }
    }

    /// The real `CaptureMetadata` schema requires `image_width` and `image_height`
    /// (alongside `device_model`, `lens`, `app_version`, `timestamp`). The hand-written
    /// Swift `CaptureMetadata` models both as optional `Int?`, so a caller can build a
    /// request that omits them entirely — the synthesized `Encodable` conformance skips
    /// nil keys rather than sending `null` or refusing to compile.
    func testCaptureMetadataAlwaysSendsRequiredImageDimensions() async throws {
        var capturedBody: Data?
        DriftMockURLProtocol.handler = { request in
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
            quality: CaptureQuality(detectedMarkerCount: 4, blurScore: 0.75, rejections: [])
        )

        let json = try XCTUnwrap(Self.jsonObject(from: capturedBody) as? [String: Any])
        let metadata = try XCTUnwrap(json["metadata"] as? [String: Any])
        XCTAssertNotNil(metadata["image_width"], "real CaptureMetadata schema requires image_width")
        XCTAssertNotNil(metadata["image_height"], "real CaptureMetadata schema requires image_height")
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
