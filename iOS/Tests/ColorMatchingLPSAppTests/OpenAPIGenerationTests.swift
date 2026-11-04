import Foundation
import XCTest

final class OpenAPIGenerationTests: XCTestCase {
    func testPackageDeclaresOpenAPIGeneratorAndRuntimeDependencies() throws {
        let package = try String(contentsOf: packageRoot.appending(path: "Package.swift"))

        XCTAssertTrue(package.contains("swift-openapi-generator"))
        XCTAssertTrue(package.contains("swift-openapi-runtime"))
    }

    func testVendoredSpecDeclaresEveryCompanionOperation() throws {
        let specificationURL = packageRoot.appending(path: "OpenAPI/openapi.json")
        let data = try XCTUnwrap(try? Data(contentsOf: specificationURL), "Vendor the published OpenAPI document at \(specificationURL.path).")
        let document = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let paths = try XCTUnwrap(document["paths"] as? [String: Any])

        let expectedOperations = [
            "/api/v1/test_sheets/{sheet_id}/manifest": "get",
            "/api/v1/test_sheets/recent": "get",
            "/api/v1/test_sheets/{sheet_id}/captures": "post",
            "/api/v1/captures/{capture_id}/measurements": "post",
            "/api/v1/captures/{capture_id}/judgments": "post",
            "/api/v1/test_sheets/{sheet_id}/ranked_results": "get"
        ]

        for (path, method) in expectedOperations {
            let operation = (paths[path] as? [String: Any])?[method]
            XCTAssertNotNil(operation, "Expected \(method.uppercased()) \(path) in the vendored OpenAPI document.")
        }
    }

    private var packageRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
