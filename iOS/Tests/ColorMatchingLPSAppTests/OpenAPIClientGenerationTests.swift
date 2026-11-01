import Foundation
import XCTest

final class OpenAPIClientGenerationTests: XCTestCase {
    func testGeneratedClientSourceIsCheckedIn() throws {
        let testDirectory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let packageDirectory = testDirectory
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let generatedClient = packageDirectory.appending(path: "Sources/ColorMatchingOpenAPI/Generated/Client.swift")

        XCTAssertTrue(
            FileManager.default.fileExists(atPath: generatedClient.path),
            "Regenerate and check in the OpenAPI client from viamin/color_matching /api/v1/openapi.json."
        )
    }

    func testRankedResultsStubDocumentsThePublishedResponseSurface() throws {
        let response = try JSONSerialization.jsonObject(with: Data(Self.rankedResultsResponse.utf8)) as? [String: Any]
        let result = try XCTUnwrap((response?["results"] as? [[String: Any]])?.first)
        let score = try XCTUnwrap(result["score"] as? [String: Any])

        XCTAssertEqual(response?["schema_version"] as? String, "lps-ranked-results/v1")
        XCTAssertEqual(result["pair_id"] as? String, "pair-1")
        XCTAssertEqual(score["latest"] as? Double, 0.965)
        XCTAssertEqual(result["current_judgment"] as? String, "near_match")
    }

    private static let rankedResultsResponse = #"""
    {
      "schema_version": "lps-ranked-results/v1",
      "sheet_id": "ABCD-1234",
      "printer_profile": {"printer_make_model": "Research printer", "paper_type": "matte", "ink_type": "pigment"},
      "capture_count": 1,
      "latest_capture_at": "2026-10-30T12:00:00Z",
      "earliest_capture_at": "2026-10-30T12:00:00Z",
      "scoring_algorithm_versions": ["lps-distance-v1"],
      "results": [{
        "rank": 1,
        "pair_id": "pair-1",
        "scoring_algorithm_version": "lps-distance-v1",
        "row": 0,
        "col": 0,
        "source_colors": {"color_a_hex": "#112233", "color_b_hex": "#445566"},
        "score": {"average": 0.965, "latest": 0.965, "minimum": 0.965, "maximum": 0.965, "capture_count": 1, "sample_count": 1, "algorithm_versions": ["lps-distance-v1"]},
        "current_judgment": "near_match",
        "current_judgment_observed_at": "2026-10-30T12:01:00Z",
        "observation_count": 1,
        "latest_observation": {"judgment": "near_match", "observed_at": "2026-10-30T12:01:00Z"},
        "capture_count": 1,
        "latest_capture_at": "2026-10-30T12:00:00Z",
        "earliest_capture_at": "2026-10-30T12:00:00Z"
      }]
    }
    """
}
