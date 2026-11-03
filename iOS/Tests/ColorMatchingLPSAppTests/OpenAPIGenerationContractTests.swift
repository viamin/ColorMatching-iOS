import Foundation
import XCTest

final class OpenAPIGenerationContractTests: XCTestCase {
    func testPackageWiresAppleOpenAPIGeneratorAndRuntime() throws {
        let package = try String(contentsOf: iOSDirectory.appending(path: "Package.swift"), encoding: .utf8)

        XCTAssertTrue(package.contains("swift-openapi-generator"))
        XCTAssertTrue(package.contains("swift-openapi-runtime"))
        XCTAssertTrue(package.contains("OpenAPIGenerator"))
        XCTAssertTrue(package.contains("OpenAPIRuntime"))
    }

    func testVendoredSpecificationCoversEveryAppAPIEndpoint() throws {
        let specification = try String(contentsOf: iOSDirectory.appending(path: "OpenAPI/color_matching.yaml"), encoding: .utf8)

        [
            "/api/v1/test_sheets/{sheet_id}/manifest",
            "/api/v1/test_sheets/recent",
            "/api/v1/test_sheets/{sheet_id}/captures",
            "/api/v1/captures/{capture_id}/measurements",
            "/api/v1/captures/{capture_id}/judgments",
            "/api/v1/test_sheets/{sheet_id}/ranked_results"
        ].forEach { endpoint in
            XCTAssertTrue(specification.contains(endpoint), "Missing endpoint: \(endpoint)")
        }
    }

    private var iOSDirectory: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
