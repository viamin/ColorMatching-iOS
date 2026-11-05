import Foundation
import XCTest

final class OpenAPIClientConfigurationTests: XCTestCase {
    func testPackageConfiguresGeneratedClientFromVendoredOpenAPIDocument() throws {
        let package = try packageManifest()

        XCTAssertTrue(package.contains("swift-openapi-generator"))
        XCTAssertTrue(package.contains("swift-openapi-runtime"))
        XCTAssertTrue(package.contains("OpenAPIGenerator"))
        XCTAssertTrue(package.contains("OpenAPIRuntime"))
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: iOSRoot
                .appending(path: "Sources/ColorMatchingLPSAppCore/openapi.yaml").path)
        )
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: iOSRoot
                .appending(path: "Sources/ColorMatchingLPSAppCore/openapi-generator-config.yaml").path)
        )
    }

    private var iOSRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func packageManifest() throws -> String {
        try String(contentsOf: iOSRoot.appending(path: "Package.swift"), encoding: .utf8)
    }
}
