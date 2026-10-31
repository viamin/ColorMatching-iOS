import XCTest
@testable import ColorMatchingLPSAppCore

final class RankedResultsClientSurfaceTests: XCTestCase {
    override func tearDown() {
        StubURLProtocol.handler = nil
        super.tearDown()
    }

    func testFetchRankedResultsRequestsRankedResultsEndpointAndDecodesSchemaVersion() async throws {
        var capturedRequest: URLRequest?
        StubURLProtocol.handler = { request in
            capturedRequest = request
            return try StubHTTP.ok(StubbedResponses.rankedResultsJSON)(request)
        }

        let results = try await client().fetchRankedResults(
            sheetID: "sheet_123",
            baseURL: URL(string: "https://example.test")!
        )

        XCTAssertEqual(capturedRequest?.httpMethod, "GET")
        XCTAssertEqual(capturedRequest?.url?.path, "/api/v1/test_sheets/sheet_123/ranked_results")
        XCTAssertEqual(capturedRequest?.value(forHTTPHeaderField: "Authorization"), "Bearer token")
        XCTAssertEqual(results.schemaVersion, "lps-ranked-results/v1")
        XCTAssertEqual(results.sheetID, "sheet_123")
    }

    func testFetchRankedResultsThrowsOnUndecodablePayload() async throws {
        StubURLProtocol.handler = StubHTTP.ok("[]")

        do {
            _ = try await client().fetchRankedResults(
                sheetID: "sheet_123",
                baseURL: URL(string: "https://example.test")!
            )
            XCTFail("Expected a decoding error for a non-object ranked results payload")
        } catch {}
    }

    private func client() -> APIClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return APIClient(token: "token", session: URLSession(configuration: configuration))
    }
}
