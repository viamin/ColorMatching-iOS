import Foundation
import XCTest

final class OpenAPIContractTests: XCTestCase {
    func testVendoredPublishedSpecDeclaresEveryCompanionOperation() throws {
        let document = try openAPIDocument()
        let paths = try XCTUnwrap(document["paths"] as? [String: Any])

        for operation in requiredOperations {
            let pathItem = try XCTUnwrap(paths[operation.path] as? [String: Any], "Missing \(operation.path)")
            XCTAssertNotNil(pathItem[operation.method], "Missing \(operation.method.uppercased()) \(operation.path)")
        }
    }

    func testPackageConfiguresTheOpenAPIGeneratorAndRuntime() throws {
        let packageManifest = try String(contentsOf: repositoryRoot.appending(path: "iOS/Package.swift"))

        XCTAssertTrue(packageManifest.contains("swift-openapi-generator"))
        XCTAssertTrue(packageManifest.contains("swift-openapi-runtime"))
        XCTAssertTrue(packageManifest.contains("OpenAPIGenerator"))
        XCTAssertTrue(packageManifest.contains("OpenAPIRuntime"))
    }

    private var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func openAPIDocument() throws -> [String: Any] {
        let specURL = repositoryRoot.appending(path: "iOS/OpenAPI/color_matching.openapi.json")
        guard FileManager.default.fileExists(atPath: specURL.path) else {
            XCTFail("Vendor the provider document at \(specURL.path)")
            return [:]
        }

        let data = try Data(contentsOf: specURL)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private let requiredOperations = [
        (path: "/api/v1/test_sheets/{sheet_id}/manifest", method: "get"),
        (path: "/api/v1/test_sheets/recent", method: "get"),
        (path: "/api/v1/test_sheets/{sheet_id}/captures", method: "post"),
        (path: "/api/v1/captures/{capture_id}/measurements", method: "post"),
        (path: "/api/v1/captures/{capture_id}/judgments", method: "post"),
        (path: "/api/v1/test_sheets/{sheet_id}/ranked_results", method: "get")
    ]
}
