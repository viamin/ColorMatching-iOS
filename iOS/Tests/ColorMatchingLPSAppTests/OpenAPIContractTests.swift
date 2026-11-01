import Foundation
import XCTest

final class OpenAPIContractTests: XCTestCase {
    func testVendoredDocumentDescribesEveryOperationUsedByTheApp() throws {
        let document = try openAPIDocument()
        let version = try XCTUnwrap(document["openapi"] as? String)
        XCTAssertTrue(version.hasPrefix("3."))

        let paths = try XCTUnwrap(document["paths"] as? [String: Any])
        try assertOperation("get", at: "/api/v1/test_sheets/{sheet_id}/manifest", in: paths)
        try assertOperation("get", at: "/api/v1/test_sheets/recent", in: paths)
        try assertOperation("post", at: "/api/v1/test_sheets/{sheet_id}/captures", in: paths)
        try assertOperation("post", at: "/api/v1/captures/{capture_id}/measurements", in: paths)
        try assertOperation("post", at: "/api/v1/captures/{capture_id}/judgments", in: paths)
        try assertOperation("get", at: "/api/v1/test_sheets/{sheet_id}/ranked_results", in: paths)
    }

    func testPackageDeclaresTheOpenAPIRuntimeAndBuildPlugin() throws {
        let package = try String(contentsOf: packageURL(), encoding: .utf8)

        XCTAssertTrue(package.contains("swift-openapi-generator"))
        XCTAssertTrue(package.contains("swift-openapi-runtime"))
        XCTAssertTrue(package.contains("OpenAPIGenerator"))
        XCTAssertTrue(package.contains("OpenAPIRuntime"))
    }

    private func openAPIDocument() throws -> [String: Any] {
        let data = try Data(contentsOf: packageRoot().appending(path: "OpenAPI/color-matching.openapi.json"))
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private func assertOperation(_ method: String, at path: String, in paths: [String: Any]) throws {
        let pathItem = try XCTUnwrap(paths[path] as? [String: Any], "Missing OpenAPI path: \(path)")
        XCTAssertNotNil(pathItem[method], "Missing \(method.uppercased()) operation for \(path)")
    }

    private func packageURL() -> URL {
        packageRoot().appending(path: "Package.swift")
    }

    private func packageRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
