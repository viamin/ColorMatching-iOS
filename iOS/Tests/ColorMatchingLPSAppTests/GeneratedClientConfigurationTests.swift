import Foundation
import XCTest

final class GeneratedClientConfigurationTests: XCTestCase {
    func testPackageBuildsTheClientFromVendoredOpenAPISpecification() throws {
        let package = try String(contentsOf: packageURL, encoding: .utf8)

        XCTAssertTrue(package.contains("swift-openapi-generator"))
        XCTAssertTrue(package.contains("swift-openapi-runtime"))
        XCTAssertTrue(package.contains("OpenAPIGenerator"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: openAPISpecURL.path))
    }

    func testGeneratedClientCoversEveryCompanionSurface() throws {
        let generatedClient = try String(contentsOf: generatedClientURL, encoding: .utf8)

        [
            "/api/v1/test_sheets/{sheet_id}/manifest",
            "/api/v1/test_sheets/recent",
            "/api/v1/test_sheets/{sheet_id}/captures",
            "/api/v1/captures/{capture_id}/measurements",
            "/api/v1/captures/{capture_id}/judgments",
            "/api/v1/test_sheets/{sheet_id}/ranked_results"
        ].forEach { path in
            XCTAssertTrue(generatedClient.contains(path), "Generated client does not cover \(path)")
        }
    }

    private var packageURL: URL {
        repositoryURL.appending(path: "iOS/Package.swift")
    }

    private var openAPISpecURL: URL {
        repositoryURL.appending(path: "iOS/openapi/color-matching.json")
    }

    private var generatedClientURL: URL {
        repositoryURL.appending(path: "iOS/Sources/ColorMatchingAPI/Generated/Client.swift")
    }

    private var repositoryURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
