import XCTest

import ColorMatchingLPSAPI

final class RankedResultsTests: GeneratedClientTestCase {
    func testGetRankedResultsBuildsContractRequest() async throws {
        let recorder = RequestRecorder()
        let client = makeClient { request, body, _, operationID in
            await recorder.record(request, body: body, operationID: operationID)
            return HTTPResponse.stubbedJSON(.ok, Fixtures.rankedResults)
        }

        _ = try await client.getRankedResults(.init(path: .init(sheet_id: "sheet_1")))

        let request = try XCTUnwrap(recorder.request("getRankedResults"))
        XCTAssertEqual(request.method, .get)
        XCTAssertEqual(request.path, "/api/v1/test_sheets/sheet_1/ranked_results")
    }

    func testGetRankedResultsDecodesRankedPairs() async throws {
        let client = makeClient { _, _, _, _ in
            HTTPResponse.stubbedJSON(.ok, Fixtures.rankedResults)
        }

        let results = try await client
            .getRankedResults(.init(path: .init(sheet_id: "sheet_1")))
            .ok.body.json

        XCTAssertEqual(results.sheet_id, "sheet_1")
        XCTAssertEqual(results.scoring_algorithm_version, "lps-distance-v1")
        XCTAssertEqual(results.results.count, 1)
        assertRankedPair(try XCTUnwrap(results.results.first))
    }

    func testUndocumentedStatusSurfacesAsSwiftCase() async throws {
        let client = makeClient { _, _, _, _ in (HTTPResponse(status: .notFound), nil) }

        let response = try await client
            .getRankedResults(.init(path: .init(sheet_id: "missing")))

        guard case .undocumented(let statusCode, _) = response else {
            return XCTFail("Expected undocumented case for 404 response.")
        }
        XCTAssertEqual(statusCode, 404)
    }

    private func assertRankedPair(_ pair: Components.Schemas.RankedPairResult) {
        XCTAssertEqual(pair.pair_id, "pair_1")
        XCTAssertEqual(pair.source_colors, ["#FF0000", "#00FF00"])
        XCTAssertEqual(pair.distance, 0.035)
        XCTAssertEqual(pair.similarity, 0.965)
        XCTAssertEqual(pair.algorithm_version, "lps-distance-v1")
        XCTAssertEqual(pair.capture_id, "capture_123")
        XCTAssertEqual(pair.judgment, .near_match)
    }
}
