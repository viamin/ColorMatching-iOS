import Foundation
import XCTest

final class GeneratedOpenAPIConfigurationTests: XCTestCase {
    func testPackageDeclaresGeneratedClientDependenciesAndV1Specification() throws {
        let iosDirectory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let package = try String(contentsOf: iosDirectory.appending(path: "Package.swift"), encoding: .utf8)
        let specification = try XCTUnwrap(
            try specificationURL(in: iosDirectory),
            "A vendored OpenAPI v1 specification is required so generated-client changes are reviewable."
        )
        let specificationText = try String(contentsOf: specification, encoding: .utf8)

        XCTAssertTrue(package.contains("swift-openapi-generator"))
        XCTAssertTrue(package.contains("swift-openapi-runtime"))
        XCTAssertTrue(specificationText.contains("/api/v1/test_sheets/{sheet_id}/manifest"))
        XCTAssertTrue(specificationText.contains("/api/v1/test_sheets/recent"))
        XCTAssertTrue(specificationText.contains("/api/v1/test_sheets/{sheet_id}/captures"))
        XCTAssertTrue(specificationText.contains("/api/v1/captures/{capture_id}/measurements"))
        XCTAssertTrue(specificationText.contains("/api/v1/captures/{capture_id}/judgments"))
        XCTAssertTrue(specificationText.contains("/api/v1/test_sheets/{sheet_id}/ranked_results"))
    }

    private func specificationURL(in iosDirectory: URL) throws -> URL? {
        let candidates = FileManager.default.enumerator(
            at: iosDirectory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        return candidates?.compactMap { $0 as? URL }.first { url in
            ["yaml", "yml", "json"].contains(url.pathExtension.lowercased())
                && url.lastPathComponent.lowercased().contains("openapi")
        }
    }
}
