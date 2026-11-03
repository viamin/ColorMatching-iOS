import Foundation
import XCTest

final class GeneratedOpenAPIClientConfigurationTests: XCTestCase {
    func testPackageWiresTheGeneratorRuntimeAndVendoredPublishedSpec() throws {
        let packageRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let package = try String(contentsOf: packageRoot.appending(path: "Package.swift"), encoding: .utf8)

        XCTAssertTrue(package.contains("swift-openapi-generator"))
        XCTAssertTrue(package.contains("swift-openapi-runtime"))
        XCTAssertTrue(package.contains("OpenAPIGenerator"))
        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: packageRoot.appending(path: "Sources/ColorMatchingLPSAppCore/OpenAPI/openapi.json").path
            )
        )
    }
}
