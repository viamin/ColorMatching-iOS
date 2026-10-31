import Foundation
import XCTest

final class OpenAPIContractTests: XCTestCase {
    func testVendoredOpenAPISpecDeclaresEveryCompanionSurface() throws {
        let specificationURL = iosDirectory.appending(path: "OpenAPI/color-matching-openapi.json")
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: specificationURL.path),
            "Vendor the published /api/v1 OpenAPI document at \(specificationURL.path)."
        )
        guard FileManager.default.fileExists(atPath: specificationURL.path) else { return }

        let data = try Data(contentsOf: specificationURL)
        let document = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let paths = try XCTUnwrap(document["paths"] as? [String: Any])

        XCTAssertEqual(document["openapi"] as? String, "3.0.0")
        XCTAssertNotNil(paths["/api/v1/test_sheets/{sheet_id}/manifest"])
        XCTAssertNotNil(paths["/api/v1/test_sheets/recent"])
        XCTAssertNotNil(paths["/api/v1/test_sheets/{sheet_id}/captures"])
        XCTAssertNotNil(paths["/api/v1/captures/{capture_id}/measurements"])
        XCTAssertNotNil(paths["/api/v1/captures/{capture_id}/judgments"])
        XCTAssertNotNil(paths["/api/v1/test_sheets/{sheet_id}/ranked_results"])
    }

    func testPackageDeclaresOpenAPIGeneratorAndRuntimeDependencies() throws {
        let packageURL = iosDirectory.appending(path: "Package.swift")
        let package = try String(contentsOf: packageURL, encoding: .utf8)

        XCTAssertTrue(package.contains("swift-openapi-generator"))
        XCTAssertTrue(package.contains("swift-openapi-runtime"))
    }

    private var iosDirectory: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
