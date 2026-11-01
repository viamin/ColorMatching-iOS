import Foundation
import XCTest

/// Pins the iOS package manifest wiring required to build the generated
/// OpenAPI client (issue #5): swift-openapi-generator plugin, swift-openapi-runtime,
/// a `GeneratedAPIClient` target consumed by the app core, and a
/// `GeneratedClientTests` target that compiles the stubbed-response suite in
/// `iOS/Tests/GeneratedClientTests/`.
final class OpenAPIPackageWiringTests: XCTestCase {
    private static let packageRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    private static var manifestURL: URL {
        packageRoot.appendingPathComponent("Package.swift")
    }

    func testPackageDeclaresOpenAPIGeneratorAndRuntimeDependencies() throws {
        let source = try manifestSource()
        XCTAssertTrue(
            source.contains("swift-openapi-generator"),
            "Add the swift-openapi-generator package dependency (provides the OpenAPIGenerator build plugin)."
        )
        XCTAssertTrue(
            source.contains("swift-openapi-runtime"),
            "Add the swift-openapi-runtime package dependency (provides the OpenAPIRuntime library)."
        )
    }

    func testGeneratedClientTargetUsesGeneratorPluginAndRuntime() throws {
        let source = try manifestSource()
        let block = try targetBlock(named: "GeneratedAPIClient", in: source)
        XCTAssertTrue(
            block.contains("OpenAPIGenerator"),
            "GeneratedAPIClient must apply the OpenAPIGenerator build plugin over iOS/OpenAPI/color-matching-openapi.json."
        )
        XCTAssertTrue(
            block.contains("OpenAPIRuntime"),
            "GeneratedAPIClient must link OpenAPIRuntime."
        )
    }

    func testAppCoreConsumesGeneratedClient() throws {
        let source = try manifestSource()
        let block = try targetBlock(named: "ColorMatchingLPSAppCore", in: source)
        XCTAssertTrue(
            block.contains("GeneratedAPIClient"),
            "ColorMatchingLPSAppCore must depend on GeneratedAPIClient so the app core calls generated types."
        )
    }

    func testStubbedResponseSuiteIsWiredAsTestTarget() throws {
        let source = try manifestSource()
        let block = try targetBlock(named: "GeneratedClientTests", in: source)
        XCTAssertTrue(
            block.contains("GeneratedAPIClient"),
            "Declare testTarget GeneratedClientTests depending on GeneratedAPIClient so the stubbed-response "
                + "suite at iOS/Tests/GeneratedClientTests/ compiles and runs."
        )
    }

    private func manifestSource() throws -> String {
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: Self.manifestURL.path),
            "iOS/Package.swift must exist next to the package root."
        )
        return try String(contentsOf: Self.manifestURL, encoding: .utf8)
    }

    private func targetBlock(named targetName: String, in source: String) throws -> String {
        try XCTUnwrap(
            targetBlocks(in: source).first { $0.contains("name: \"\(targetName)\"") },
            "Declare target '\(targetName)' in iOS/Package.swift."
        )
    }

    private func targetBlocks(in source: String) -> [String] {
        var blocks: [String] = []
        var searchStart = source.startIndex
        while let markerRange = source.range(of: "arget(", range: searchStart..<source.endIndex) {
            let openParen = source.index(before: markerRange.upperBound)
            var index = source.index(after: openParen)
            var depth = 1
            while index < source.endIndex, depth > 0 {
                let character = source[index]
                if character == "(" { depth += 1 }
                if character == ")" { depth -= 1 }
                index = source.index(after: index)
            }
            blocks.append(String(source[source.index(after: openParen)..<source.index(before: index)]))
            searchStart = index
        }
        return blocks
    }
}
