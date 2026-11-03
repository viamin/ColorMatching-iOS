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

    func testFetchManifestDecodesLocalOpenAPIStub() async throws {
        var capturedRequest: URLRequest?
        MockURLProtocol.handler = { request in
            capturedRequest = request
            return (
                HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                Data(Self.manifestResponse.utf8)
            )
        }

        let manifest = try await client().fetchManifest(
            baseURL: URL(string: "https://example.test")!,
            sheetCode: "sheet_1"
        )

        XCTAssertEqual(capturedRequest?.httpMethod, "GET")
        XCTAssertEqual(capturedRequest?.url?.path, "/api/v1/test_sheets/sheet_1/manifest")
        XCTAssertEqual(capturedRequest?.value(forHTTPHeaderField: "Authorization"), "Bearer token")
        XCTAssertEqual(manifest.sheetID, "sheet_1")
        XCTAssertEqual(manifest.schemaVersion, "lps-sheet-manifest/v1")
    }

    func testFetchRecentSheetsDecodesLocalOpenAPIStub() async throws {
        MockURLProtocol.handler = { request in
            XCTAssertEqual(request.url?.path, "/api/v1/test_sheets/recent")
            return (
                HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                Data(#"{"sheets":[{"sheet_id":"sheet_1","manifest_url":"https://example.test/api/v1/test_sheets/sheet_1/manifest","title":null}]}"#.utf8)
            )
        }

        let sheets = try await client().fetchRecentSheets(baseURL: URL(string: "https://example.test")!)

        XCTAssertEqual(sheets.count, 1)
        XCTAssertEqual(sheets.first?.sheetID, "sheet_1")
        XCTAssertNil(sheets.first?.title)
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

    func testPackageDeclaresGeneratedOpenAPIClientDependencies() throws {
        let packageURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Package.swift")
        let package = try String(contentsOf: packageURL)

        XCTAssertTrue(
            package.contains("swift-openapi-generator"),
            "The package must declare swift-openapi-generator so API types are generated from the provider spec."
        )
        XCTAssertTrue(
            package.contains("swift-openapi-runtime"),
            "The package must declare swift-openapi-runtime for the generated client transport."
        )
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

    private static let manifestResponse = #"""
    {
      "schema_version": "lps-sheet-manifest/v1",
      "sheet_version": "lps-letter-grid-v1",
      "sheet_id": "sheet_1",
      "manifest_url": "https://example.test/api/v1/test_sheets/sheet_1/manifest",
      "page": {"units": "mm", "width": 215.9, "height": 279.4},
      "registration_markers": [],
      "patches": [],
      "pairs": []
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
