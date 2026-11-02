import Foundation
import XCTest

final class GeneratedClientConfigurationTests: XCTestCase {
    func testPackageDeclaresOpenAPIGeneratorAndRuntime() throws {
        let package = try String(contentsOf: packageURL)

        XCTAssertTrue(package.contains("swift-openapi-generator"))
        XCTAssertTrue(package.contains("swift-openapi-runtime"))
    }

    func testGeneratedClientIncludesEveryCompanionEndpoint() throws {
        let generatedSources = try generatedSourceFiles()
        let clientSource = try generatedSources
            .map { try String(contentsOf: $0) }
            .joined(separator: "\n")

        for endpoint in [
            "/api/v1/test_sheets/{sheet_id}/manifest",
            "/api/v1/test_sheets/recent",
            "/api/v1/test_sheets/{sheet_id}/captures",
            "/api/v1/captures/{capture_id}/measurements",
            "/api/v1/captures/{capture_id}/judgments",
            "/api/v1/test_sheets/{sheet_id}/ranked_results"
        ] {
            XCTAssertTrue(clientSource.contains(endpoint), "Generated client does not include \(endpoint)")
        }
    }

    private var packageURL: URL {
        repositoryRoot.appending(path: "iOS/Package.swift")
    }

    private var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func generatedSourceFiles() throws -> [URL] {
        let sources = repositoryRoot.appending(path: "iOS/Sources")
        let enumerator = FileManager.default.enumerator(at: sources, includingPropertiesForKeys: nil)
        let files = (enumerator?.allObjects as? [URL]) ?? []
        let generated = files.filter { $0.pathExtension == "swift" && $0.path.contains("Generated") }

        XCTAssertFalse(generated.isEmpty, "Run the OpenAPI generator and commit its output under Sources/*/Generated.")
        return generated
    }
}
