import Foundation
import XCTest

final class OpenAPIClientConfigurationTests: XCTestCase {
    func testPackageDeclaresOpenAPIGeneratorAndRuntime() throws {
        let package = try String(contentsOf: packageRoot.appending(path: "Package.swift"), encoding: .utf8)

        XCTAssertTrue(package.contains("apple/swift-openapi-generator"))
        XCTAssertTrue(package.contains("apple/swift-openapi-runtime"))
    }

    func testVendoredSpecificationDefinesEveryAppOperation() throws {
        let specificationURL = packageRoot.appending(path: "OpenAPI/color-matching.yaml")
        XCTAssertTrue(FileManager.default.fileExists(atPath: specificationURL.path))
        guard FileManager.default.fileExists(atPath: specificationURL.path) else { return }

        let specification = try String(contentsOf: specificationURL, encoding: .utf8)

        [
            "/api/v1/test_sheets/{sheet_id}/manifest",
            "/api/v1/test_sheets/recent",
            "/api/v1/test_sheets/{sheet_id}/captures",
            "/api/v1/captures/{capture_id}/measurements",
            "/api/v1/captures/{capture_id}/judgments",
            "/api/v1/test_sheets/{sheet_id}/ranked_results"
        ].forEach { path in
            XCTAssertTrue(specification.contains(path), "Missing OpenAPI path: \(path)")
        }
    }

    private var packageRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
