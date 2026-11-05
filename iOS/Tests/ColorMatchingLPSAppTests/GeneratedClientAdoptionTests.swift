import Foundation
import XCTest

final class GeneratedClientAdoptionTests: XCTestCase {
    func testPackageUsesSwiftOpenAPIGeneratorAndRuntime() throws {
        let package = try sourceFile(at: "Package.swift")

        XCTAssertTrue(package.contains("swift-openapi-generator"))
        XCTAssertTrue(package.contains("swift-openapi-runtime"))
    }

    func testAPIClientDoesNotDeclareTransportModelsOwnedByTheOpenAPISpec() throws {
        let client = try sourceFile(at: "Sources/ColorMatchingLPSAppCore/APIClient.swift")

        XCTAssertFalse(client.contains("public struct CaptureMetadata"))
        XCTAssertFalse(client.contains("public struct WhiteBalanceGains"))
        XCTAssertFalse(client.contains("public struct CaptureSessionResponse"))
        XCTAssertFalse(client.contains("public struct RecentSheet"))
        XCTAssertFalse(client.contains("public struct PairJudgment"))
    }

    func testGeneratedClientIncludesEveryCompanionAPIPath() throws {
        let specURL = packageRoot.appendingPathComponent("OpenAPI/color_matching.json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: specURL.path))
        guard FileManager.default.fileExists(atPath: specURL.path) else { return }

        let specData = try Data(contentsOf: specURL)
        let spec = try XCTUnwrap(JSONSerialization.jsonObject(with: specData) as? [String: Any])
        let paths = try XCTUnwrap(spec["paths"] as? [String: Any])

        [
            "/api/v1/test_sheets/{sheet_id}/manifest",
            "/api/v1/test_sheets/recent",
            "/api/v1/test_sheets/{sheet_id}/captures",
            "/api/v1/captures/{capture_id}/measurements",
            "/api/v1/captures/{capture_id}/judgments",
            "/api/v1/test_sheets/{sheet_id}/ranked_results"
        ].forEach { path in
            XCTAssertNotNil(paths[path], "Missing generated operation for \(path)")
        }
    }

    private func sourceFile(at relativePath: String) throws -> String {
        try String(contentsOf: packageRoot.appendingPathComponent(relativePath), encoding: .utf8)
    }

    private var packageRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
