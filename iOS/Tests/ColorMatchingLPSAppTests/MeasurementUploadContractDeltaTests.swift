import Foundation
import MeasurementCore
import XCTest
@testable import ColorMatchingLPSAppCore

/// Pins the client's measurement-upload request body against the published
/// OpenAPI `MeasurementUploadRequest` schema (`ColorMatchingWeb.ApiSchemas`
/// in `viamin/color_matching`, added by PR #113 which closed
/// `viamin/color_matching#110`).
///
/// That schema declares only `measurements` and `pair_scores` at the top
/// level -- `scoring_algorithm_version` lives per pair score as
/// `algorithm_version`, not as a sibling of `measurements`. The hand-written
/// `APIClient.uploadMeasurements` still sends a top-level
/// `scoring_algorithm_version` key per the (now outdated) prose contract in
/// `docs/color-matching-api-contract.md`. A generated client built from the
/// published spec would not have a slot to put that value in at the top
/// level, so this currently fails and should guide the generated-client swap.
final class MeasurementUploadContractDeltaTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.handler = nil
        super.tearDown()
    }

    func testUploadMeasurementsBodyMatchesPublishedSchemaKeys() async throws {
        var capturedBody: Data?
        MockURLProtocol.handler = { request in
            capturedBody = request.httpBodyStream.flatMap(Self.readBody) ?? request.httpBody
            return (
                HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                Data(#"{"capture_id":"cap_1","measurement_count":1,"pair_score_count":1}"#.utf8)
            )
        }

        let rgb = RGB(r: 0.2, g: 0.3, b: 0.4)
        let stats = ChannelStats(
            median: rgb,
            mean: rgb,
            standardDeviation: RGB(r: 0.01, g: 0.01, b: 0.01),
            min: rgb,
            max: rgb,
            sampleCount: 9,
            clippingFraction: 0
        )

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let client = APIClient(token: "token", session: URLSession(configuration: configuration))

        try await client.uploadMeasurements(
            captureID: "cap_1",
            baseURL: URL(string: "https://example.test")!,
            measurements: [PatchMeasurement(patchID: "patch_1", linearRGBMedian: rgb, normalizedLinearRGBMedian: rgb, stats: stats)],
            scores: [PairScore(pairID: "pair_1", distance: 0.1, similarity: 0.9, algorithmVersion: LPSScorer.algorithmVersion)]
        )

        let json = try XCTUnwrap(Self.jsonObject(from: capturedBody) as? [String: Any])
        XCTAssertEqual(
            Set(json.keys),
            ["measurements", "pair_scores"],
            "published MeasurementUploadRequest schema (color_matching#110) declares only measurements/pair_scores at the top level; the client also sends scoring_algorithm_version"
        )
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
