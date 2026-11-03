import Foundation
import XCTest

final class GeneratedOpenAPIClientConfigurationTests: XCTestCase {
    func testPackageDeclaresOpenAPIGeneratorAndRuntime() throws {
        let package = try String(contentsOf: packageRoot.appending(path: "Package.swift"))

        XCTAssertTrue(package.contains("swift-openapi-generator"))
        XCTAssertTrue(package.contains("swift-openapi-runtime"))
        XCTAssertTrue(package.contains(".plugin(name: \"OpenAPIGenerator\""))
    }

    func testAppCoreHasNoHandwrittenTransportModels() throws {
        let sourceDirectory = packageRoot.appending(path: "Sources/ColorMatchingLPSAppCore")
        let source = try swiftSources(in: sourceDirectory).joined(separator: "\n")

        for declaration in [
            "public struct CaptureMetadata",
            "public struct WhiteBalanceGains",
            "public struct CaptureSessionResponse",
            "public struct RecentSheet",
            "public struct PairJudgment"
        ] {
            XCTAssertFalse(source.contains(declaration), "Generated OpenAPI types must replace \(declaration).")
        }
    }

    private var packageRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func swiftSources(in directory: URL) throws -> [String] {
        try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "swift" }
            .map { try String(contentsOf: $0) }
    }
}
