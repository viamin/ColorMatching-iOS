import Foundation
import XCTest

final class OpenAPIContractTests: XCTestCase {
    func testVendoredSpecDefinesEveryCompanionAppOperation() throws {
        let specURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "Specs/color_matching.openapi.json")
        let spec = try JSONSerialization.jsonObject(with: Data(contentsOf: specURL)) as? [String: Any]
        let paths = try XCTUnwrap(spec?["paths"] as? [String: Any])

        XCTAssertNotNil(paths["/api/v1/test_sheets/recent"])
        XCTAssertNotNil(paths["/api/v1/test_sheets/{sheet_id}/manifest"])
        XCTAssertNotNil(paths["/api/v1/test_sheets/{sheet_id}/captures"])
        XCTAssertNotNil(paths["/api/v1/captures/{capture_id}/measurements"])
        XCTAssertNotNil(paths["/api/v1/captures/{capture_id}/judgments"])
        XCTAssertNotNil(paths["/api/v1/test_sheets/{sheet_id}/ranked_results"])
    }
}
