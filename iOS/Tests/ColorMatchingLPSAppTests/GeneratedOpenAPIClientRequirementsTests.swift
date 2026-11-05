import Foundation
import XCTest

final class GeneratedOpenAPIClientRequirementsTests: XCTestCase {
    func testPackageDeclaresOpenAPIGeneratorAndRuntimeDependencies() throws {
        let package = try packageFileContents()

        XCTAssertTrue(package.contains("swift-openapi-generator"))
        XCTAssertTrue(package.contains("swift-openapi-runtime"))
    }

    func testGeneratedClientCoversEveryCompanionAPISurface() throws {
        let client = try appCoreFileContents()

        [
            "fetchManifest",
            "fetchRecentSheets",
            "createCapture",
            "uploadMeasurements",
            "uploadJudgments",
            "fetchRankedResults",
            "Client"
        ].forEach { expectedSurface in
            XCTAssertTrue(client.contains(expectedSurface), "Expected generated-client adapter to expose \(expectedSurface)")
        }
    }

    private func packageFileContents() throws -> String {
        try String(contentsOf: packageRoot.appending(path: "Package.swift"), encoding: .utf8)
    }

    private func appCoreFileContents() throws -> String {
        try String(contentsOf: packageRoot.appending(path: "Sources/ColorMatchingLPSAppCore/APIClient.swift"), encoding: .utf8)
    }

    private var packageRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
