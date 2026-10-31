import Foundation
import XCTest

final class OpenAPIPackageIntegrationTests: XCTestCase {
    func testPackageDependsOnOpenAPIGeneratorAndRuntime() throws {
        let manifest = try loadPackageManifest()
        XCTAssertTrue(
            manifest.contains("swift-openapi-generator"),
            "Package.swift must depend on apple/swift-openapi-generator to produce the typed client at build time"
        )
        XCTAssertTrue(
            manifest.contains("swift-openapi-runtime"),
            "Package.swift must depend on apple/swift-openapi-runtime for the generated client's transport and conversions"
        )
    }

    func testPackageAppliesOpenAPIGeneratorPlugin() throws {
        let manifest = try loadPackageManifest()
        XCTAssertTrue(
            manifest.contains("OpenAPIGeneratorTarget"),
            "The ColorMatchingOpenAPI target must apply the OpenAPIGeneratorTarget build plugin consuming iOS/openapi.yaml"
        )
    }

    func testPackageDeclaresGeneratedClientModule() throws {
        let manifest = try loadPackageManifest()
        XCTAssertTrue(
            manifest.contains("ColorMatchingOpenAPI"),
            "Package.swift must declare the ColorMatchingOpenAPI target that exports the generated client (GeneratedClientTests compiles against this module)"
        )
    }

    func testAppCoreRoutesThroughGeneratedClient() throws {
        let sources = try loadAppCoreSources()
        XCTAssertFalse(
            sources.isEmpty,
            "Expected Swift sources under iOS/Sources/ColorMatchingLPSAppCore"
        )
        XCTAssertTrue(
            sources.contains { $0.contains("import ColorMatchingOpenAPI") },
            "ColorMatchingLPSAppCore must import the generated ColorMatchingOpenAPI client instead of hand-writing Codable request/response models"
        )
    }

    private func loadPackageManifest() throws -> String {
        try String(contentsOf: Self.packageRoot.appendingPathComponent("Package.swift"), encoding: .utf8)
    }

    private func loadAppCoreSources() throws -> [String] {
        let appCoreRoot = Self.packageRoot.appendingPathComponent("Sources/ColorMatchingLPSAppCore")
        guard let enumerator = FileManager.default.enumerator(at: appCoreRoot, includingPropertiesForKeys: nil) else {
            return []
        }
        return try enumerator.compactMap { item -> String? in
            guard let url = item as? URL, url.pathExtension == "swift" else { return nil }
            return try String(contentsOf: url, encoding: .utf8)
        }
    }

    private static var packageRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
