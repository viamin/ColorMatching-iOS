import Foundation
import XCTest

final class OpenAPIClientConfigurationTests: XCTestCase {
    func testGeneratedClientIsConfiguredFromPinnedAPISpecification() throws {
        let packageRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let packageManifest = try String(contentsOf: packageRoot.appending(path: "Package.swift"))
        let specificationURL = packageRoot.appending(path: "OpenAPI/color-matching-api-v1.json")

        XCTAssertTrue(packageManifest.contains("swift-openapi-generator"))
        XCTAssertTrue(packageManifest.contains("swift-openapi-runtime"))
        guard FileManager.default.fileExists(atPath: specificationURL.path) else {
            XCTFail("The pinned OpenAPI document is missing at \(specificationURL.path)")
            return
        }

        let specification = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: Data(contentsOf: specificationURL)) as? [String: Any]
        )
        let paths = try XCTUnwrap(specification["paths"] as? [String: Any])
        XCTAssertEqual(
            Set(paths.keys),
            Set([
                "/api/v1/test_sheets/{sheet_id}/manifest",
                "/api/v1/test_sheets/recent",
                "/api/v1/test_sheets/{sheet_id}/captures",
                "/api/v1/captures/{capture_id}/measurements",
                "/api/v1/captures/{capture_id}/judgments",
                "/api/v1/test_sheets/{sheet_id}/ranked_results"
            ])
        )
    }
}
