import Foundation
import XCTest

final class OpenAPIClientMigrationTests: XCTestCase {
    func testPackageDeclaresOpenAPIGeneratorAndRuntime() throws {
        let package = try String(contentsOf: appRoot.appending(path: "Package.swift"), encoding: .utf8)

        XCTAssertTrue(package.contains("swift-openapi-generator"))
        XCTAssertTrue(package.contains("swift-openapi-runtime"))
    }

    func testVendoredSpecDocumentsEveryAppEndpoint() throws {
        let spec = try openAPISpec()

        for endpoint in [
            "/api/v1/test_sheets/{sheet_id}/manifest",
            "/api/v1/test_sheets/recent",
            "/api/v1/test_sheets/{sheet_id}/captures",
            "/api/v1/captures/{capture_id}/measurements",
            "/api/v1/captures/{capture_id}/judgments",
            "/api/v1/test_sheets/{sheet_id}/ranked_results"
        ] {
            XCTAssertNotNil(spec[endpoint], "Missing \(endpoint) from the vendored OpenAPI snapshot")
        }
    }

    func testGeneratedClientReplacesHandWrittenTransportModels() throws {
        let source = try String(
            contentsOf: appRoot.appending(path: "Sources/ColorMatchingLPSAppCore/APIClient.swift"),
            encoding: .utf8
        )

        for model in [
            "RecentSheetsResponse",
            "CreateCaptureRequest",
            "MeasurementUploadRequest",
            "MeasurementUpload",
            "MeasurementStatsUpload",
            "JudgmentUploadRequest"
        ] {
            XCTAssertFalse(source.contains("struct \(model): Codable"), "\(model) must come from the generated client")
        }
    }

    private var appRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func openAPISpec() throws -> [String: [String: Any]] {
        let data = try Data(contentsOf: appRoot.appending(path: "OpenAPI/color-matching.json"))
        let document = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        return try XCTUnwrap(document["paths"] as? [String: [String: Any]])
    }
}
