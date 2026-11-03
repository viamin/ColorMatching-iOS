import Foundation
import XCTest

final class OpenAPIContractTests: XCTestCase {
    func testVendoredOpenAPIDocumentCoversEveryCompanionOperation() throws {
        let document = try openAPIDocument()
        let paths = try XCTUnwrap(document["paths"] as? [String: Any])

        try assertOperation("get", at: "/api/v1/test_sheets/{sheet_id}/manifest", in: paths)
        try assertOperation("get", at: "/api/v1/test_sheets/recent", in: paths)
        try assertOperation("post", at: "/api/v1/test_sheets/{sheet_id}/captures", in: paths)
        try assertOperation("post", at: "/api/v1/captures/{capture_id}/measurements", in: paths)
        try assertOperation("post", at: "/api/v1/captures/{capture_id}/judgments", in: paths)
        try assertOperation("get", at: "/api/v1/test_sheets/{sheet_id}/ranked_results", in: paths)
    }

    func testPackageDeclaresGeneratedClientDependencies() throws {
        let package = try String(contentsOf: packageURL())

        XCTAssertTrue(package.contains("swift-openapi-generator"))
        XCTAssertTrue(package.contains("swift-openapi-runtime"))
    }

    private func openAPIDocument() throws -> [String: Any] {
        let data = try Data(contentsOf: packageRootURL().appending(path: "OpenAPI/color_matching.openapi.json"))
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private func assertOperation(_ method: String, at path: String, in paths: [String: Any]) throws {
        let operations = try XCTUnwrap(paths[path] as? [String: Any], "Missing OpenAPI path: \(path)")
        XCTAssertNotNil(operations[method], "Missing \(method.uppercased()) operation for \(path)")
    }

    private func packageRootURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func packageURL() -> URL {
        packageRootURL().appending(path: "Package.swift")
    }
}
