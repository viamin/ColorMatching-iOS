import Foundation
import XCTest

final class OpenAPIClientContractTests: XCTestCase {
    func testPackageDeclaresOpenAPIGeneratorAndRuntimeDependencies() throws {
        let package = try String(contentsOf: workspaceRoot.appending(path: "iOS/Package.swift"))

        XCTAssertTrue(package.contains("swift-openapi-generator"))
        XCTAssertTrue(package.contains("swift-openapi-runtime"))
    }

    func testVendoredOpenAPIContractCoversEveryAppSurface() throws {
        let specification = try XCTUnwrap(vendoredSpecification())
        let document = try JSONSerialization.jsonObject(with: Data(contentsOf: specification))
        let paths = try XCTUnwrap((document as? [String: Any])?["paths"] as? [String: Any])

        for path in [
            "/api/v1/test_sheets/recent",
            "/api/v1/test_sheets/{sheet_id}/manifest",
            "/api/v1/test_sheets/{sheet_id}/captures",
            "/api/v1/captures/{capture_id}/measurements",
            "/api/v1/captures/{capture_id}/judgments",
            "/api/v1/test_sheets/{sheet_id}/ranked_results"
        ] {
            XCTAssertNotNil(paths[path], "Missing OpenAPI path: \(path)")
        }
    }

    private var workspaceRoot: URL {
        var directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        while directory.lastPathComponent != "iOS" {
            directory.deleteLastPathComponent()
        }
        return directory.deletingLastPathComponent()
    }

    private func vendoredSpecification() -> URL? {
        let iOSDirectory = workspaceRoot.appending(path: "iOS")
        let enumerator = FileManager.default.enumerator(
            at: iOSDirectory,
            includingPropertiesForKeys: [.isRegularFileKey]
        )

        return enumerator?
            .compactMap { $0 as? URL }
            .first { url in
                let name = url.lastPathComponent.lowercased()
                return name.contains("openapi") && ["json", "yaml", "yml"].contains(url.pathExtension)
            }
    }
}
