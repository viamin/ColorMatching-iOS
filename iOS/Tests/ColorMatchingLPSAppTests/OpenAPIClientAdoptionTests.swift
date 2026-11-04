import Foundation
import XCTest

final class OpenAPIClientAdoptionTests: XCTestCase {
    func testPackageUsesGeneratedClientAndVendoredSpecCoversAppEndpoints() throws {
        let package = try String(contentsOf: packageURL, encoding: .utf8)
        XCTAssertTrue(package.contains("swift-openapi-generator"))
        XCTAssertTrue(package.contains("swift-openapi-runtime"))

        let spec = try XCTUnwrap(try? Data(contentsOf: specURL))
        let document = try XCTUnwrap(JSONSerialization.jsonObject(with: spec) as? [String: Any])
        let paths = try XCTUnwrap(document["paths"] as? [String: Any])

        [
            "/api/v1/test_sheets/{sheet_id}/manifest",
            "/api/v1/test_sheets/recent",
            "/api/v1/test_sheets/{sheet_id}/captures",
            "/api/v1/captures/{capture_id}/measurements",
            "/api/v1/captures/{capture_id}/judgments",
            "/api/v1/test_sheets/{sheet_id}/ranked_results"
        ].forEach { XCTAssertNotNil(paths[$0], "Missing OpenAPI path: \($0)") }
    }

    private var packageURL: URL {
        repositoryRoot.appending(path: "Package.swift")
    }

    private var specURL: URL {
        repositoryRoot.appending(path: "OpenAPI/color-matching-openapi.json")
    }

    private var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
