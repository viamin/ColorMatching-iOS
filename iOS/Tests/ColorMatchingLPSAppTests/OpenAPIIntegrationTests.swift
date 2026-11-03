import Foundation
import XCTest

final class OpenAPIIntegrationTests: XCTestCase {
    func testPackageDeclaresGeneratedClientDependenciesAndVendoredContract() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let package = try String(contentsOf: repositoryRoot.appending(path: "Package.swift"))
        let specification = repositoryRoot.appending(path: "OpenAPI/color_matching.json")

        XCTAssertTrue(package.contains("swift-openapi-generator"))
        XCTAssertTrue(package.contains("swift-openapi-runtime"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: specification.path))
    }
}
