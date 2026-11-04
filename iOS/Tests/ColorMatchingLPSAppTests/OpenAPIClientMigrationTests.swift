import Foundation
import XCTest

final class OpenAPIClientMigrationTests: XCTestCase {
    func testPublishedSpecAndGeneratedClientConfigurationAreCheckedIn() throws {
        let packageDirectory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let packageManifest = try String(contentsOf: packageDirectory.appending(path: "Package.swift"))
        let specURL = packageDirectory.appending(path: "Sources/ColorMatchingLPSAppCore/openapi.json")

        XCTAssertTrue(packageManifest.contains("swift-openapi-generator"), "Add swift-openapi-generator to Package.swift.")
        XCTAssertTrue(packageManifest.contains("swift-openapi-runtime"), "Add swift-openapi-runtime to Package.swift.")
        XCTAssertTrue(FileManager.default.fileExists(atPath: specURL.path), "Vendor the published /api/v1/openapi.json in the API target.")

        guard FileManager.default.fileExists(atPath: specURL.path) else { return }
        let specData = try Data(contentsOf: specURL)
        let spec = try XCTUnwrap(JSONSerialization.jsonObject(with: specData) as? [String: Any])
        let paths = try XCTUnwrap(spec["paths"] as? [String: Any])
        for path in [
            "/api/v1/test_sheets/{sheet_id}/manifest",
            "/api/v1/test_sheets/recent",
            "/api/v1/test_sheets/{sheet_id}/captures",
            "/api/v1/captures/{capture_id}/measurements",
            "/api/v1/captures/{capture_id}/judgments",
            "/api/v1/test_sheets/{sheet_id}/ranked_results"
        ] {
            let operation = try XCTUnwrap(paths[path] as? [String: Any], "Vendored spec must expose \(path).")
            XCTAssertNotNil(operation["get"] ?? operation["post"], "Vendored spec must define an HTTP operation for \(path).")
        }
    }

    func testHandWrittenTransportPayloadModelsAreRemovedFromAPIClient() throws {
        let packageDirectory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(contentsOf: packageDirectory.appending(path: "Sources/ColorMatchingLPSAppCore/APIClient.swift"))

        for model in [
            "CaptureMetadata",
            "WhiteBalanceGains",
            "CaptureSessionResponse",
            "RecentSheet",
            "RecentSheetsResponse",
            "CreateCaptureRequest",
            "MeasurementUploadRequest",
            "MeasurementUpload",
            "MeasurementStatsUpload",
            "JudgmentUploadRequest",
            "PairJudgment"
        ] {
            XCTAssertFalse(source.contains("struct \(model)"), "\(model) must come from the generated OpenAPI client or be an explicit adapter to it.")
        }
    }
}
