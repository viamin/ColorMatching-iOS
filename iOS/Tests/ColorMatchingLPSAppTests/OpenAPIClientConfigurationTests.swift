import Foundation
import XCTest

final class OpenAPIClientConfigurationTests: XCTestCase {
    func testPackageConfiguresOpenAPIGenerationForTheIOSContract() throws {
        let package = try String(contentsOf: packageURL, encoding: .utf8)

        XCTAssertTrue(package.contains("swift-openapi-generator"))
        XCTAssertTrue(package.contains("swift-openapi-runtime"))
        XCTAssertTrue(package.contains("swift-openapi-urlsession"))
        XCTAssertTrue(package.contains("OpenAPIGenerator"))
    }

    private var packageURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Package.swift")
    }
}
