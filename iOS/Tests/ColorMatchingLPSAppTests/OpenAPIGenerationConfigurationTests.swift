import Foundation
import XCTest

final class OpenAPIGenerationConfigurationTests: XCTestCase {
    func testPackageDeclaresGeneratorRuntimeAndGeneratedClientTarget() throws {
        let package = try String(contentsOf: packageFileURL, encoding: .utf8)

        XCTAssertTrue(package.contains("swift-openapi-generator"))
        XCTAssertTrue(package.contains("swift-openapi-runtime"))
        XCTAssertTrue(package.contains("OpenAPIGenerator"))
        XCTAssertTrue(package.contains("OpenAPIRuntime"))
    }

    func testGeneratedOpenAPIDocumentCoversEveryCompanionSurface() throws {
        let document = try String(contentsOf: openAPIDocumentURL, encoding: .utf8)

        [
            "/api/v1/test_sheets/{sheet_id}/manifest",
            "/api/v1/test_sheets/recent",
            "/api/v1/test_sheets/{sheet_id}/captures",
            "/api/v1/captures/{capture_id}/measurements",
            "/api/v1/captures/{capture_id}/judgments",
            "/api/v1/test_sheets/{sheet_id}/ranked_results"
        ].forEach { path in
            XCTAssertTrue(document.contains(path), "Missing OpenAPI path: \(path)")
        }
    }

    private var packageFileURL: URL {
        repositoryURL.appending(path: "iOS/Package.swift")
    }

    private var openAPIDocumentURL: URL {
        repositoryURL.appending(path: "iOS/Sources/ColorMatchingAPI/openapi.json")
    }

    private var repositoryURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
