import Foundation
import XCTest

final class GeneratedOpenAPIClientAdoptionTests: XCTestCase {
    func testPackageDeclaresGeneratorAndRuntimeAndVendorsOpenAPIDocument() throws {
        let package = try String(contentsOf: repositoryFile("iOS/Package.swift"))
        let openAPIDocument = repositoryFile("iOS/OpenAPI/color-matching-api.yaml")

        XCTAssertTrue(package.contains("swift-openapi-generator"))
        XCTAssertTrue(package.contains("swift-openapi-runtime"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: openAPIDocument.path))
    }

    func testVendoredSpecificationDeclaresEveryAppAPIPath() throws {
        let documentURL = repositoryFile("iOS/OpenAPI/color-matching-api.yaml")
        guard FileManager.default.fileExists(atPath: documentURL.path) else {
            return XCTFail("Expected a vendored OpenAPI document at \(documentURL.path)")
        }
        let specification = try String(contentsOf: documentURL)

        [
            "/api/v1/test_sheets/{sheet_id}/manifest",
            "/api/v1/test_sheets/recent",
            "/api/v1/test_sheets/{sheet_id}/captures",
            "/api/v1/captures/{capture_id}/measurements",
            "/api/v1/captures/{capture_id}/judgments",
            "/api/v1/test_sheets/{sheet_id}/ranked_results"
        ].forEach { path in
            XCTAssertTrue(specification.contains(path), "OpenAPI document must cover \(path)")
        }
    }

    func testAppCoreImportsGeneratedAPIModule() throws {
        let appCore = try String(contentsOf: repositoryFile("iOS/Sources/ColorMatchingLPSAppCore/APIClient.swift"))

        XCTAssertTrue(appCore.contains("import ColorMatchingAPI"))
    }

    private func repositoryFile(_ relativePath: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(relativePath)
    }
}
