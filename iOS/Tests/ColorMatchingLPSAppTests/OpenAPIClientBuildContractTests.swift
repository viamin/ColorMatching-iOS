import Foundation
import XCTest

final class OpenAPIClientBuildContractTests: XCTestCase {
    func testPackageDeclaresPinnedOpenAPIGeneratorAndRuntimeDependencies() throws {
        let package = try String(contentsOf: packageRoot.appending(path: "Package.swift"))

        XCTAssertTrue(package.contains("swift-openapi-generator"))
        XCTAssertTrue(package.contains("swift-openapi-runtime"))
        XCTAssertTrue(package.contains("OpenAPIGenerator"))
        XCTAssertTrue(package.contains("OpenAPIRuntime"))
    }

    func testVendoredOpenAPIDocumentCoversEveryCompanionSurface() throws {
        let document = try String(contentsOf: packageRoot.appending(path: "Sources/OpenAPIClient/openapi.json"))

        for path in [
            "/api/v1/test_sheets/{sheet_id}/manifest",
            "/api/v1/test_sheets/recent",
            "/api/v1/test_sheets/{sheet_id}/captures",
            "/api/v1/captures/{capture_id}/measurements",
            "/api/v1/captures/{capture_id}/judgments",
            "/api/v1/test_sheets/{sheet_id}/ranked_results"
        ] {
            XCTAssertTrue(document.contains(path), "Missing OpenAPI operation: \(path)")
        }
    }

    private var packageRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
