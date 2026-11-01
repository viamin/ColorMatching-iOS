import Foundation
import XCTest

final class OpenAPIContractTests: XCTestCase {
    func testVendoredSpecificationCoversEveryAppSurface() throws {
        let specification = try specificationObject()
        let paths = try XCTUnwrap(specification["paths"] as? [String: Any])

        try assertOperation(paths, "/api/v1/test_sheets/{sheet_id}/manifest", method: "get", successStatus: "200")
        try assertOperation(paths, "/api/v1/test_sheets/recent", method: "get", successStatus: "200")
        try assertOperation(paths, "/api/v1/test_sheets/{sheet_id}/captures", method: "post", successStatus: "201")
        try assertOperation(paths, "/api/v1/captures/{capture_id}/measurements", method: "post", successStatus: "200")
        try assertOperation(paths, "/api/v1/captures/{capture_id}/judgments", method: "post", successStatus: "200")
        try assertOperation(paths, "/api/v1/test_sheets/{sheet_id}/ranked_results", method: "get", successStatus: "200")
    }

    private func specificationObject() throws -> [String: Any] {
        let data = try Data(contentsOf: specificationURL)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private func assertOperation(
        _ paths: [String: Any],
        _ path: String,
        method: String,
        successStatus: String
    ) throws {
        let pathItem = try XCTUnwrap(paths[path] as? [String: Any], "Missing OpenAPI path: \(path)")
        let operation = try XCTUnwrap(pathItem[method] as? [String: Any], "Missing \(method.uppercased()) operation: \(path)")
        let responses = try XCTUnwrap(operation["responses"] as? [String: Any])
        XCTAssertNotNil(responses[successStatus], "Missing \(successStatus) response: \(method.uppercased()) \(path)")
    }

    private var specificationURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "openapi/color_matching.openapi.json")
    }
}
