import Foundation
import XCTest

final class GeneratedOpenAPIClientConfigurationTests: XCTestCase {
    func testPackageAndVendoredSpecConfigureGeneratedClientForEveryUsedEndpoint() throws {
        let package = try String(contentsOf: repositoryFile("iOS/Package.swift"), encoding: .utf8)
        let specificationURL = repositoryFile("iOS/OpenAPI/color-matching-api.yaml")
        guard FileManager.default.fileExists(atPath: specificationURL.path) else {
            XCTFail("Vendored OpenAPI document is required at \(specificationURL.path)")
            return
        }
        let specification = try String(contentsOf: specificationURL, encoding: .utf8)

        XCTAssertTrue(package.contains("swift-openapi-generator"))
        XCTAssertTrue(package.contains("swift-openapi-runtime"))
        XCTAssertTrue(package.contains("OpenAPIGenerator"))

        [
            "/api/v1/test_sheets/{sheet_id}/manifest",
            "/api/v1/test_sheets/recent",
            "/api/v1/test_sheets/{sheet_id}/captures",
            "/api/v1/captures/{capture_id}/measurements",
            "/api/v1/captures/{capture_id}/judgments",
            "/api/v1/test_sheets/{sheet_id}/ranked_results"
        ].forEach { path in
            XCTAssertTrue(specification.contains(path), "Missing generated-client operation for \(path)")
        }
    }

    private func repositoryFile(_ relativePath: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: relativePath)
    }
}
