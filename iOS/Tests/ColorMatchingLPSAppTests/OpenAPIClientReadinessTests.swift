import Foundation
import XCTest

final class OpenAPIClientReadinessTests: XCTestCase {
    func testGeneratedClientDependenciesAndVendoredContractAreConfigured() throws {
        let package = try String(contentsOf: repositoryRoot.appending(path: "iOS/Package.swift"))

        XCTAssertTrue(package.contains("swift-openapi-generator"))
        XCTAssertTrue(package.contains("swift-openapi-runtime"))
        XCTAssertTrue(package.contains("OpenAPIGenerator"))
        XCTAssertTrue(package.contains("OpenAPIRuntime"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: openAPIDocument.path))
    }

    func testVendoredContractDeclaresEveryCompanionSurface() throws {
        guard FileManager.default.fileExists(atPath: openAPIDocument.path) else {
            XCTFail("Missing vendored OpenAPI document at \(openAPIDocument.path)")
            return
        }

        let data = try Data(contentsOf: openAPIDocument)
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
            XCTAssertNotNil(paths[path], "Missing OpenAPI path: \(path)")
        }
    }

    private var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private var openAPIDocument: URL {
        repositoryRoot.appending(path: "iOS/OpenAPI/color-matching.json")
    }
}
