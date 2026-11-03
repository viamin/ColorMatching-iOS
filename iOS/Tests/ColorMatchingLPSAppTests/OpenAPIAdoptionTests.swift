import Foundation
import XCTest

final class OpenAPIAdoptionTests: XCTestCase {
    func testPackageDeclaresOpenAPIGeneratorAndRuntimeDependencies() throws {
        let package = try String(contentsOf: packageRoot.appending(path: "Package.swift"))

        XCTAssertTrue(package.contains("swift-openapi-generator"))
        XCTAssertTrue(package.contains("swift-openapi-runtime"))
    }

    func testAPISpecIsAvailableToRegenerateTheClient() {
        let candidateURLs = [
            packageRoot.appending(path: "OpenAPI/color-matching-api.json"),
            packageRoot.appending(path: "OpenAPI/color-matching-api.yaml"),
            packageRoot.appending(path: "OpenAPI/color-matching-api.yml")
        ]

        XCTAssertTrue(
            candidateURLs.contains(where: { FileManager.default.fileExists(atPath: $0.path) }),
            "Vendor the published /api/v1 OpenAPI document so generated-client changes are reviewable."
        )
    }

    private var packageRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
