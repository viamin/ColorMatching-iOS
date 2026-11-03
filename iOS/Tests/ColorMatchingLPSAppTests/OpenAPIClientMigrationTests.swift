import Foundation
import XCTest

final class OpenAPIClientMigrationTests: XCTestCase {
    func testPackageDeclaresOpenAPIGeneratorAndRuntime() throws {
        let package = try String(contentsOf: packageRoot.appending(path: "Package.swift"), encoding: .utf8)

        XCTAssertTrue(package.contains("swift-openapi-generator"))
        XCTAssertTrue(package.contains("swift-openapi-runtime"))
        XCTAssertTrue(package.contains("OpenAPIGenerator"))
    }

    func testVendoredSpecificationDeclaresEveryCompanionOperation() throws {
        let specification = try XCTUnwrap(vendoredOpenAPISpecification())

        for path in [
            "/api/v1/test_sheets/{sheet_id}/manifest",
            "/api/v1/test_sheets/recent",
            "/api/v1/test_sheets/{sheet_id}/captures",
            "/api/v1/captures/{capture_id}/measurements",
            "/api/v1/captures/{capture_id}/judgments",
            "/api/v1/test_sheets/{sheet_id}/ranked_results"
        ] {
            XCTAssertTrue(specification.contains(path), "Missing OpenAPI path: \(path)")
        }
    }

    func testGeneratedSourceUsesOpenAPIRuntime() throws {
        let sourceFiles = try FileManager.default.contentsOfDirectory(
            at: packageRoot.appending(path: "Sources"),
            includingPropertiesForKeys: nil
        )
        let source = try sourceFiles
            .flatMap(recursiveSwiftFiles)
            .map { try String(contentsOf: $0, encoding: .utf8) }
            .joined(separator: "\n")

        XCTAssertTrue(source.contains("import OpenAPIRuntime"))
    }

    private var packageRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func vendoredOpenAPISpecification() -> String? {
        let candidates = recursiveFiles(at: packageRoot)
            .filter { ["json", "yaml", "yml"].contains($0.pathExtension) }

        return candidates.lazy.compactMap { try? String(contentsOf: $0, encoding: .utf8) }
            .first { $0.contains("openapi:") || $0.contains("\"openapi\"") }
    }

    private func recursiveSwiftFiles(at url: URL) -> [URL] {
        recursiveFiles(at: url).filter { $0.pathExtension == "swift" }
    }

    private func recursiveFiles(at url: URL) -> [URL] {
        let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.isRegularFileKey]
        )

        return (enumerator?.allObjects as? [URL] ?? []).filter { url in
            (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true
        }
    }
}
