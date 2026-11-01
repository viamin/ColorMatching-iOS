import Foundation
import XCTest

final class OpenAPIClientAdoptionTests: XCTestCase {
    private let requiredOperations = [
        "/api/v1/test_sheets/{sheet_id}/manifest",
        "/api/v1/test_sheets/recent",
        "/api/v1/test_sheets/{sheet_id}/captures",
        "/api/v1/captures/{capture_id}/measurements",
        "/api/v1/captures/{capture_id}/judgments",
        "/api/v1/test_sheets/{sheet_id}/ranked_results"
    ]

    func testPackageDeclaresGeneratedClientDependenciesAndVendoredSpec() throws {
        let package = try contents(at: "Package.swift")

        XCTAssertTrue(package.contains("swift-openapi-generator"))
        XCTAssertTrue(package.contains("swift-openapi-runtime"))
        XCTAssertTrue(fileExists(at: "OpenAPI/color-matching-api.json"))
        XCTAssertTrue(fileExists(at: "OpenAPI/openapi-generator-config.yaml"))
    }

    func testGeneratedClientStubCoverageIncludesEveryConsumedSurface() throws {
        let tests = try contents(at: "Tests/ColorMatchingLPSAppTests/APIClientTests.swift")

        for operation in requiredOperations {
            XCTAssertTrue(tests.contains(operation), "Missing local-stub coverage for \(operation)")
        }
    }

    func testAPIBoundaryUsesGeneratedTypesAndPreservesClientOnlyModels() throws {
        let apiClient = try contents(at: "Sources/ColorMatchingLPSAppCore/APIClient.swift")

        XCTAssertTrue(apiClient.contains("ColorMatchingAPI"))
        XCTAssertFalse(apiClient.contains("public struct CaptureMetadata"))
        XCTAssertFalse(apiClient.contains("public struct CaptureSessionResponse"))
        XCTAssertTrue(apiClient.contains("PatchMeasurement"))
        XCTAssertTrue(apiClient.contains("PairScore"))
    }

    private func contents(at relativePath: String) throws -> String {
        try String(contentsOf: repositoryURL.appending(path: relativePath), encoding: .utf8)
    }

    private func fileExists(at relativePath: String) -> Bool {
        FileManager.default.fileExists(atPath: repositoryURL.appending(path: relativePath).path)
    }

    private var repositoryURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
