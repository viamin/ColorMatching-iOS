import Foundation
import XCTest

/// Verifies the SwiftPM wiring required by issue #5: the package must depend
/// on `swift-openapi-generator` + `swift-openapi-runtime`, expose a generated
/// client target (`OpenAPIClient`) driven by a vendored OpenAPI document, and
/// make both the generated client and the runtime importable from tests.
///
/// These tests FAIL until the implementation lands (see
/// `docs/openapi-generated-client-plan.md` for the exact wiring contract).
final class OpenAPIClientPackageTests: XCTestCase {
    func testPackageWiresGeneratorPluginAndRuntime() throws {
        let manifest = try packageManifestSource()

        XCTAssertTrue(
            manifest.contains("swift-openapi-generator"),
            "Package.swift must depend on apple/swift-openapi-generator"
        )
        XCTAssertTrue(
            manifest.contains("swift-openapi-runtime"),
            "Package.swift must depend on apple/swift-openapi-runtime"
        )
        XCTAssertTrue(
            manifest.contains("OpenAPIGenerator"),
            "The OpenAPIClient target must apply the OpenAPIGenerator build plugin"
        )
        XCTAssertTrue(
            manifest.contains("OpenAPIRuntime"),
            "Targets must depend on the OpenAPIRuntime product"
        )
    }

    func testPackageDeclaresGeneratedClientTargetUsableFromTests() throws {
        let manifest = try packageManifestSource()

        XCTAssertTrue(
            manifest.contains("OpenAPIClient"),
            "Package.swift must declare the OpenAPIClient generated-client target"
        )
        let testsSection = manifest.range(of: "ColorMatchingLPSAppTests").map { testsRange in
            String(manifest[testsRange.lowerBound..<manifest.endIndex])
        }
        XCTAssertNotNil(testsSection, "Package.swift must declare the ColorMatchingLPSAppTests test target")
        XCTAssertTrue(
            (testsSection ?? "").contains("OpenAPIClient"),
            "The ColorMatchingLPSAppTests target must depend on OpenAPIClient so the generated types are importable in tests"
        )
    }

    func testGeneratedClientTargetVendorsSpecAndGeneratorConfig() throws {
        let targetDirectory = try openAPIClientTargetDirectory()

        let specURL = targetDirectory.appendingPathComponent("openapi.json")
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: specURL.path),
            "Vendored OpenAPI document missing at iOS/Sources/OpenAPIClient/openapi.json"
        )

        let config = try String(
            contentsOf: targetDirectory.appendingPathComponent("openapi-generator-config.yaml"),
            encoding: .utf8
        )
        XCTAssertTrue(
            config.contains("mode: client"),
            "openapi-generator-config.yaml must set 'mode: client'"
        )
        XCTAssertTrue(
            config.contains("accessModifier: public"),
            "openapi-generator-config.yaml must set 'accessModifier: public' so tests can import the generated types without @testable"
        )
    }

    // MARK: - Helpers

    private func packageManifestSource() throws -> String {
        try String(contentsOf: packageRoot().appendingPathComponent("Package.swift"), encoding: .utf8)
    }

    private func openAPIClientTargetDirectory() throws -> URL {
        packageRoot().appendingPathComponent("Sources/OpenAPIClient")
    }

    private func packageRoot() -> URL {
        var directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        for _ in 0..<8 {
            if FileManager.default.fileExists(atPath: directory.appendingPathComponent("Package.swift").path) {
                return directory
            }
            directory.deleteLastPathComponent()
        }
        return directory
    }
}
