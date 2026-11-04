import Foundation
import XCTest

final class OpenAPIContractTests: XCTestCase {
    func testVendoredOpenAPIDocumentCoversEveryIOSOperation() throws {
        let documentURL = repositoryRoot
            .appendingPathComponent("iOS/OpenAPI/color-matching-api.json")
        let data = try Data(contentsOf: documentURL)
        let document = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let paths = try XCTUnwrap(document["paths"] as? [String: [String: Any]])

        try assertOperation("get", at: "/api/v1/test_sheets/{sheet_id}/manifest", in: paths)
        try assertOperation("get", at: "/api/v1/test_sheets/recent", in: paths)
        try assertOperation("post", at: "/api/v1/test_sheets/{sheet_id}/captures", in: paths)
        try assertOperation("post", at: "/api/v1/captures/{capture_id}/measurements", in: paths)
        try assertOperation("post", at: "/api/v1/captures/{capture_id}/judgments", in: paths)
        try assertOperation("get", at: "/api/v1/test_sheets/{sheet_id}/ranked_results", in: paths)
    }

    private var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func assertOperation(
        _ method: String,
        at path: String,
        in paths: [String: [String: Any]]
    ) throws {
        let operation = try XCTUnwrap(paths[path]?[method] as? [String: Any])
        let responses = try XCTUnwrap(operation["responses"] as? [String: Any])
        XCTAssertFalse(responses.isEmpty, "\(method.uppercased()) \(path) must declare responses for generated decoding")

        if method == "post" {
            let requestBody = try XCTUnwrap(operation["requestBody"] as? [String: Any])
            let content = try XCTUnwrap(requestBody["content"] as? [String: Any])
            XCTAssertNotNil(content["application/json"])
        }
    }
}
