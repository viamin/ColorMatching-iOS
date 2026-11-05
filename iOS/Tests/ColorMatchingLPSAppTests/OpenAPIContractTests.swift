import Foundation
import XCTest

final class OpenAPIContractTests: XCTestCase {
    func testVendoredOpenAPIDocumentCoversCompanionOperations() throws {
        let documentURL = packageRoot
            .appending(path: "Sources/ColorMatchingAPI/openapi.json")

        XCTAssertTrue(
            FileManager.default.fileExists(atPath: documentURL.path),
            "Vendor the published /api/v1/openapi.json as the generator input."
        )

        let data = try Data(contentsOf: documentURL)
        let document = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let paths = try XCTUnwrap(document["paths"] as? [String: Any])

        for operation in requiredOperations {
            let path = try XCTUnwrap(paths[operation.path] as? [String: Any], "Missing path: \(operation.path)")
            XCTAssertNotNil(path[operation.method], "Missing \(operation.method.uppercased()) operation for \(operation.path)")
        }
    }

    private var packageRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
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
