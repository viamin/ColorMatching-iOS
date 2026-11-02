import Foundation
import XCTest

final class OpenAPISpecCoverageTests: XCTestCase {
    private static let requiredOperations: [(path: String, method: String)] = [
        ("/api/v1/test_sheets/{sheet_id}/manifest", "get"),
        ("/api/v1/test_sheets/recent", "get"),
        ("/api/v1/test_sheets/{sheet_id}/captures", "post"),
        ("/api/v1/captures/{capture_id}/measurements", "post"),
        ("/api/v1/captures/{capture_id}/judgments", "post"),
        ("/api/v1/test_sheets/{sheet_id}/ranked_results", "get"),
    ]

    func testVendoredOpenAPIDocumentExists() {
        let candidates = Self.specCandidates()
        let existing = candidates.filter { FileManager.default.fileExists(atPath: $0.path) }
        XCTAssertTrue(
            !existing.isEmpty,
            "No vendored OpenAPI document found. Expected one of: \(candidates.map(\.path).joined(separator: ", "))"
        )
    }

    func testVendoredSpecIsOpenAPI3AndCoversRequiredOperations() throws {
        let document = try XCTUnwrap(
            Self.vendoredSpecData(),
            "Vendored OpenAPI document is missing; vendor the spec published by viamin/color_matching#110 under iOS/OpenAPI/"
        )
        if Self.vendoredSpecURL()?.pathExtension == "json" {
            try Self.assertJSONSpec(document)
        } else {
            try Self.assertYAMLSpec(document)
        }
    }

    func testPackageDeclaresOpenAPIGeneratorRuntimeAndGeneratedTarget() throws {
        let manifest = try String(contentsOf: Self.packageManifestURL(), encoding: .utf8)
        XCTAssertTrue(
            manifest.contains("swift-openapi-generator"),
            "iOS/Package.swift must depend on apple/swift-openapi-generator"
        )
        XCTAssertTrue(
            manifest.contains("swift-openapi-runtime"),
            "iOS/Package.swift must depend on apple/swift-openapi-runtime"
        )
        XCTAssertTrue(
            manifest.contains("ColorMatchingOpenAPI"),
            "iOS/Package.swift must declare the generated client target ColorMatchingOpenAPI"
        )
    }

    private static func assertJSONSpec(_ data: Data) throws {
        let object = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let version = try XCTUnwrap(object["openapi"] as? String, "Spec is missing the openapi version field")
        XCTAssertTrue(version.hasPrefix("3."), "Expected an OpenAPI 3.x document, found openapi: \(version)")
        let paths = try XCTUnwrap(object["paths"] as? [String: Any], "Spec is missing the paths object")
        for operation in requiredOperations {
            let pathItem = try XCTUnwrap(
                paths[operation.path] as? [String: Any],
                "Spec does not cover required path \(operation.path)"
            )
            XCTAssertNotNil(
                pathItem[operation.method],
                "Spec does not cover required operation \(operation.method.uppercased()) \(operation.path)"
            )
        }
    }

    private static func assertYAMLSpec(_ data: Data) throws {
        let text = try XCTUnwrap(String(data: data, encoding: .utf8))
        XCTAssertTrue(
            text.contains("openapi: 3"),
            "Expected an OpenAPI 3.x document"
        )
        for operation in requiredOperations {
            XCTAssertTrue(
                text.contains(operation.path),
                "Spec does not cover required path \(operation.path)"
            )
        }
    }

    private static func repoRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private static func packageManifestURL() -> URL {
        repoRoot().appendingPathComponent("iOS/Package.swift")
    }

    private static func specCandidates() -> [URL] {
        let directory = repoRoot().appendingPathComponent("iOS/OpenAPI")
        return [
            directory.appendingPathComponent("openapi.json"),
            directory.appendingPathComponent("openapi.yaml"),
            directory.appendingPathComponent("openapi.yml"),
        ]
    }

    private static func vendoredSpecURL() -> URL? {
        specCandidates().first { FileManager.default.fileExists(atPath: $0.path) }
    }

    private static func vendoredSpecData() -> Data? {
        vendoredSpecURL().flatMap { try? Data(contentsOf: $0) }
    }
}
