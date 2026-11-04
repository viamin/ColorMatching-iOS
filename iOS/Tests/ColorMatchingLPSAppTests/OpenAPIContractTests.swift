import Foundation
import XCTest

final class OpenAPIContractTests: XCTestCase {
    func testVendoredContractContainsEveryConsumedSheetAndCaptureOperation() throws {
        let contractURL = repositoryRoot
            .appending(path: "iOS/Sources/ColorMatchingLPSAppCore/openapi.yaml")

        guard FileManager.default.fileExists(atPath: contractURL.path) else {
            XCTFail("Vendor the published /api/v1 OpenAPI document at \(contractURL.path).")
            return
        }

        let contract = try String(contentsOf: contractURL, encoding: .utf8)
        for path in [
            "/api/v1/test_sheets/recent",
            "/api/v1/test_sheets/{sheet_id}/manifest",
            "/api/v1/test_sheets/{sheet_id}/captures",
            "/api/v1/captures/{capture_id}/measurements",
            "/api/v1/captures/{capture_id}/judgments",
            "/api/v1/test_sheets/{sheet_id}/ranked_results"
        ] {
            XCTAssertTrue(contract.contains(path), "Missing consumed operation: \(path)")
        }
    }

    func testPackageAndAPIClientUseOpenAPIGeneratedTypes() throws {
        let package = try source(at: "iOS/Package.swift")
        XCTAssertTrue(package.contains("swift-openapi-generator"))
        XCTAssertTrue(package.contains("swift-openapi-runtime"))

        let apiClient = try source(at: "iOS/Sources/ColorMatchingLPSAppCore/APIClient.swift")
        XCTAssertTrue(apiClient.contains("import OpenAPIRuntime"))
        XCTAssertFalse(apiClient.contains("struct CaptureMetadata"))
        XCTAssertFalse(apiClient.contains("struct CaptureSessionResponse"))
        XCTAssertFalse(apiClient.contains("struct RecentSheet"))
        XCTAssertFalse(apiClient.contains("struct PairJudgment"))
        XCTAssertFalse(apiClient.contains("struct MeasurementUploadRequest"))
    }

    private var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func source(at path: String) throws -> String {
        try String(contentsOf: repositoryRoot.appending(path: path), encoding: .utf8)
    }
}
