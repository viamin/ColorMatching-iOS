import XCTest

final class OpenAPIPackageWiringTests: XCTestCase {
    func testPackageManifestUsesOpenAPIGeneratorPlugin() throws {
        let manifest = try Self.packageManifest()
        XCTAssertTrue(
            manifest.contains("swift-openapi-generator"),
            "Package.swift must depend on apple/swift-openapi-generator"
        )
        XCTAssertTrue(
            manifest.contains("OpenAPIGeneratorPlugin"),
            "Package.swift must apply the OpenAPIGeneratorPlugin build plugin to the generated client target"
        )
    }

    func testPackageManifestLinksOpenAPIRuntime() throws {
        let manifest = try Self.packageManifest()
        XCTAssertTrue(
            manifest.contains("swift-openapi-runtime"),
            "Package.swift must link swift-openapi-runtime for the generated client"
        )
    }

    private static func packageManifest() throws -> String {
        let packageRoot = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(contentsOf: packageRoot.appendingPathComponent("Package.swift"), encoding: .utf8)
    }
}
