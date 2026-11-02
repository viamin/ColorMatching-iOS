import Foundation
import XCTest

final class OpenAPIContractTests: XCTestCase {
    func testPackageDeclaresSwiftOpenAPIGeneratorAndRuntime() throws {
        let manifest = try String(contentsOf: packageManifestURL)

        XCTAssertTrue(manifest.contains("swift-openapi-generator"))
        XCTAssertTrue(manifest.contains("swift-openapi-runtime"))
    }

    func testVendoredOpenAPIDocumentCoversEveryAppOperation() throws {
        let data = try Data(contentsOf: openAPIDocumentURL)
        let document = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let paths = try XCTUnwrap(document["paths"] as? [String: Any])

        try assertOperation("get", at: "/api/v1/test_sheets/{sheet_id}/manifest", in: paths)
        try assertOperation("get", at: "/api/v1/test_sheets/recent", in: paths)
        try assertOperation("post", at: "/api/v1/test_sheets/{sheet_id}/captures", in: paths)
        try assertOperation("post", at: "/api/v1/captures/{capture_id}/measurements", in: paths)
        try assertOperation("post", at: "/api/v1/captures/{capture_id}/judgments", in: paths)
        try assertOperation("get", at: "/api/v1/test_sheets/{sheet_id}/ranked_results", in: paths)
    }

    private func assertOperation(_ method: String, at path: String, in paths: [String: Any]) throws {
        let pathItem = try XCTUnwrap(paths[path] as? [String: Any], "Missing OpenAPI path: \(path)")
        let operation = try XCTUnwrap(pathItem[method] as? [String: Any], "Missing \(method.uppercased()) operation: \(path)")
        XCTAssertNotNil(operation["responses"], "Operation must declare responses: \(method.uppercased()) \(path)")
    }

    private var packageManifestURL: URL {
        repositoryRoot.appending(path: "iOS/Package.swift")
    }

    private var openAPIDocumentURL: URL {
        repositoryRoot.appending(path: "iOS/OpenAPI/openapi.json")
    }

    private var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
