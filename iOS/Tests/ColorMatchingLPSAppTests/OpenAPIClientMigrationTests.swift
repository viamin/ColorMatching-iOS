import Foundation
import XCTest

final class OpenAPIClientMigrationTests: XCTestCase {
    func testPackageUsesSwiftOpenAPIToolchain() throws {
        let package = try String(contentsOf: iOSDirectory.appending(path: "Package.swift"), encoding: .utf8)

        XCTAssertTrue(package.contains("swift-openapi-generator"))
        XCTAssertTrue(package.contains("swift-openapi-runtime"))
    }

    func testVendoredOpenAPISpecCoversEveryCompanionEndpoint() throws {
        let specification = try XCTUnwrap(vendoredOpenAPISpec())
        let paths = try XCTUnwrap(specification["paths"] as? [String: Any])

        [
            "/api/v1/test_sheets/recent",
            "/api/v1/test_sheets/{sheet_id}/manifest",
            "/api/v1/test_sheets/{sheet_id}/captures",
            "/api/v1/captures/{capture_id}/measurements",
            "/api/v1/captures/{capture_id}/judgments",
            "/api/v1/test_sheets/{sheet_id}/ranked_results"
        ].forEach { XCTAssertNotNil(paths[$0], "Missing \($0) from vendored OpenAPI spec") }
    }

    func testHandWrittenTransportDTOsAreRemoved() throws {
        let source = try String(
            contentsOf: iOSDirectory.appending(path: "Sources/ColorMatchingLPSAppCore/APIClient.swift"),
            encoding: .utf8
        )

        ["CaptureMetadata", "WhiteBalanceGains", "CaptureSessionResponse", "RecentSheet", "PairJudgment"]
            .forEach { XCTAssertFalse(source.contains("struct \($0)"), "\($0) must come from the generated client") }
    }

    private var iOSDirectory: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func vendoredOpenAPISpec() throws -> [String: Any]? {
        guard let enumerator = FileManager.default.enumerator(
            at: iOSDirectory,
            includingPropertiesForKeys: nil
        ) else {
            return nil
        }
        let candidates = enumerator
            .compactMap { $0 as? URL }
            .filter { $0.lastPathComponent.lowercased().contains("openapi") && $0.pathExtension == "json" }

        guard let specificationURL = candidates.first else { return nil }
        let data = try Data(contentsOf: specificationURL)
        return try JSONSerialization.jsonObject(with: data) as? [String: Any]
    }
}
