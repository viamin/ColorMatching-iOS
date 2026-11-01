import Foundation
import XCTest

final class GeneratedOpenAPIClientAdoptionTests: XCTestCase {
    private let requiredPaths = [
        "/api/v1/test_sheets/{sheet_id}/manifest",
        "/api/v1/test_sheets/recent",
        "/api/v1/test_sheets/{sheet_id}/captures",
        "/api/v1/captures/{capture_id}/measurements",
        "/api/v1/captures/{capture_id}/judgments",
        "/api/v1/test_sheets/{sheet_id}/ranked_results"
    ]

    func testPackageDeclaresOpenAPIGeneratorAndRuntime() throws {
        let manifest = try String(contentsOf: packageRoot.appending(path: "Package.swift"))

        XCTAssertTrue(manifest.contains("swift-openapi-generator"))
        XCTAssertTrue(manifest.contains("swift-openapi-runtime"))
    }

    func testVendoredOpenAPIDocumentCoversEveryAppOperation() throws {
        let document = try Data(contentsOf: packageRoot.appending(path: "OpenAPI/color-matching.json"))
        let openAPI = try XCTUnwrap(try JSONSerialization.jsonObject(with: document) as? [String: Any])
        let paths = try XCTUnwrap(openAPI["paths"] as? [String: Any])

        let version = try XCTUnwrap(openAPI["openapi"] as? String)
        XCTAssertTrue(version.hasPrefix("3."))
        requiredPaths.forEach { XCTAssertNotNil(paths[$0], "Missing OpenAPI path: \($0)") }
    }

    func testGeneratorConfigurationUsesVendoredDocument() throws {
        let configuration = try String(
            contentsOf: packageRoot.appending(path: "OpenAPI/openapi-generator-config.yaml")
        )

        XCTAssertTrue(configuration.contains("color-matching.json"))
    }

    private var packageRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
