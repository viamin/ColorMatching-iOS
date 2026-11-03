import Foundation
import XCTest

final class OpenAPIContractTests: XCTestCase {
    func testPackageDeclaresTheOpenAPIGeneratorAndRuntime() throws {
        let package = try String(contentsOf: packageRoot.appending(path: "Package.swift"))

        XCTAssertTrue(package.contains("swift-openapi-generator"))
        XCTAssertTrue(package.contains("swift-openapi-runtime"))
    }

    func testVendoredSpecIncludesEveryCompanionEndpoint() throws {
        let specURL = packageRoot.appending(path: "OpenAPI/openapi.json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: specURL.path), "Vendor the published /api/v1/openapi.json document.")
        guard FileManager.default.fileExists(atPath: specURL.path) else { return }

        let document = try JSONSerialization.jsonObject(with: Data(contentsOf: specURL))
        let paths = try XCTUnwrap((document as? [String: Any])?["paths"] as? [String: Any])
        let expectedOperations = [
            "/api/v1/test_sheets/recent": "get",
            "/api/v1/test_sheets/{sheet_id}/manifest": "get",
            "/api/v1/test_sheets/{sheet_id}/captures": "post",
            "/api/v1/captures/{capture_id}/measurements": "post",
            "/api/v1/captures/{capture_id}/judgments": "post",
            "/api/v1/test_sheets/{sheet_id}/ranked_results": "get"
        ]

        for (path, method) in expectedOperations {
            let operations = try XCTUnwrap(paths[path] as? [String: Any], "Missing OpenAPI path: \(path)")
            XCTAssertNotNil(operations[method], "Missing OpenAPI operation: \(method.uppercased()) \(path)")
        }
    }

    private var packageRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
