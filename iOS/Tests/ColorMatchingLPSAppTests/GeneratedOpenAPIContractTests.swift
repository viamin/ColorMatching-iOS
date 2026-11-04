import Foundation
import XCTest

final class GeneratedOpenAPIContractTests: XCTestCase {
    func testVendoredSpecificationDeclaresEveryAppAPIPath() throws {
        let specificationURL = packageRoot
            .appending(path: "OpenAPI")
            .appending(path: "color-matching.json")
        let specificationData = try Data(contentsOf: specificationURL)
        let specification = try XCTUnwrap(
            JSONSerialization.jsonObject(with: specificationData) as? [String: Any]
        )
        let paths = try XCTUnwrap(specification["paths"] as? [String: Any])

        XCTAssertTrue(Set(expectedPaths).isSubset(of: Set(paths.keys)))
    }

    func testPackageDeclaresGeneratorAndRuntimeDependencies() throws {
        let package = try String(contentsOf: packageRoot.appending(path: "Package.swift"))

        XCTAssertTrue(package.contains("swift-openapi-generator"))
        XCTAssertTrue(package.contains("swift-openapi-runtime"))
    }

    private var packageRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private let expectedPaths = [
        "/api/v1/test_sheets/{sheet_id}/manifest",
        "/api/v1/test_sheets/recent",
        "/api/v1/test_sheets/{sheet_id}/captures",
        "/api/v1/captures/{capture_id}/measurements",
        "/api/v1/captures/{capture_id}/judgments",
        "/api/v1/test_sheets/{sheet_id}/ranked_results"
    ]
}
