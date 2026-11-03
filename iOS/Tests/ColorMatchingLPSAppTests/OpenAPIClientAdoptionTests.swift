import Foundation
import XCTest

final class OpenAPIClientAdoptionTests: XCTestCase {
    func testPackageDeclaresOpenAPIGeneratorAndRuntimeDependencies() throws {
        let package = try sourceFile(named: "Package.swift")

        XCTAssertTrue(package.contains("swift-openapi-generator"))
        XCTAssertTrue(package.contains("swift-openapi-runtime"))
    }

    func testAPILayerUsesGeneratedClientForEveryCompanionSurface() throws {
        let client = try sourceFile(named: "Sources/ColorMatchingLPSAppCore/APIClient.swift")

        XCTAssertTrue(client.contains("import ColorMatchingOpenAPIClient"))
        XCTAssertTrue(client.contains("fetchManifest"))
        XCTAssertTrue(client.contains("fetchRecentSheets"))
        XCTAssertTrue(client.contains("createCapture"))
        XCTAssertTrue(client.contains("uploadMeasurements"))
        XCTAssertTrue(client.contains("uploadJudgments"))
        XCTAssertTrue(client.contains("fetchRankedResults"))
    }

    private func sourceFile(named name: String) throws -> String {
        let testsDirectory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let packageDirectory = testsDirectory
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(contentsOf: packageDirectory.appending(path: name), encoding: .utf8)
    }
}
