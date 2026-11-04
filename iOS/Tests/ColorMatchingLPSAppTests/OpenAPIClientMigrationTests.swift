import Foundation
import XCTest

final class OpenAPIClientMigrationTests: XCTestCase {
    func testPackageAndVendoredContractSupportAllConsumerOperations() throws {
        let packageRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let packageManifest = try String(contentsOf: packageRoot.appending(path: "Package.swift"))
        let contractURL = packageRoot.appending(path: "OpenAPI/color-matching.openapi.json")

        XCTAssertTrue(packageManifest.contains("swift-openapi-generator"))
        XCTAssertTrue(packageManifest.contains("swift-openapi-runtime"))

        let data = try Data(contentsOf: contractURL)
        let document = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let paths = try XCTUnwrap(document["paths"] as? [String: Any])

        [
            "/api/v1/test_sheets/{sheet_id}/manifest",
            "/api/v1/test_sheets/recent",
            "/api/v1/test_sheets/{sheet_id}/captures",
            "/api/v1/captures/{capture_id}/measurements",
            "/api/v1/captures/{capture_id}/judgments",
            "/api/v1/test_sheets/{sheet_id}/ranked_results"
        ].forEach { path in
            XCTAssertNotNil(paths[path], "Missing OpenAPI operation for \(path)")
        }
    }
}
