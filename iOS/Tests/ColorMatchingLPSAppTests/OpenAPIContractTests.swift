import Foundation
import XCTest

final class OpenAPIContractTests: XCTestCase {
    func testPackageDeclaresGeneratorRuntimeAndGeneratedClientTarget() throws {
        let package = try String(contentsOf: iosRoot.appending(path: "Package.swift"))

        XCTAssertTrue(package.contains("swift-openapi-generator"))
        XCTAssertTrue(package.contains("swift-openapi-runtime"))
        XCTAssertTrue(package.contains("ColorMatchingAPI"))
        XCTAssertTrue(package.contains("OpenAPIGenerator"))
    }

    func testVendoredSpecCoversEveryAppEndpoint() throws {
        let specificationURL = iosRoot.appending(path: "Sources/ColorMatchingAPI/openapi.json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: specificationURL.path), "Vendor the spec served by color_matching at /api/v1/openapi.json.")

        let data = try Data(contentsOf: specificationURL)
        let document = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let paths = try XCTUnwrap(document["paths"] as? [String: Any])

        [
            "/api/v1/test_sheets/{sheet_id}/manifest",
            "/api/v1/test_sheets/recent",
            "/api/v1/test_sheets/{sheet_id}/captures",
            "/api/v1/captures/{capture_id}/measurements",
            "/api/v1/captures/{capture_id}/judgments",
            "/api/v1/test_sheets/{sheet_id}/ranked_results"
        ].forEach { path in
            XCTAssertNotNil(paths[path], "Missing OpenAPI path: \(path)")
        }
    }

    private var iosRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
