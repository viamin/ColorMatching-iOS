import Foundation
import XCTest

final class OpenAPIClientMigrationTests: XCTestCase {
    func testPackageDeclaresOpenAPIGeneratorAndRuntimeDependencies() throws {
        let package = try String(contentsOf: packageURL)

        XCTAssertTrue(package.contains("swift-openapi-generator"))
        XCTAssertTrue(package.contains("swift-openapi-runtime"))
    }

    func testPublishedSpecIsVendoredForRepeatableClientGeneration() {
        XCTAssertTrue(FileManager.default.fileExists(atPath: openAPISpecURL.path))
    }

    private var packageURL: URL {
        repositoryURL.appending(path: "iOS/Package.swift")
    }

    private var openAPISpecURL: URL {
        repositoryURL.appending(path: "iOS/Sources/ColorMatchingLPSAppCore/openapi.json")
    }

    private var repositoryURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
