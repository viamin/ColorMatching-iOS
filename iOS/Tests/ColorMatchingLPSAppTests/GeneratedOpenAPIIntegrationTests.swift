import Foundation
import XCTest

final class GeneratedOpenAPIIntegrationTests: XCTestCase {
    func testPackageUsesOpenAPIGeneratorAndRuntimeForTheAppClient() throws {
        let package = try String(contentsOf: repositoryRoot.appending(path: "iOS/Package.swift"))

        XCTAssertTrue(package.contains("swift-openapi-generator"))
        XCTAssertTrue(package.contains("swift-openapi-runtime"))
        XCTAssertTrue(package.contains("OpenAPIGenerator"))
        XCTAssertTrue(package.contains("OpenAPIRuntime"))
    }

    func testVendoredOpenAPIDocumentDeclaresEveryAppSurface() throws {
        let specificationURL = repositoryRoot.appending(path: "iOS/Sources/ColorMatchingLPSAppCore/openapi.yaml")
        XCTAssertTrue(FileManager.default.fileExists(atPath: specificationURL.path))
        guard FileManager.default.fileExists(atPath: specificationURL.path) else { return }
        let specification = try String(contentsOf: specificationURL)

        [
            "/api/v1/test_sheets/{sheet_id}/manifest",
            "/api/v1/test_sheets/recent",
            "/api/v1/test_sheets/{sheet_id}/captures",
            "/api/v1/captures/{capture_id}/measurements",
            "/api/v1/captures/{capture_id}/judgments",
            "/api/v1/test_sheets/{sheet_id}/ranked_results"
        ].forEach { path in
            XCTAssertTrue(specification.contains(path), "Missing OpenAPI operation for \(path)")
        }
    }

    private var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
