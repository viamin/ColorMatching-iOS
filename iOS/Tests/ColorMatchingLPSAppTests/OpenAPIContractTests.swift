import Foundation
import XCTest

final class OpenAPIContractTests: XCTestCase {
    private let requiredOperations: [(path: String, method: String)] = [
        ("/api/v1/test_sheets/{sheet_id}/manifest", "get"),
        ("/api/v1/test_sheets/recent", "get"),
        ("/api/v1/test_sheets/{sheet_id}/captures", "post"),
        ("/api/v1/captures/{capture_id}/measurements", "post"),
        ("/api/v1/captures/{capture_id}/judgments", "post"),
        ("/api/v1/test_sheets/{sheet_id}/ranked_results", "get")
    ]

    func testVendoredOpenAPISpecDeclaresEveryAppOperation() throws {
        let spec = try openAPISpec()
        let paths = try XCTUnwrap(spec["paths"] as? [String: Any])

        for operation in requiredOperations {
            let path = try XCTUnwrap(paths[operation.path] as? [String: Any], "Missing \(operation.path) from vendored OpenAPI spec")
            XCTAssertNotNil(path[operation.method], "Missing \(operation.method.uppercased()) \(operation.path) from vendored OpenAPI spec")
        }
    }

    func testPackageDeclaresGeneratorAndRuntimeDependencies() throws {
        let packageURL = repositoryURL().appendingPathComponent("Package.swift")
        let package = try String(contentsOf: packageURL, encoding: .utf8)

        XCTAssertTrue(package.contains("swift-openapi-generator"))
        XCTAssertTrue(package.contains("swift-openapi-runtime"))
    }

    private func openAPISpec() throws -> [String: Any] {
        let specURL = repositoryURL().appendingPathComponent("OpenAPI/color_matching.json")
        let data = try Data(contentsOf: specURL)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private func repositoryURL() -> URL {
        URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
    }
}
