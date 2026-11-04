import Foundation
import XCTest

final class OpenAPISpecContractTests: XCTestCase {
    func testVendoredOpenAPIDocumentDescribesEveryIOSClientOperation() throws {
        let data = try Data(contentsOf: Self.specURL)
        let document = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let paths = try XCTUnwrap(document["paths"] as? [String: Any])

        for operation in Self.iOSOperations {
            let pathItem = try XCTUnwrap(paths[operation.path] as? [String: Any], "Missing \(operation.path)")
            let endpoint = try XCTUnwrap(pathItem[operation.method] as? [String: Any], "Missing \(operation.method.uppercased()) \(operation.path)")
            XCTAssertNotNil(endpoint["operationId"], "\(operation.method.uppercased()) \(operation.path) needs an operationId for stable generated Swift API names")
        }
    }

    private static let specURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appending(path: "OpenAPI/color_matching.openapi.json")

    private static let iOSOperations = [
        (path: "/api/v1/test_sheets/{sheet_id}/manifest", method: "get"),
        (path: "/api/v1/test_sheets/recent", method: "get"),
        (path: "/api/v1/test_sheets/{sheet_id}/captures", method: "post"),
        (path: "/api/v1/captures/{capture_id}/measurements", method: "post"),
        (path: "/api/v1/captures/{capture_id}/judgments", method: "post"),
        (path: "/api/v1/test_sheets/{sheet_id}/ranked_results", method: "get")
    ]
}
