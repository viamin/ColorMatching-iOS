import Foundation
import XCTest

final class OpenAPIClientIntegrationTests: XCTestCase {
    func testPackageDeclaresOpenAPIGeneratorAndRuntime() throws {
        let package = try String(contentsOfFile: packagePath())

        XCTAssertTrue(package.contains("swift-openapi-generator"))
        XCTAssertTrue(package.contains("swift-openapi-runtime"))
    }

    func testRankedResultsStubContainsPublishedResponseShape() throws {
        let response = try JSONSerialization.jsonObject(with: Data(rankedResultsStub.utf8)) as? [String: Any]
        let results = try XCTUnwrap(response?["results"] as? [[String: Any]])
        let result = try XCTUnwrap(results.first)

        XCTAssertEqual(response?["schema_version"] as? String, "lps-ranked-results/v1")
        XCTAssertEqual(result["pair_id"] as? String, "pair-1")
        XCTAssertEqual((result["score"] as? [String: Any])?["average"] as? Double, 0.91)
        XCTAssertEqual((result["source_colors"] as? [String: Any])?["color_a_hex"] as? String, "#FF0000")
    }

    private func packagePath() -> String {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Package.swift")
            .path
    }

    private let rankedResultsStub = #"""
    {
      "schema_version": "lps-ranked-results/v1",
      "sheet_id": "SHEET-1",
      "capture_count": 1,
      "scoring_algorithm_versions": ["lps-distance-v1"],
      "results": [{
        "rank": 1,
        "pair_id": "pair-1",
        "scoring_algorithm_version": "lps-distance-v1",
        "row": 0,
        "col": 0,
        "source_colors": {"color_a_hex": "#FF0000", "color_b_hex": "#00FF00"},
        "score": {"average": 0.91, "latest": 0.91, "minimum": 0.91, "maximum": 0.91, "capture_count": 1, "sample_count": 1, "algorithm_versions": ["lps-distance-v1"]},
        "current_judgment": "near_match",
        "current_judgment_observed_at": "2026-10-30T00:00:00Z",
        "observation_count": 1,
        "latest_observation": {"judgment": "near_match", "observed_at": "2026-10-30T00:00:00Z"},
        "capture_count": 1,
        "latest_capture_at": "2026-10-30T00:00:00Z",
        "earliest_capture_at": "2026-10-30T00:00:00Z"
      }]
    }
    """
}
