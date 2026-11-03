import Foundation
import XCTest

final class OpenAPIClientGenerationTests: XCTestCase {
    func testOpenAPIClientGenerationIsConfiguredForEveryUsedSheetAndCaptureOperation() {
        let package = contents(of: "Package.swift")
        XCTAssertTrue(package.contains("swift-openapi-generator"))
        XCTAssertTrue(package.contains("swift-openapi-runtime"))

        let specification = contents(of: "Sources/ColorMatchingLPSAppCore/openapi.yaml")
        [
            "/api/v1/test_sheets/{sheet_id}/manifest",
            "/api/v1/test_sheets/recent",
            "/api/v1/test_sheets/{sheet_id}/captures",
            "/api/v1/captures/{capture_id}/measurements",
            "/api/v1/captures/{capture_id}/judgments",
            "/api/v1/test_sheets/{sheet_id}/ranked_results"
        ].forEach { path in
            XCTAssertTrue(specification.contains(path), "Missing generated-client operation: \(path)")
        }
    }

    func testHandWrittenWireModelsAreReplacedByTheGeneratedClient() {
        let apiClient = contents(of: "Sources/ColorMatchingLPSAppCore/APIClient.swift")
        [
            "public struct CaptureMetadata: Codable",
            "public struct CaptureSessionResponse: Codable",
            "public struct RecentSheet: Codable",
            "private struct MeasurementUploadRequest: Codable",
            "public struct PairJudgment: Codable"
        ].forEach { declaration in
            XCTAssertFalse(apiClient.contains(declaration), "Hand-written API model remains: \(declaration)")
        }
    }

    private func contents(of relativePath: String) -> String {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let url = root.appending(path: relativePath)
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path), "Missing required artifact: \(relativePath)")
        return (try? String(contentsOf: url, encoding: .utf8)) ?? ""
    }
}
