import Foundation
import XCTest

final class OpenAPIContractTests: XCTestCase {
    func testPackageDeclaresGeneratedClientDependencies() throws {
        let package = try String(contentsOf: packageRoot.appending(path: "Package.swift"), encoding: .utf8)

        XCTAssertTrue(package.contains("swift-openapi-generator"))
        XCTAssertTrue(package.contains("swift-openapi-runtime"))
    }

    func testVendoredSpecCoversEveryCompanionAPISurface() throws {
        let data = try Data(contentsOf: packageRoot.appending(path: "OpenAPI/color_matching.json"))
        let document = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let paths = try XCTUnwrap(document["paths"] as? [String: Any])

        XCTAssertTrue((document["openapi"] as? String)?.hasPrefix("3.") == true)
        assertOperation("get", at: "/api/v1/test_sheets/{sheet_id}/manifest", in: paths)
        assertOperation("get", at: "/api/v1/test_sheets/recent", in: paths)
        assertOperation("post", at: "/api/v1/test_sheets/{sheet_id}/captures", in: paths)
        assertOperation("post", at: "/api/v1/captures/{capture_id}/measurements", in: paths)
        assertOperation("post", at: "/api/v1/captures/{capture_id}/judgments", in: paths)
        assertOperation("get", at: "/api/v1/test_sheets/{sheet_id}/ranked_results", in: paths)
    }

    private var packageRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func assertOperation(_ method: String, at path: String, in paths: [String: Any], file: StaticString = #filePath, line: UInt = #line) {
        let pathItem = paths[path] as? [String: Any]
        XCTAssertNotNil(pathItem?[method], "Expected \(method.uppercased()) \(path) in the vendored OpenAPI document.", file: file, line: line)
    }
}
