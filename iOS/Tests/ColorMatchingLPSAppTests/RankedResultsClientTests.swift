import Foundation
import XCTest
@testable import ColorMatchingLPSAppCore

final class RankedResultsClientTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.handler = nil
        super.tearDown()
    }

    func testFetchRankedResultsDecodesPublishedResponse() async throws {
        var capturedRequest: URLRequest?
        MockURLProtocol.handler = { request in
            capturedRequest = request
            return try StubResponse.ok(APIFixtures.rankedResultsJSON, for: request)
        }

        let results = try await stubbedClient().fetchRankedResults(
            sheetID: "sheet_1",
            baseURL: URL(string: "https://example.test")!
        )

        XCTAssertEqual(capturedRequest?.url?.path, "/api/v1/test_sheets/sheet_1/ranked_results")
        XCTAssertEqual(capturedRequest?.httpMethod, "GET")
        XCTAssertEqual(capturedRequest?.value(forHTTPHeaderField: "Authorization"), "Bearer token")
        XCTAssertEqual(results.schemaVersion, "lps-ranked-results/v1")
        XCTAssertEqual(results.sheetID, "sheet_1")
        let top = try XCTUnwrap(results.results.first)
        XCTAssertEqual(top.rank, 1)
        XCTAssertEqual(top.pairID, "pair_1")
        XCTAssertEqual(top.row, 0)
        XCTAssertEqual(top.col, 1)
        XCTAssertEqual(top.colorAHex, "#FF0000")
        XCTAssertEqual(top.colorBHex, "#00FF00")
        XCTAssertEqual(top.averageScore, 0.04, accuracy: 0.0001)
        XCTAssertEqual(top.latestScore, 0.05, accuracy: 0.0001)
        XCTAssertEqual(top.currentJudgment, "near_match")
    }

    func testFetchRankedResultsWithNoJudgmentsDecodesNilCurrentJudgment() async throws {
        MockURLProtocol.handler = { request in
            let json = """
            {
              "schema_version": "lps-ranked-results/v1",
              "sheet_id": "sheet_1",
              "printer_profile": {
                "id": 7,
                "printer_make_model": "Canon PIXMA Pro-200",
                "paper_type": "Ilford Galerie Smooth Pearl",
                "ink_type": "CLI-42 dye",
                "icc_profile": null,
                "print_settings": {},
                "driver_name": null,
                "driver_version": null,
                "calibration_date": null,
                "calibration_version": null,
                "notes": null
              },
              "capture_count": 1,
              "latest_capture_at": "2026-07-25T12:30:00Z",
              "earliest_capture_at": "2026-07-25T12:30:00Z",
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
                    "average": 0.04,
                    "latest": 0.04,
                    "minimum": 0.04,
                    "maximum": 0.04,
                    "capture_count": 1,
                    "sample_count": 2,
                    "algorithm_versions": ["lps-distance-v1"]
                  },
                  "current_judgment": null,
                  "current_judgment_observed_at": null,
                  "observation_count": 0,
                  "latest_observation": null,
                  "capture_count": 1,
                  "latest_capture_at": "2026-07-25T12:30:00Z",
                  "earliest_capture_at": "2026-07-25T12:30:00Z"
                }
              ]
            }
            """
            return try StubResponse.ok(Data(json.utf8), for: request)
        }

        let results = try await stubbedClient().fetchRankedResults(
            sheetID: "sheet_1",
            baseURL: URL(string: "https://example.test")!
        )

        XCTAssertEqual(results.results.count, 1)
        XCTAssertNil(results.results.first?.currentJudgment)
    }

    func testFetchRankedResultsThrowsWhenSheetMissing() async throws {
        MockURLProtocol.handler = { request in
            try StubResponse.make(status: 404, body: APIFixtures.errorJSON, for: request)
        }

        do {
            _ = try await stubbedClient().fetchRankedResults(
                sheetID: "missing_sheet",
                baseURL: URL(string: "https://example.test")!
            )
            XCTFail("Expected an error for a missing sheet")
        } catch {}
    }
}
