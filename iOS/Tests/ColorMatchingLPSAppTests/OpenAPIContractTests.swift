import Foundation
import XCTest

final class OpenAPIContractTests: XCTestCase {
    func testVendoredOpenAPISpecFullyTypesEveryAppSurface() throws {
        let specURL = repositoryRoot
            .appending(path: "iOS/OpenAPI/color-matching.json")
        let data = try Data(contentsOf: specURL)
        let spec = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let paths = try XCTUnwrap(spec["paths"] as? [String: Any])
        let schemas = try XCTUnwrap((spec["components"] as? [String: Any])?["schemas"] as? [String: Any])

        for path in [
            "/api/v1/test_sheets/{sheet_id}/manifest",
            "/api/v1/test_sheets/recent",
            "/api/v1/test_sheets/{sheet_id}/captures",
            "/api/v1/captures/{capture_id}/measurements",
            "/api/v1/captures/{capture_id}/judgments",
            "/api/v1/test_sheets/{sheet_id}/ranked_results"
        ] {
            XCTAssertNotNil(paths[path], "The vendored contract must include \(path).")
        }

        XCTAssertEqual(requiredProperties(in: schemas, named: "TestSheetManifest"), [
            "capture_profile", "manifest_url", "page", "patches", "pairs", "registration_markers", "schema_version", "sheet_id", "sheet_version"
        ])
        XCTAssertEqual(requiredProperties(in: schemas, named: "RankedResults"), [
            "capture_count", "printer_profile", "results", "schema_version", "scoring_algorithm_versions", "sheet_id"
        ])
        XCTAssertEqual(requiredProperties(in: schemas, named: "RecentSheetsResponse"), ["sheets"])
        XCTAssertEqual(requiredProperties(in: schemas, named: "CaptureCreatedResponse"), ["capture_id"])
        XCTAssertEqual(requiredProperties(in: schemas, named: "MeasurementUploadResponse"), ["capture_id", "measurement_count", "pair_score_count"])
        XCTAssertEqual(requiredProperties(in: schemas, named: "JudgmentUploadResponse"), ["capture_id", "judgment_count"])
    }

    private var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func requiredProperties(in schemas: [String: Any], named name: String) -> [String] {
        let schema = schemas[name] as? [String: Any]
        return ((schema?["required"] as? [String]) ?? []).sorted()
    }
}
