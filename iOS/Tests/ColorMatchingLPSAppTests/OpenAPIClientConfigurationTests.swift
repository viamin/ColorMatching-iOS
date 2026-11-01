import Foundation
import XCTest

final class OpenAPIClientConfigurationTests: XCTestCase {
    func testPackageTracksGeneratedClientDependenciesAndVendoredSpecification() throws {
        let iOSDirectory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let package = try String(contentsOf: iOSDirectory.appending(path: "Package.swift"))
        let specification = iOSDirectory.appending(path: "OpenAPI/color-matching-openapi.json")

        XCTAssertTrue(package.contains("swift-openapi-generator"))
        XCTAssertTrue(package.contains("swift-openapi-runtime"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: specification.path))
    }
}
