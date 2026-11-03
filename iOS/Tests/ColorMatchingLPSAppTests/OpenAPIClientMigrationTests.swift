import Foundation
import XCTest

final class OpenAPIClientMigrationTests: XCTestCase {
    func testPackageConfiguresGeneratedClientDependencies() throws {
        let package = try source(at: "Package.swift")

        XCTAssertTrue(package.contains("swift-openapi-generator"))
        XCTAssertTrue(package.contains("swift-openapi-runtime"))
        XCTAssertTrue(package.contains("OpenAPIGenerator"))
        XCTAssertTrue(package.contains("OpenAPIRuntime"))
    }

    func testVendoredSpecDefinesEveryAppOperation() throws {
        let specData = try Data(contentsOf: iOSRoot.appending(path: "Sources/ColorMatchingAPI/openapi.json"))
        let document = try XCTUnwrap(JSONSerialization.jsonObject(with: specData) as? [String: Any])
        let paths = try XCTUnwrap(document["paths"] as? [String: Any])

        XCTAssertNotNil(paths["/api/v1/test_sheets/{sheet_id}/manifest"])
        XCTAssertNotNil(paths["/api/v1/test_sheets/recent"])
        XCTAssertNotNil(paths["/api/v1/test_sheets/{sheet_id}/captures"])
        XCTAssertNotNil(paths["/api/v1/captures/{capture_id}/measurements"])
        XCTAssertNotNil(paths["/api/v1/captures/{capture_id}/judgments"])
        XCTAssertNotNil(paths["/api/v1/test_sheets/{sheet_id}/ranked_results"])
    }

    func testTransportDoesNotDeclareServerOwnedModels() throws {
        let transport = try source(at: "Sources/ColorMatchingLPSAppCore/APIClient.swift")

        ["CaptureMetadata", "WhiteBalanceGains", "CaptureSessionResponse", "RecentSheet", "PairJudgment"].forEach {
            XCTAssertFalse(transport.contains("struct \($0)"), "\($0) must be generated from OpenAPI")
        }
    }

    private var iOSRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func source(at relativePath: String) throws -> String {
        try String(contentsOf: iOSRoot.appending(path: relativePath), encoding: .utf8)
    }
}
