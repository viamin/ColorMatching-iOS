import Foundation
import XCTest

final class OpenAPIClientConfigurationTests: XCTestCase {
    func testVendoredOpenAPISpecDeclaresEveryCompanionSurface() throws {
        let spec = try openAPISpec()
        let paths = try XCTUnwrap(spec["paths"] as? [String: Any])

        XCTAssertNotNil(paths["/api/v1/test_sheets/recent"])
        XCTAssertNotNil(paths["/api/v1/test_sheets/{sheet_id}/manifest"])
        XCTAssertNotNil(paths["/api/v1/test_sheets/{sheet_id}/captures"])
        XCTAssertNotNil(paths["/api/v1/captures/{capture_id}/measurements"])
        XCTAssertNotNil(paths["/api/v1/captures/{capture_id}/judgments"])
        XCTAssertNotNil(paths["/api/v1/test_sheets/{sheet_id}/ranked_results"])
    }

    func testPackageUsesSwiftOpenAPIGeneratorAndRuntime() throws {
        let package = try String(contentsOf: packageURL(), encoding: .utf8)

        XCTAssertTrue(package.contains("swift-openapi-generator"))
        XCTAssertTrue(package.contains("swift-openapi-runtime"))
    }

    private func openAPISpec() throws -> [String: Any] {
        let data = try Data(contentsOf: packageURL().deletingLastPathComponent().appending(path: "OpenAPI/color-matching.json"))
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private func packageURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "Package.swift")
    }
}
