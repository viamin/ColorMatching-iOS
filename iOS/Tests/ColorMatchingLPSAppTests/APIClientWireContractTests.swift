import Foundation
import MeasurementCore
import XCTest
@testable import ColorMatchingLPSAppCore

final class APIClientWireContractTests: XCTestCase {
    override func tearDown() {
        StubURLProtocol.handler = nil
        super.tearDown()
    }

    func testFetchManifestDecodesServerManifestShape() async throws {
        var capturedRequest: URLRequest?
        StubURLProtocol.handler = { request in
            capturedRequest = request
            return try StubHTTP.ok(StubbedResponses.manifestJSON)(request)
        }

        let manifest = try await client().fetchManifest(
            from: URL(string: "https://example.test/api/v1/test_sheets/sheet_123/manifest")!
        )

        XCTAssertEqual(capturedRequest?.httpMethod, "GET")
        XCTAssertEqual(capturedRequest?.url?.path, "/api/v1/test_sheets/sheet_123/manifest")
        XCTAssertEqual(capturedRequest?.value(forHTTPHeaderField: "Authorization"), "Bearer token")
        XCTAssertEqual(manifest.schemaVersion, "lps-sheet-manifest/v1")
        XCTAssertEqual(manifest.sheetID, "sheet_123")
        XCTAssertEqual(manifest.sheetVersion, "lps-letter-grid-v1")
        XCTAssertEqual(manifest.page.width, 215.9)
        XCTAssertEqual(manifest.registrationMarkers.first?.role, "top_left")
        XCTAssertEqual(manifest.patches.map(\.id), ["pair_1#first", "pair_1#second"])
        XCTAssertEqual(manifest.patches.first?.pairID, "pair_1")
        XCTAssertEqual(manifest.patches.first?.sourceColor, "#FF0000")
        XCTAssertEqual(manifest.pairs.first?.firstPatchID, "pair_1#first")
        XCTAssertEqual(manifest.pairs.first?.secondPatchID, "pair_1#second")
        XCTAssertEqual(manifest.pairs.first?.sourceColors, ["#FF0000", "#00FF00"])
    }

    func testFetchRecentSheetsDecodesNullableTitles() async throws {
        var capturedRequest: URLRequest?
        StubURLProtocol.handler = { request in
            capturedRequest = request
            return try StubHTTP.ok(StubbedResponses.recentSheetsJSON)(request)
        }

        let sheets = try await client().fetchRecentSheets(baseURL: URL(string: "https://example.test")!)

        XCTAssertEqual(capturedRequest?.url?.path, "/api/v1/test_sheets/recent")
        XCTAssertEqual(capturedRequest?.value(forHTTPHeaderField: "Authorization"), "Bearer token")
        XCTAssertEqual(sheets.count, 2)
        XCTAssertEqual(sheets.first?.sheetID, "sheet_123")
        XCTAssertEqual(sheets.first?.title, nil)
        XCTAssertEqual(sheets.last?.title, "July LPS comparison sheet")
    }

    func testUploadMeasurementsAccepts200WithJSONResponseBodyAndSendsNormalizedMedians() async throws {
        var capturedBody: Data?
        StubURLProtocol.handler = { request in
            capturedBody = StubURLProtocol.readBody(of: request)
            return try StubHTTP.ok(StubbedResponses.measurementUploadResponseJSON)(request)
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
        do {
            try await client().uploadMeasurements(
                captureID: "101",
                baseURL: URL(string: "https://example.test")!,
                measurements: [
                    PatchMeasurement(
                        patchID: "pair_1#first",
                        linearRGBMedian: rgb,
                        normalizedLinearRGBMedian: rgb,
                        stats: stats
                    )
                ],
                scores: [PairScore(pairID: "pair_1", distance: 0.1, similarity: 0.9, algorithmVersion: LPSScorer.algorithmVersion)]
            )
        } catch {
            XCTFail("Measurement upload must tolerate the server's 200 JSON response body: \(error)")
        }

        let json = try XCTUnwrap(Self.jsonObject(from: capturedBody) as? [String: Any])
        let measurement = try XCTUnwrap((json["measurements"] as? [[String: Any]])?.first)
        XCTAssertEqual(measurement["patch_id"] as? String, "pair_1#first")
        XCTAssertNotNil(
            measurement["normalized_linear_rgb_median"],
            "The published spec requires normalized_linear_rgb_median on every uploaded measurement"
        )
    }

    func testUploadJudgmentsAccepts200WithJSONResponseBody() async throws {
        StubURLProtocol.handler = StubHTTP.ok(StubbedResponses.judgmentUploadResponseJSON)

        do {
            try await client().uploadJudgments(
                captureID: "101",
                baseURL: URL(string: "https://example.test")!,
                judgments: [PairJudgment(pairID: "pair_1", judgment: "near_match")]
            )
        } catch {
            XCTFail("Judgment upload must tolerate the server's 200 JSON response body: \(error)")
        }
    }

    func testFetchManifestThrowsOnNotFoundError() async throws {
        StubURLProtocol.handler = StubHTTP.status(404, json: StubbedResponses.notFoundJSON)

        do {
            _ = try await client().fetchManifest(
                from: URL(string: "https://example.test/api/v1/test_sheets/sheet_missing/manifest")!
            )
            XCTFail("Expected an error for a 404 manifest response")
        } catch {}
    }

    private func client() -> APIClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return APIClient(token: "token", session: URLSession(configuration: configuration))
    }

    private static func jsonObject(from data: Data?) throws -> Any {
        try JSONSerialization.jsonObject(with: XCTUnwrap(data))
    }
}
