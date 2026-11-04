import Foundation
import XCTest

final class OpenAPIContractTests: XCTestCase {
    func testVendoredOpenAPIDocumentDeclaresEveryCompanionSurface() throws {
        let document = try XCTUnwrap(
            try? Data(contentsOf: openAPIDocumentURL()),
            "Vendor the OpenAPI document from color_matching #110 at iOS/OpenAPI/color-matching-openapi.json."
        )
        let root = try XCTUnwrap(try JSONSerialization.jsonObject(with: document) as? [String: Any])
        let paths = try XCTUnwrap(root["paths"] as? [String: Any])

        try assertOperation(paths, path: "/api/v1/test_sheets/{sheet_id}/manifest", method: "get")
        try assertOperation(paths, path: "/api/v1/test_sheets/recent", method: "get")
        try assertOperation(paths, path: "/api/v1/test_sheets/{sheet_id}/captures", method: "post")
        try assertOperation(paths, path: "/api/v1/captures/{capture_id}/measurements", method: "post")
        try assertOperation(paths, path: "/api/v1/captures/{capture_id}/judgments", method: "post")
        try assertOperation(paths, path: "/api/v1/test_sheets/{sheet_id}/ranked_results", method: "get")
    }

    private func assertOperation(_ paths: [String: Any], path: String, method: String) throws {
        let item = try XCTUnwrap(paths[path] as? [String: Any], "Missing OpenAPI path: \(path)")
        XCTAssertNotNil(item[method], "Missing \(method.uppercased()) operation for \(path)")
    }

    private func openAPIDocumentURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "OpenAPI/color-matching-openapi.json")
    }
}
