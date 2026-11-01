import Foundation
import XCTest

final class OpenAPIClientGenerationTests: XCTestCase {
    func testPackageWiresOpenAPIRuntimeAndGenerator() throws {
        let package = try source(at: "Package.swift")

        XCTAssertTrue(package.contains("swift-openapi-generator"))
        XCTAssertTrue(package.contains("swift-openapi-runtime"))
    }

    func testVendoredSpecificationCoversEveryCompanionAPISurface() throws {
        let specification = try vendoredSpecification()

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

    func testHandWrittenTransportModelsAreRemovedAfterGeneration() throws {
        let apiClient = try source(at: "Sources/ColorMatchingLPSAppCore/APIClient.swift")

        for type in [
            "CaptureMetadata",
            "WhiteBalanceGains",
            "CaptureSessionResponse",
            "RecentSheet",
            "MeasurementUploadRequest",
            "MeasurementUpload",
            "MeasurementStatsUpload",
            "JudgmentUploadRequest",
            "PairJudgment"
        ] {
            XCTAssertFalse(apiClient.contains("struct \(type)"), "Hand-written API type remains: \(type)")
        }
    }

    private func vendoredSpecification() throws -> String {
        let openAPI = packageRoot.appending(path: "OpenAPI")
        guard FileManager.default.fileExists(atPath: openAPI.path) else {
            XCTFail("A vendored OpenAPI document is required")
            return ""
        }
        let candidates = try FileManager.default.contentsOfDirectory(
            at: openAPI,
            includingPropertiesForKeys: nil
        )
        .filter { ["json", "yaml", "yml"].contains($0.pathExtension.lowercased()) }

        return try XCTUnwrap(candidates.first, "A vendored OpenAPI document is required")
            .contentsOfString()
    }

    private func source(at relativePath: String) throws -> String {
        try packageRoot.appending(path: relativePath).contentsOfString()
    }

    private var packageRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}

private extension URL {
    func contentsOfString() throws -> String {
        try String(contentsOf: self, encoding: .utf8)
    }
}
