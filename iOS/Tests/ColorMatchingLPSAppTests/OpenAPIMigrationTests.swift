import Foundation
import XCTest

final class OpenAPIMigrationTests: XCTestCase {
    func testGeneratedClientPackageAndPluginAreConfigured() throws {
        let package = try source(at: "Package.swift")

        XCTAssertTrue(package.contains("swift-openapi-generator"))
        XCTAssertTrue(package.contains("swift-openapi-runtime"))
        XCTAssertTrue(package.contains("OpenAPIGenerator"))
    }

    func testVendoredSpecificationCoversEveryCompanionSurface() throws {
        let specificationPath = "Sources/ColorMatchingLPSAPI/openapi.yaml"
        let specificationURL = packageRoot.appending(path: specificationPath)
        guard FileManager.default.fileExists(atPath: specificationURL.path) else {
            XCTFail("Missing vendored OpenAPI specification: \(specificationPath)")
            return
        }
        let specification = try String(contentsOf: specificationURL, encoding: .utf8)

        for endpoint in [
            "/api/v1/test_sheets/{sheet_id}/manifest",
            "/api/v1/test_sheets/recent",
            "/api/v1/test_sheets/{sheet_id}/captures",
            "/api/v1/captures/{capture_id}/measurements",
            "/api/v1/captures/{capture_id}/judgments",
            "/api/v1/test_sheets/{sheet_id}/ranked_results"
        ] {
            XCTAssertTrue(specification.contains(endpoint), "Missing OpenAPI endpoint: \(endpoint)")
        }
    }

    func testAPIClientDelegatesToGeneratedClientInsteadOfDeclaringTransportModels() throws {
        let client = try source(at: "Sources/ColorMatchingLPSAppCore/APIClient.swift")

        XCTAssertTrue(client.contains("ColorMatchingLPSAPI"))
        XCTAssertFalse(client.contains("struct CaptureMetadata"))
        XCTAssertFalse(client.contains("struct RecentSheet"))
        XCTAssertFalse(client.contains("struct CaptureSessionResponse"))
    }

    private func source(at relativePath: String) throws -> String {
        try String(contentsOf: packageRoot.appending(path: relativePath), encoding: .utf8)
    }

    private var packageRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
