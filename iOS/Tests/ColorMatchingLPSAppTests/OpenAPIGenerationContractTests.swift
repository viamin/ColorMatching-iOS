import Foundation
import XCTest

final class OpenAPIGenerationContractTests: XCTestCase {
    func testPackageUsesGeneratedOpenAPIClientInsteadOfHandWrittenTransportModels() {
        let package = sourceFile(at: "Package.swift")
        let client = sourceFile(at: "Sources/ColorMatchingLPSAppCore/APIClient.swift")
        let specification = sourceFile(at: "OpenAPI/color_matching.openapi.json")

        XCTAssertTrue(package.contains("swift-openapi-generator"))
        XCTAssertTrue(package.contains("swift-openapi-runtime"))
        XCTAssertTrue(package.contains("OpenAPIGenerator"))
        XCTAssertFalse(client.contains("public struct CaptureMetadata: Codable"))
        XCTAssertFalse(client.contains("public struct CaptureSessionResponse: Codable"))

        for path in [
            "/api/v1/test_sheets/{sheet_id}/manifest",
            "/api/v1/test_sheets/recent",
            "/api/v1/test_sheets/{sheet_id}/captures",
            "/api/v1/captures/{capture_id}/measurements",
            "/api/v1/captures/{capture_id}/judgments",
            "/api/v1/test_sheets/{sheet_id}/ranked_results"
        ] {
            XCTAssertTrue(specification.contains(path), "Missing OpenAPI path: \(path)")
        }
    }

    private func sourceFile(at relativePath: String) -> String {
        let packageRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return (try? String(contentsOf: packageRoot.appending(path: relativePath), encoding: .utf8)) ?? ""
    }
}
