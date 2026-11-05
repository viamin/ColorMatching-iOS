import Foundation
import XCTest

final class OpenAPIGenerationConfigurationTests: XCTestCase {
    func testPackagePinsGeneratorRuntimeAndPublishedSpec() throws {
        let package = try String(contentsOf: packageURL, encoding: .utf8)
        let spec = specURL

        XCTAssertTrue(package.contains("swift-openapi-generator"))
        XCTAssertTrue(package.contains("swift-openapi-runtime"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: spec.path), "Vendor the published OpenAPI document for reproducible generation.")
    }

    func testVendoredSpecDocumentsEveryCompanionSurface() throws {
        let document = try String(contentsOf: specURL, encoding: .utf8)

        [
            "/api/v1/test_sheets/recent",
            "/api/v1/test_sheets/{sheet_id}/manifest",
            "/api/v1/test_sheets/{sheet_id}/captures",
            "/api/v1/captures/{capture_id}/measurements",
            "/api/v1/captures/{capture_id}/judgments",
            "/api/v1/test_sheets/{sheet_id}/ranked_results"
        ].forEach { path in
            XCTAssertTrue(document.contains(path), "Missing generated-client surface: \(path)")
        }
    }

    private var packageURL: URL {
        repositoryRoot.appending(path: "iOS/Package.swift")
    }

    private var specURL: URL {
        repositoryRoot.appending(path: "iOS/OpenAPI/color_matching.openapi.json")
    }

    private var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
