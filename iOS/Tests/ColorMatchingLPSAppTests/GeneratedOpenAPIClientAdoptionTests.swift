import Foundation
import XCTest

final class GeneratedOpenAPIClientAdoptionTests: XCTestCase {
    func testPackageDeclaresOpenAPIGeneratorAndRuntime() throws {
        let package = try String(contentsOf: packageManifestURL)

        XCTAssertTrue(package.contains("swift-openapi-generator"))
        XCTAssertTrue(package.contains("swift-openapi-runtime"))
    }

    func testPublishedSpecificationIsVendoredForReproducibleGeneration() {
        XCTAssertTrue(FileManager.default.fileExists(atPath: specificationURL.path))
    }

    private var packageManifestURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Package.swift")
    }

    private var specificationURL: URL {
        packageManifestURL
            .deletingLastPathComponent()
            .appendingPathComponent("OpenAPI/openapi.json")
    }
}
