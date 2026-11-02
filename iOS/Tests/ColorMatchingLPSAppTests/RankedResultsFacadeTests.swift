import Foundation
import XCTest
import ColorMatchingAPIClient
@testable import ColorMatchingLPSAppCore

final class RankedResultsFacadeTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.handler = nil
        super.tearDown()
    }

    func testFetchRankedResultsRequestsSheetPathWithBearerTokenAndDecodesGeneratedPayload() async throws {
        var capturedRequest: URLRequest?
        MockURLProtocol.handler = { request in
            capturedRequest = request
            return (
                HTTPURLResponse(
                    url: request.url!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "application/json"]
                )!,
                Data(Self.rankedResultsJSON.utf8)
            )
        }

        let results = try await Self.makeClient().fetchRankedResults(
            baseURL: Self.baseURL,
            sheetID: "lps-7f3a"
        )

        XCTAssertEqual(capturedRequest?.httpMethod, "GET")
        XCTAssertEqual(capturedRequest?.url?.path, "/api/v1/test_sheets/lps-7f3a/ranked_results")
        XCTAssertEqual(capturedRequest?.value(forHTTPHeaderField: "Authorization"), "Bearer token")
        XCTAssertEqual(results.schemaVersion, .lpsRankedResultsV1)
        XCTAssertEqual(results.sheetId, "lps-7f3a")
    }

    func testFetchRankedResultsThrowsOnUnauthorizedStatus() async throws {
        MockURLProtocol.handler = { request in
            (
                HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!,
                Data(#"{"errors":{"detail":"Unauthorized"}}"#.utf8)
            )
        }

        do {
            _ = try await Self.makeClient().fetchRankedResults(baseURL: Self.baseURL, sheetID: "lps-7f3a")
            XCTFail("Expected fetchRankedResults to throw on 401")
        } catch let error as APIError {
            guard case .badStatus = error else { return XCTFail("Unexpected APIError case: \(error)") }
        } catch {
            XCTFail("Expected APIError, got \(error)")
        }
    }

    private static let baseURL = URL(string: "https://color-matching.example.test")!

    private static func makeClient() -> APIClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        return APIClient(token: "token", session: URLSession(configuration: configuration))
    }

    private static let rankedResultsJSON = """
        {
          "schema_version": "lps-ranked-results/v1",
          "sheet_id": "lps-7f3a",
          "printer_profile": {
            "printer_make_model": "SureColor P700",
            "paper_type": "Premium Luster",
            "ink_type": "UltraChrome HD",
            "icc_profile": null,
            "print_settings": {},
            "driver_name": null,
            "driver_version": null,
            "calibration_date": null,
            "calibration_version": null,
            "notes": null
          },
          "capture_count": 2,
          "latest_capture_at": "2026-10-20T09:30:00Z",
          "earliest_capture_at": "2026-10-19T18:05:00Z",
          "scoring_algorithm_versions": ["lps-distance-v1"],
          "results": [
            {
              "rank": 1,
              "pair_id": "pair_1",
              "scoring_algorithm_version": "lps-distance-v1",
              "row": 0,
              "col": 1,
              "source_colors": {"color_a_hex": "#FF0000", "color_b_hex": "#00FF00"},
              "score": {
                "average": 0.035,
                "latest": 0.031,
                "minimum": 0.031,
                "maximum": 0.039,
                "capture_count": 2,
                "sample_count": 2,
                "algorithm_versions": ["lps-distance-v1"]
              },
              "current_judgment": "near_match",
              "current_judgment_observed_at": "2026-10-20T09:31:00Z",
              "observation_count": 1,
              "latest_observation": {"judgment": "near_match", "observed_at": "2026-10-20T09:31:00Z"},
              "capture_count": 2,
              "latest_capture_at": "2026-10-20T09:30:00Z",
              "earliest_capture_at": "2026-10-19T18:05:00Z"
            }
          ]
        }
        """
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
