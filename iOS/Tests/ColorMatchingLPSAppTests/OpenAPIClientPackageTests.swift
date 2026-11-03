import Foundation
import XCTest

final class OpenAPIClientPackageTests: XCTestCase {
    func testPackageDeclaresGeneratedClientDependencies() throws {
        let package = try String(contentsOf: packageURL(), encoding: .utf8)

        XCTAssertTrue(package.contains("swift-openapi-generator"))
        XCTAssertTrue(package.contains("swift-openapi-runtime"))
        XCTAssertTrue(package.contains("OpenAPIGenerator"))
        XCTAssertTrue(package.contains("OpenAPIRuntime"))
    }

    func testVendoredSpecCoversEveryAppAPIOperation() throws {
        let specURL = packageURL().deletingLastPathComponent().appending(path: "OpenAPI/openapi.json")
        let data = try Data(contentsOf: specURL)
        let document = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let paths = try XCTUnwrap(document["paths"] as? [String: Any])

        XCTAssertNotNil(paths["/api/v1/test_sheets/{sheet_id}/manifest"])
        XCTAssertNotNil(paths["/api/v1/test_sheets/recent"])
        XCTAssertNotNil(paths["/api/v1/test_sheets/{sheet_id}/captures"])
        XCTAssertNotNil(paths["/api/v1/captures/{capture_id}/measurements"])
        XCTAssertNotNil(paths["/api/v1/captures/{capture_id}/judgments"])
        XCTAssertNotNil(paths["/api/v1/test_sheets/{sheet_id}/ranked_results"])
    }

    private func packageURL() -> URL {
        URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appending(path: "Package.swift")
    }
}
