import Foundation
import XCTest

/// Verifies the Swift package wires in OpenAPI generation (issue #5): the
/// generated client must come from `swift-openapi-generator` running as a build
/// plugin over the vendored spec, linked against `swift-openapi-runtime`.
///
/// These tests fail red until the implementation change set updates the package.
final class OpenAPIPackageWiringTests: XCTestCase {
    func testPackageDeclaresSwiftOpenAPIGeneratorAndRuntime() throws {
        let manifest = try String(contentsOf: Self.packageManifestURL, encoding: .utf8)

        XCTAssertTrue(
            manifest.contains("swift-openapi-generator"),
            "iOS/Package.swift must declare the swift-openapi-generator dependency so the typed client is generated at build time."
        )
        XCTAssertTrue(
            manifest.contains("swift-openapi-runtime"),
            "iOS/Package.swift must declare the swift-openapi-runtime dependency that the generated client links against."
        )
    }

    func testPackageUsesOpenAPIGeneratorBuildPlugin() throws {
        let manifest = try String(contentsOf: Self.packageManifestURL, encoding: .utf8)

        XCTAssertTrue(
            manifest.contains("OpenAPIGenerator"),
            "iOS/Package.swift must attach the OpenAPIGenerator build plugin to the target that owns the generated client, so spec changes regenerate the client on build."
        )
    }
}

private extension OpenAPIPackageWiringTests {
    /// `<repo>/iOS/Tests/ColorMatchingLPSAppTests/ThisFile.swift` → `<repo>/iOS/Package.swift`.
    static var packageManifestURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "Package.swift")
    }
}
