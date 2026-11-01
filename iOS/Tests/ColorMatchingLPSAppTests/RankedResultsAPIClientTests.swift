import Foundation
import MeasurementCore
import XCTest
@testable import ColorMatchingLPSAppCore

// Issue #5: the "ranked results" surface is one of the endpoints the generated
// OpenAPI client must cover, but `APIClient` has no method for
// `GET /api/v1/test_sheets/:sheet_id/ranked_results` today (see
// docs/color-matching-api-contract.md, "Retrieve Ranked Results"). This test
// documents the expected call shape against a locally stubbed response; it
// will not compile until `fetchRankedResults` and its response types exist.
final class RankedResultsAPIClientTests: XCTestCase {
    override func tearDown() {
        MockRankedResultsURLProtocol.handler = nil
        super.tearDown()
    }

    func testFetchRankedResultsDecodesContractShapedResponse() async throws {
        let payload = Data(
            """
            {
              "sheet_id": "sheet_123",
              "scoring_algorithm_version": "lps-distance-v1",
              "printer_profile": {"id": "printer_profile_1", "name": "Research printer"},
              "results": [
                {
                  "pair_id": "pair_1",
                  "source_colors": ["#FF0000", "#00FF00"],
                  "distance": 0.035,
                  "similarity": 0.965,
                  "judgment": "near_match",
                  "capture_id": "capture_123"
                }
              ]
            }
            """.utf8
        )

        var capturedRequest: URLRequest?
        MockRankedResultsURLProtocol.handler = { request in
            capturedRequest = request
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, payload)
        }

        let response = try await client().fetchRankedResults(
            sheetID: "sheet_123",
            baseURL: URL(string: "https://example.test")!
        )

        XCTAssertEqual(capturedRequest?.url?.path, "/api/v1/test_sheets/sheet_123/ranked_results")
        XCTAssertEqual(capturedRequest?.httpMethod, "GET")
        XCTAssertEqual(response.sheetID, "sheet_123")
        XCTAssertEqual(response.scoringAlgorithmVersion, "lps-distance-v1")
        XCTAssertEqual(response.printerProfile?.id, "printer_profile_1")
        XCTAssertEqual(response.results.first?.pairID, "pair_1")
        XCTAssertEqual(response.results.first?.judgment, "near_match")
        XCTAssertEqual(response.results.first?.captureID, "capture_123")
    }

    private func client() -> APIClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockRankedResultsURLProtocol.self]
        return APIClient(token: "token", session: URLSession(configuration: configuration))
    }
}

private final class MockRankedResultsURLProtocol: URLProtocol {
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
