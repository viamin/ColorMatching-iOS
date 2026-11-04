import Foundation
import XCTest

final class OpenAPIContractTests: XCTestCase {
    func testVendoredSpecificationContainsEveryCompanionSurface() throws {
        let specification = try specificationObject()
        let paths = try XCTUnwrap(specification["paths"] as? [String: Any])

        try assertOperation("get", at: "/api/v1/test_sheets/{sheet_id}/manifest", in: paths)
        try assertOperation("get", at: "/api/v1/test_sheets/recent", in: paths)
        try assertOperation("post", at: "/api/v1/test_sheets/{sheet_id}/captures", in: paths)
        try assertOperation("post", at: "/api/v1/captures/{capture_id}/measurements", in: paths)
        try assertOperation("post", at: "/api/v1/captures/{capture_id}/judgments", in: paths)
        try assertOperation("get", at: "/api/v1/test_sheets/{sheet_id}/ranked_results", in: paths)
    }

    func testVendoredSpecificationDescribesTypedWriteResponsesAndRankedResults() throws {
        let specification = try specificationObject()
        let paths = try XCTUnwrap(specification["paths"] as? [String: Any])

        for path in [
            "/api/v1/test_sheets/{sheet_id}/captures",
            "/api/v1/captures/{capture_id}/measurements",
            "/api/v1/captures/{capture_id}/judgments"
        ] {
            let operation = try XCTUnwrap((paths[path] as? [String: Any])?["post"] as? [String: Any])
            XCTAssertNotNil(operation["requestBody"], "\(path) must generate a typed request body")
            let responses = try XCTUnwrap(operation["responses"] as? [String: Any])
            XCTAssertFalse(responses.isEmpty, "\(path) must generate a typed response")
        }

        let schemas = try XCTUnwrap(
            ((specification["components"] as? [String: Any])?["schemas"] as? [String: Any])
        )
        XCTAssertNotNil(schemas["RankedResults"], "ranked results must be a generated model")
    }

    private func specificationObject() throws -> [String: Any] {
        let data = try Data(contentsOf: specificationURL)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private func assertOperation(_ method: String, at path: String, in paths: [String: Any]) throws {
        let pathItem = try XCTUnwrap(paths[path] as? [String: Any], "Missing path: \(path)")
        XCTAssertNotNil(pathItem[method], "Missing \(method.uppercased()) operation for \(path)")
    }

    private var specificationURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "OpenAPI/color-matching-v1.json")
    }
}
