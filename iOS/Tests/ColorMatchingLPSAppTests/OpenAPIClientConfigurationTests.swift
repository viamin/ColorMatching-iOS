import Foundation
import XCTest

final class OpenAPIClientConfigurationTests: XCTestCase {
    func testPackageTracksThePublishedSpecAndOpenAPIClientDependencies() throws {
        let iOSRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let package = try String(contentsOf: iOSRoot.appending(path: "Package.swift"), encoding: .utf8)
        let specificationURL = iOSRoot.appending(path: "Sources/ColorMatchingLPSAppCore/openapi.json")

        XCTAssertTrue(package.contains("swift-openapi-generator"))
        XCTAssertTrue(package.contains("swift-openapi-runtime"))
        XCTAssertTrue(package.contains("OpenAPIGenerator"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: specificationURL.path), "Vendor the published /api/v1/openapi.json document beside the generated client target.")

        guard FileManager.default.fileExists(atPath: specificationURL.path) else { return }
        let specification = try JSONSerialization.jsonObject(with: Data(contentsOf: specificationURL)) as? [String: Any]
        let paths = try XCTUnwrap(specification?["paths"] as? [String: Any])

        XCTAssertEqual(
            Set(paths.keys).intersection([
                "/api/v1/test_sheets/recent",
                "/api/v1/test_sheets/{sheet_id}/manifest",
                "/api/v1/test_sheets/{sheet_id}/captures",
                "/api/v1/captures/{capture_id}/measurements",
                "/api/v1/captures/{capture_id}/judgments",
                "/api/v1/test_sheets/{sheet_id}/ranked_results"
            ]),
            Set([
                "/api/v1/test_sheets/recent",
                "/api/v1/test_sheets/{sheet_id}/manifest",
                "/api/v1/test_sheets/{sheet_id}/captures",
                "/api/v1/captures/{capture_id}/measurements",
                "/api/v1/captures/{capture_id}/judgments",
                "/api/v1/test_sheets/{sheet_id}/ranked_results"
            ])
        )
    }
}
