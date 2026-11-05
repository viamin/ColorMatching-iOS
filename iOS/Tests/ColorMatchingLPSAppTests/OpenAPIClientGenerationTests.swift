import Foundation
import XCTest

final class OpenAPIClientGenerationTests: XCTestCase {
    private let requiredOperations = [
        ("/api/v1/test_sheets/{sheet_id}/manifest", "get"),
        ("/api/v1/test_sheets/recent", "get"),
        ("/api/v1/test_sheets/{sheet_id}/captures", "post"),
        ("/api/v1/captures/{capture_id}/measurements", "post"),
        ("/api/v1/captures/{capture_id}/judgments", "post"),
        ("/api/v1/test_sheets/{sheet_id}/ranked_results", "get")
    ]

    func testPackageWiresTheOpenAPIGeneratorAndRuntime() throws {
        let package = try String(contentsOf: repositoryRoot.appending(path: "iOS/Package.swift"))

        XCTAssertTrue(package.contains("swift-openapi-generator"))
        XCTAssertTrue(package.contains("swift-openapi-runtime"))
        XCTAssertTrue(package.contains("OpenAPIGenerator"))
    }

    func testVendoredUpstreamSpecDefinesEveryCompanionOperation() throws {
        let data = try Data(contentsOf: vendoredSpecURL)
        let document = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let paths = try XCTUnwrap(document["paths"] as? [String: Any])

        for (path, method) in requiredOperations {
            let operations = try XCTUnwrap(paths[path] as? [String: Any], "Missing \(path) in the vendored OpenAPI document")
            XCTAssertNotNil(operations[method], "Missing \(method.uppercased()) \(path) in the vendored OpenAPI document")
        }
    }

    func testHandWrittenTransportModelsAreRemovedAfterGeneration() throws {
        let apiClient = try String(contentsOf: repositoryRoot.appending(path: "iOS/Sources/ColorMatchingLPSAppCore/APIClient.swift"))

        for handwrittenModel in [
            "public struct CaptureMetadata",
            "public struct WhiteBalanceGains",
            "public struct CaptureSessionResponse",
            "public struct RecentSheet",
            "public struct PairJudgment",
            "private struct RecentSheetsResponse",
            "private struct CreateCaptureRequest",
            "private struct MeasurementUploadRequest",
            "private struct JudgmentUploadRequest"
        ] {
            XCTAssertFalse(apiClient.contains(handwrittenModel), "Generated OpenAPI types must replace \(handwrittenModel)")
        }
    }

    private var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private var vendoredSpecURL: URL {
        repositoryRoot.appending(path: "iOS/Sources/ColorMatchingLPSAppCore/openapi.json")
    }
}
