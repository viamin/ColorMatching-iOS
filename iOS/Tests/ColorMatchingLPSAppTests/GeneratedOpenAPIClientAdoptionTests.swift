import Foundation
import XCTest

final class GeneratedOpenAPIClientAdoptionTests: XCTestCase {
    func testPackageWiresGeneratorRuntimeAndVendoredAPISpec() throws {
        let package = try String(contentsOf: packageURL)

        XCTAssertTrue(package.contains("swift-openapi-generator"))
        XCTAssertTrue(package.contains("swift-openapi-runtime"))
        XCTAssertTrue(package.contains("OpenAPIGenerator"))
        XCTAssertTrue(package.contains("OpenAPIRuntime"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: openAPISpecURL.path))

        let specification = try String(contentsOf: openAPISpecURL)
        [
            "/api/v1/test_sheets/{sheet_id}/manifest",
            "/api/v1/test_sheets/recent",
            "/api/v1/test_sheets/{sheet_id}/captures",
            "/api/v1/captures/{capture_id}/measurements",
            "/api/v1/captures/{capture_id}/judgments",
            "/api/v1/test_sheets/{sheet_id}/ranked_results"
        ].forEach { path in
            XCTAssertTrue(specification.contains(path), "Missing generated-client operation: \(path)")
        }
    }

    private var iOSDirectoryURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private var packageURL: URL {
        iOSDirectoryURL.appending(path: "Package.swift")
    }

    private var openAPISpecURL: URL {
        iOSDirectoryURL.appending(path: "OpenAPI/openapi.json")
    }
}
