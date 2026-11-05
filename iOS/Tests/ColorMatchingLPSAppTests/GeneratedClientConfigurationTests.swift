import Foundation
import XCTest

final class GeneratedClientConfigurationTests: XCTestCase {
    func testPackageDeclaresGeneratedOpenAPIClientDependencies() throws {
        let packageURL = try XCTUnwrap(
            findPackageURL(startingAt: URL(fileURLWithPath: #filePath))
        )
        let package = try String(contentsOf: packageURL)

        XCTAssertTrue(package.contains("swift-openapi-generator"))
        XCTAssertTrue(package.contains("swift-openapi-runtime"))
        XCTAssertTrue(package.contains("OpenAPIGenerator"))
        XCTAssertTrue(package.contains("OpenAPIRuntime"))
    }

    private func findPackageURL(startingAt fileURL: URL) -> URL? {
        var directory = fileURL.deletingLastPathComponent()
        while directory.path != "/" {
            let candidate = directory.appendingPathComponent("Package.swift")
            if FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
            directory.deleteLastPathComponent()
        }
        return nil
    }
}
