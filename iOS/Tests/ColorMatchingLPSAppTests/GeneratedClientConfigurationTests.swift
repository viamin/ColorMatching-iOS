import Foundation
import XCTest

final class GeneratedClientConfigurationTests: XCTestCase {
    func testPackageConfiguresOpenAPIGeneratorRuntimeAndGenerationPlugin() throws {
        let package = try String(contentsOf: packageManifestURL, encoding: .utf8)

        XCTAssertTrue(package.contains("swift-openapi-generator"))
        XCTAssertTrue(package.contains("swift-openapi-runtime"))
        XCTAssertTrue(package.contains("SwiftOpenAPIGenerator"))
        XCTAssertTrue(package.contains("openapi.yaml") || package.contains("openapi.json"))
    }

    private var packageManifestURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Package.swift")
    }
}
