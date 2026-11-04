import Foundation
import XCTest

final class OpenAPIClientAdoptionTests: XCTestCase {
    func testPackageDeclaresTheOpenAPIClientToolchain() throws {
        let packageURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "Package.swift")
        let package = try String(contentsOf: packageURL)

        XCTAssertTrue(package.contains("swift-openapi-generator"))
        XCTAssertTrue(package.contains("swift-openapi-runtime"))
        XCTAssertTrue(package.contains("OpenAPIGenerator"))
    }
}
