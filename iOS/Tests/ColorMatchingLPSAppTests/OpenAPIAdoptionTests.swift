import Foundation
import XCTest

final class OpenAPIAdoptionTests: XCTestCase {
    func testPackageDeclaresGeneratorAndRuntimeDependencies() throws {
        let package = try String(contentsOf: packageURL, encoding: .utf8)

        XCTAssertTrue(package.contains("swift-openapi-generator"))
        XCTAssertTrue(package.contains("swift-openapi-runtime"))
    }

    func testVendoredSpecificationCoversEveryCompanionSurface() throws {
        XCTAssertTrue(FileManager.default.fileExists(atPath: specificationURL.path))
        guard FileManager.default.fileExists(atPath: specificationURL.path) else { return }

        let specification = try String(contentsOf: specificationURL, encoding: .utf8)

        [
            "/api/v1/test_sheets/{sheet_id}/manifest",
            "/api/v1/test_sheets/recent",
            "/api/v1/test_sheets/{sheet_id}/captures",
            "/api/v1/captures/{capture_id}/measurements",
            "/api/v1/captures/{capture_id}/judgments",
            "/api/v1/test_sheets/{sheet_id}/ranked_results"
        ].forEach { path in
            XCTAssertTrue(specification.contains(path), "Missing OpenAPI path: \(path)")
        }
    }

    func testAppCoreExposesGeneratedClientSupportForRankedResults() throws {
        let apiClient = try String(contentsOf: apiClientURL, encoding: .utf8)

        XCTAssertTrue(apiClient.contains("fetchRankedResults"))
        XCTAssertTrue(apiClient.contains("Client"))
    }

    private var packageURL: URL {
        repositoryRoot.appending(path: "iOS/Package.swift")
    }

    private var specificationURL: URL {
        repositoryRoot.appending(path: "iOS/OpenAPI/color_matching.json")
    }

    private var apiClientURL: URL {
        repositoryRoot.appending(path: "iOS/Sources/ColorMatchingLPSAppCore/APIClient.swift")
    }

    private var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
