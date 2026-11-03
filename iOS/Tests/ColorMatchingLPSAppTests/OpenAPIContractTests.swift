import Foundation
import XCTest

final class OpenAPIContractTests: XCTestCase {
    func testVendoredSpecDeclaresEveryCompanionOperation() throws {
        let document = try openAPIDocument()
        guard !document.isEmpty else { return }
        let paths = try XCTUnwrap(document["paths"] as? [String: Any])

        for operation in requiredOperations {
            let pathItem = try XCTUnwrap(paths[operation.path] as? [String: Any], "Missing \(operation.path)")
            XCTAssertNotNil(pathItem[operation.method], "Missing \(operation.method.uppercased()) \(operation.path)")
        }
    }

    private func openAPIDocument() throws -> [String: Any] {
        guard FileManager.default.fileExists(atPath: openAPISpecURL.path) else {
            XCTFail("Vendored OpenAPI document is missing at \(openAPISpecURL.path)")
            return [:]
        }

        let data = try Data(contentsOf: openAPISpecURL)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private var openAPISpecURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "OpenAPI/color-matching.openapi.json")
    }

    private let requiredOperations = [
        Operation(method: "get", path: "/api/v1/test_sheets/{sheet_id}/manifest"),
        Operation(method: "get", path: "/api/v1/test_sheets/recent"),
        Operation(method: "post", path: "/api/v1/test_sheets/{sheet_id}/captures"),
        Operation(method: "post", path: "/api/v1/captures/{capture_id}/measurements"),
        Operation(method: "post", path: "/api/v1/captures/{capture_id}/judgments"),
        Operation(method: "get", path: "/api/v1/test_sheets/{sheet_id}/ranked_results")
    ]
}

private struct Operation {
    let method: String
    let path: String
}
