import Foundation
import XCTest

final class OpenAPIClientConfigurationTests: XCTestCase {
    func testVendoredSpecAndGeneratorConfigurationCoverEveryConsumedOperation() throws {
        let package = try String(contentsOf: repositoryRoot.appending(path: "iOS/Package.swift"))
        let specURL = repositoryRoot.appending(path: "iOS/Sources/ColorMatchingLPSAppCore/openapi.yaml")
        let spec = try String(contentsOf: specURL)
        let apiLayer = try String(contentsOf: repositoryRoot.appending(path: "iOS/Sources/ColorMatchingLPSAppCore/APIClient.swift"))

        XCTAssertTrue(package.contains("swift-openapi-generator"))
        XCTAssertTrue(package.contains("swift-openapi-runtime"))
        XCTAssertTrue(package.contains("OpenAPIGenerator"))
        XCTAssertTrue(package.contains("OpenAPIRuntime"))

        [
            "/api/v1/test_sheets/{sheet_id}/manifest",
            "/api/v1/test_sheets/recent",
            "/api/v1/test_sheets/{sheet_id}/captures",
            "/api/v1/captures/{capture_id}/measurements",
            "/api/v1/captures/{capture_id}/judgments",
            "/api/v1/test_sheets/{sheet_id}/ranked_results"
        ].forEach { path in
            XCTAssertTrue(spec.contains(path), "Missing consumed operation: \(path)")
        }

        ["CaptureMetadata", "WhiteBalanceGains", "CaptureSessionResponse", "RecentSheet"].forEach { model in
            XCTAssertFalse(apiLayer.contains("public struct \(model)"), "Handwritten API model remains: \(model)")
        }
    }

    private var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
