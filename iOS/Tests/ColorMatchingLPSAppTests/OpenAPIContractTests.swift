import Foundation
import XCTest

final class OpenAPIContractTests: XCTestCase {
    func testVendoredSpecificationDefinesEveryCompanionAppOperation() throws {
        let document = try Data(contentsOf: specificationURL)
        let root = try XCTUnwrap(try JSONSerialization.jsonObject(with: document) as? [String: Any])
        let paths = try XCTUnwrap(root["paths"] as? [String: Any])

        XCTAssertNotNil(paths["/api/v1/test_sheets/recent"])
        XCTAssertNotNil(paths["/api/v1/test_sheets/{sheet_id}/manifest"])
        XCTAssertNotNil(paths["/api/v1/test_sheets/{sheet_id}/captures"])
        XCTAssertNotNil(paths["/api/v1/captures/{capture_id}/measurements"])
        XCTAssertNotNil(paths["/api/v1/captures/{capture_id}/judgments"])
        XCTAssertNotNil(paths["/api/v1/test_sheets/{sheet_id}/ranked_results"])
    }

    private var specificationURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "OpenAPI/color-matching-api.json")
    }
}
