import Foundation
import XCTest

final class GeneratedOpenAPIClientAcceptanceTests: XCTestCase {
    func testPackageDeclaresOpenAPIGeneratorAndRuntime() throws {
        let package = try String(contentsOf: packageRoot.appending(path: "Package.swift"))

        XCTAssertTrue(package.contains("swift-openapi-generator"))
        XCTAssertTrue(package.contains("swift-openapi-runtime"))
        XCTAssertTrue(package.contains("OpenAPIGenerator"))
    }

    func testClientNoLongerDefinesServerContractModelsByHand() throws {
        let client = try String(contentsOf: packageRoot.appending(path: "Sources/ColorMatchingLPSAppCore/APIClient.swift"))

        for model in ["CaptureMetadata", "WhiteBalanceGains", "CaptureSessionResponse", "RecentSheet", "PairJudgment"] {
            XCTAssertFalse(client.contains("public struct \(model)"), "\(model) must be generated from OpenAPI")
        }
    }

    func testClientIncludesEveryCompanionAPISurface() throws {
        let client = try String(contentsOf: packageRoot.appending(path: "Sources/ColorMatchingLPSAppCore/APIClient.swift"))

        for path in [
            "test_sheets/recent",
            "test_sheets/\\(sheetCode)/manifest",
            "test_sheets/\\(sheetID)/captures",
            "captures/\\(captureID)/measurements",
            "captures/\\(captureID)/judgments",
            "ranked_results"
        ] {
            XCTAssertTrue(client.contains(path), "Missing OpenAPI-backed surface: \(path)")
        }
    }

    private var packageRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
