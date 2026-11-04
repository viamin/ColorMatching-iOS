import Foundation
import XCTest

final class GeneratedClientConfigurationTests: XCTestCase {
    func testPackageConfiguresOpenAPIGenerationAndChecksInItsClient() throws {
        let iOSDirectory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let packageManifest = try String(contentsOf: iOSDirectory.appending(path: "Package.swift"))
        let generatedClient = iOSDirectory
            .appending(path: "Sources/ColorMatchingLPSAppCore/Generated/Client.swift")

        XCTAssertTrue(packageManifest.contains("swift-openapi-generator"))
        XCTAssertTrue(packageManifest.contains("swift-openapi-runtime"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: generatedClient.path))
    }
}
