import Foundation
import XCTest

/// Checks that the repository carries the machine-readable contract the
/// generated client is built from.
///
/// The OpenAPI document is the drift detector for this app: when the server
/// changes, the vendored document changes, the regenerated client changes, and
/// the app stops compiling until somebody looks at the difference.
final class OpenAPIDocumentTests: XCTestCase {
    func testRepositoryVendorsAnOpenAPIDocumentForTheSurfacesTheAppUses() throws {
        let document = try vendoredDocument()
        let text = try String(contentsOf: document, encoding: .utf8)

        guard document.pathExtension.lowercased() == "json" else {
            for path in Self.requiredPaths {
                XCTAssertTrue(text.contains(path), "The vendored document must describe \(path)")
            }
            return
        }

        let parsed = try JSONSerialization.jsonObject(with: Data(text.utf8))
        let root = try XCTUnwrap(parsed as? [String: Any])
        XCTAssertTrue(
            (root["openapi"] as? String)?.hasPrefix("3.") == true,
            "The vendored document must be an OpenAPI 3 document"
        )
        let paths = try XCTUnwrap(root["paths"] as? [String: Any])
        for path in Self.requiredPaths {
            XCTAssertNotNil(paths[path], "The vendored document must describe \(path)")
        }

        let schemas = try XCTUnwrap((root["components"] as? [String: Any])?["schemas"] as? [String: Any])
        for schema in Self.requiredSchemas {
            XCTAssertNotNil(schemas[schema], "The vendored document must describe the \(schema) schema")
        }
        XCTAssertNotNil(
            schemas.keys.first { $0.contains("Manifest") },
            "The vendored document must describe the sheet manifest schema"
        )
    }

    func testPackageDeclaresTheOpenAPIGeneratorAndRuntimeDependencies() throws {
        let manifest = try String(contentsOf: packageDirectory().appending(path: "Package.swift"), encoding: .utf8)
        XCTAssertTrue(
            manifest.contains("swift-openapi-generator"),
            "The iOS package must depend on swift-openapi-generator"
        )
        XCTAssertTrue(
            manifest.contains("swift-openapi-runtime"),
            "The iOS package must depend on swift-openapi-runtime"
        )
    }

    private static let requiredPaths = [
        "/api/v1/test_sheets/recent",
        "/api/v1/test_sheets/{sheet_id}/manifest",
        "/api/v1/test_sheets/{sheet_id}/ranked_results",
        "/api/v1/test_sheets/{sheet_id}/captures",
        "/api/v1/captures/{capture_id}/measurements",
        "/api/v1/captures/{capture_id}/judgments"
    ]

    private static let requiredSchemas = [
        "CaptureRequest",
        "CaptureCreatedResponse",
        "MeasurementUploadRequest",
        "MeasurementUploadResponse",
        "JudgmentUploadRequest",
        "JudgmentUploadResponse",
        "RecentSheetsResponse",
        "RankedResults"
    ]

    /// The directory that holds the Swift package.
    private func packageDirectory() -> URL {
        repositoryRoot().appending(path: "iOS")
    }

    /// The root of the repository, derived from the location of this test file.
    private func repositoryRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    /// The vendored OpenAPI document, wherever the package keeps it.
    private func vendoredDocument() throws -> URL {
        let names = ["openapi.json", "openapi.yaml", "openapi.yml"]
        let enumerator = FileManager.default.enumerator(
            at: repositoryRoot(),
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )
        let candidates = (enumerator?.allObjects as? [URL] ?? [])
            .filter { names.contains($0.lastPathComponent.lowercased()) }
            .filter { (try? $0.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true }
            .sorted { $0.path < $1.path }
        return try XCTUnwrap(
            candidates.first,
            "Expected an OpenAPI document (openapi.json / openapi.yaml) to be vendored in the repository"
        )
    }
}
