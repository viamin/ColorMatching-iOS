import Foundation
import XCTest

final class OpenAPIGenerationContractTests: XCTestCase {
    func testPackageDeclaresOpenAPIGeneratorAndRuntime() throws {
        let package = try String(contentsOf: packageRoot.appending(path: "Package.swift"))

        XCTAssertTrue(package.contains("https://github.com/apple/swift-openapi-generator"))
        XCTAssertTrue(package.contains("https://github.com/apple/swift-openapi-runtime"))
        XCTAssertTrue(package.contains("OpenAPIGenerator"))
        XCTAssertTrue(package.contains("OpenAPIRuntime"))
    }

    func testBundledSpecificationCoversEveryAppAPIEndpoint() throws {
        let specification = try String(contentsOf: packageRoot.appending(path: "OpenAPI/color-matching.yaml"))

        [
            "/api/v1/test_sheets/{sheet_id}/manifest",
            "/api/v1/test_sheets/recent",
            "/api/v1/test_sheets/{sheet_id}/captures",
            "/api/v1/captures/{capture_id}/measurements",
            "/api/v1/captures/{capture_id}/judgments",
            "/api/v1/test_sheets/{sheet_id}/ranked_results"
        ].forEach { endpoint in
            XCTAssertTrue(specification.contains(endpoint), "Missing OpenAPI path: \(endpoint)")
        }
    }

    func testAPIClientDoesNotDeclareHandWrittenTransportModels() throws {
        let apiClient = try String(contentsOf: packageRoot.appending(path: "Sources/ColorMatchingLPSAppCore/APIClient.swift"))

        ["CaptureMetadata", "CaptureSessionResponse", "RecentSheet", "PairJudgment"].forEach { type in
            XCTAssertFalse(apiClient.contains("public struct \(type)"), "\(type) must come from the generated OpenAPI client")
        }
    }

    private var packageRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
