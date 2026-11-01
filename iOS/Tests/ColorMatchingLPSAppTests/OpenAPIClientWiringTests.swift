import Foundation
import XCTest

final class OpenAPIClientWiringTests: XCTestCase {
    private static let packageRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    func testPackageManifestDeclaresOpenAPIGeneratorAndRuntime() throws {
        let manifest = try Self.contents(of: "Package.swift")
        let required = [
            "swift-openapi-generator",
            "swift-openapi-runtime",
            "OpenAPIGenerator",
            "OpenAPIRuntime"
        ]

        for needle in required {
            XCTAssertTrue(
                manifest.contains(needle),
                "iOS/Package.swift must reference \(needle) (issue #5: generated OpenAPI client)"
            )
        }
    }

    func testPackageManifestDeclaresGeneratedClientTarget() throws {
        let manifest = try Self.contents(of: "Package.swift")
        XCTAssertTrue(
            manifest.contains("ColorMatchingOpenAPI"),
            "iOS/Package.swift must declare the ColorMatchingOpenAPI target that hosts openapi.yaml and the generator plugin"
        )
    }

    func testAppCoreImportsGeneratedClient() throws {
        let sources = try Self.appCoreSources()
        XCTAssertTrue(
            sources.contains { $0.contains("import ColorMatchingOpenAPI") },
            "Sources/ColorMatchingLPSAppCore must call the generated client instead of hand-building requests"
        )
    }

    func testAppCoreNoLongerHandCodesWirePayloads() throws {
        let joined = try Self.appCoreSources().joined()
        let forbidden = ["CodingKeys", "JSONEncoder", "JSONDecoder"]

        for needle in forbidden {
            XCTAssertFalse(
                joined.contains(needle),
                "Sources/ColorMatchingLPSAppCore still hand-codes wire payloads (\(needle)); wire coding must live in the generated ColorMatchingOpenAPI types (issue #5)"
            )
        }
    }

    func testAppCoreExposesRankedResultsSurface() throws {
        let joined = try Self.appCoreSources().joined().lowercased()
        XCTAssertTrue(
            joined.contains("ranked_results") || joined.contains("rankedresults"),
            "Sources/ColorMatchingLPSAppCore must surface the ranked-results operation to the app"
        )
    }

    private static func contents(of relativePath: String) throws -> String {
        let url = packageRoot.appendingPathComponent(relativePath)
        return try String(contentsOf: url, encoding: .utf8)
    }

    private static func appCoreSources() throws -> [String] {
        let directory = packageRoot.appendingPathComponent("Sources/ColorMatchingLPSAppCore")
        let files = try FileManager.default.contentsOfDirectory(atPath: directory.path)
            .filter { $0.hasSuffix(".swift") }
            .sorted()
        return try files.map { try String(contentsOf: directory.appendingPathComponent($0), encoding: .utf8) }
    }
}
