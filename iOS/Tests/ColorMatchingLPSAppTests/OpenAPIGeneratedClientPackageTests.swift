import Foundation
import XCTest

/// Pins the package-level deliverables of the generated OpenAPI client (#5):
/// the Swift package must declare the generator, runtime, and URLSession
/// transport dependencies, run the OpenAPIGenerator build plugin, and expose
/// the generated client as a `ColorMatchingOpenAPI` target that downstream
/// targets (and these tests) can import.
///
/// See `docs/openapi-generated-client-test-plan.md` for the vendoring and
/// normalization decisions these tests encode.
final class OpenAPIGeneratedClientPackageTests: XCTestCase {
    func testPackageDeclaresGeneratorRuntimeAndTransportDependencies() throws {
        let manifest = try packageManifest()

        XCTAssertTrue(
            manifest.contains("swift-openapi-generator"),
            "Package.swift must depend on apple/swift-openapi-generator (the OpenAPIGenerator build plugin)."
        )
        XCTAssertTrue(
            manifest.contains("swift-openapi-runtime"),
            "Package.swift must depend on apple/swift-openapi-runtime (generated client support types)."
        )
        XCTAssertTrue(
            manifest.contains("swift-openapi-urlsession"),
            "Package.swift must depend on apple/swift-openapi-urlsession (URLSessionTransport for the generated client)."
        )
    }

    func testPackageDeclaresGeneratedClientTargetAndGeneratorPlugin() throws {
        let manifest = try packageManifest()

        XCTAssertTrue(
            manifest.contains("ColorMatchingOpenAPI"),
            "Package.swift must declare the generated client target/module ColorMatchingOpenAPI so app code can import it."
        )
        XCTAssertTrue(
            manifest.contains("OpenAPIGenerator"),
            "Package.swift must apply the OpenAPIGenerator build plugin to the generated client target."
        )
    }

    func testGeneratedClientTargetIsWiredIntoAppCore() throws {
        let manifest = try packageManifest()

        XCTAssertTrue(
            manifest.range(of: #"target\(\s*name:\s*"ColorMatchingLPSAppCore"[^)]*\bColorMatchingOpenAPI\b"#, options: .regularExpression) != nil,
            "The ColorMatchingLPSAppCore target must depend on ColorMatchingOpenAPI so the hand-written API layer can be replaced by generated types."
        )
    }

    func testGeneratorTargetDeclaresOpenAPIDocumentAndClientConfig() throws {
        let targetRoot = packageRoot.appendingPathComponent("Sources/ColorMatchingOpenAPI")

        XCTAssertTrue(
            FileManager.default.fileExists(atPath: targetRoot.appendingPathComponent("openapi.json").path),
            "The vendored OpenAPI document must live at Sources/ColorMatchingOpenAPI/openapi.json — the file name the OpenAPIGenerator plugin discovers."
        )

        let configURL = targetRoot.appendingPathComponent("openapi-generator-config.yaml")
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: configURL.path),
            "The OpenAPIGenerator plugin requires an openapi-generator-config.yaml in the generated client target."
        )
        if FileManager.default.fileExists(atPath: configURL.path) {
            let config = try String(contentsOf: configURL, encoding: .utf8)
            XCTAssertTrue(
                config.contains("client"),
                "The generator config must generate a client (not only types)."
            )
            XCTAssertTrue(
                config.range(of: #"accessModifier:\s*public"#, options: .regularExpression) != nil,
                "The generator config must set accessModifier: public — the generator defaults to internal, which hides the generated client from the app and test targets."
            )
        }
    }

    private func packageManifest() throws -> String {
        try String(contentsOf: packageRoot.appendingPathComponent("Package.swift"), encoding: .utf8)
    }

    /// Walks up from this test file to the enclosing Swift package root.
    private var packageRoot: URL {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<6 {
            url.deleteLastPathComponent()
            if FileManager.default.fileExists(atPath: url.appendingPathComponent("Package.swift").path) {
                return url
            }
        }
        fatalError("Could not locate the Swift package root above \(#filePath)")
    }
}
