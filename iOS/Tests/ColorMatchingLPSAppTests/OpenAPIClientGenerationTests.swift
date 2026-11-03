import Foundation
import XCTest

final class OpenAPIClientGenerationTests: XCTestCase {
    func testPackageTracksGeneratedClientDependenciesAndVendoredSpecification() throws {
        let package = try String(contentsOf: repositoryFile("Package.swift"), encoding: .utf8)

        XCTAssertTrue(package.contains("swift-openapi-generator"))
        XCTAssertTrue(package.contains("swift-openapi-runtime"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: repositoryFile("OpenAPI/color-matching-api.json").path))
    }

    func testVendoredSpecificationDeclaresEveryAppOperation() throws {
        let data = try Data(contentsOf: repositoryFile("OpenAPI/color-matching-api.json"))
        let specification = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let paths = try XCTUnwrap(specification?["paths"] as? [String: Any])

        XCTAssertNotNil(paths["/api/v1/test_sheets/{sheet_id}/manifest"])
        XCTAssertNotNil(paths["/api/v1/test_sheets/recent"])
        XCTAssertNotNil(paths["/api/v1/test_sheets/{sheet_id}/captures"])
        XCTAssertNotNil(paths["/api/v1/captures/{capture_id}/measurements"])
        XCTAssertNotNil(paths["/api/v1/captures/{capture_id}/judgments"])
        XCTAssertNotNil(paths["/api/v1/test_sheets/{sheet_id}/ranked_results"])
    }

    private func repositoryFile(_ relativePath: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(relativePath)
    }
}
