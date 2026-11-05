import Foundation
import XCTest

final class OpenAPIClientIntegrationTests: XCTestCase {
    func testPackageDeclaresOpenAPIGeneratorAndRuntimeForVendoredContract() throws {
        let package = try String(contentsOf: packageURL, encoding: .utf8)

        XCTAssertTrue(package.contains("swift-openapi-generator"))
        XCTAssertTrue(package.contains("swift-openapi-runtime"))
        XCTAssertTrue(package.contains("OpenAPIGenerator"))
        XCTAssertTrue(package.contains("OpenAPIRuntime"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: vendoredSpecURL.path))
    }

    private var packageURL: URL {
        iosDirectory.appending(path: "Package.swift")
    }

    private var vendoredSpecURL: URL {
        iosDirectory.appending(path: "OpenAPI/color-matching.openapi.json")
    }

    private var iosDirectory: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
