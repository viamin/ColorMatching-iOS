import Foundation
import XCTest

final class OpenAPIContractTests: XCTestCase {
    func testVendoredSpecIncludesEveryCompanionClientOperation() throws {
        let document = try JSONSerialization.jsonObject(with: try Data(contentsOf: openAPIDocumentURL))
        let paths = try XCTUnwrap(document as? [String: Any])
            .value(for: "paths", as: [String: Any].self)

        XCTAssertNotNil(paths["/api/v1/test_sheets/recent"])
        XCTAssertNotNil(paths["/api/v1/test_sheets/{sheet_id}/manifest"])
        XCTAssertNotNil(paths["/api/v1/test_sheets/{sheet_id}/ranked_results"])
        XCTAssertNotNil(paths["/api/v1/test_sheets/{sheet_id}/captures"])
        XCTAssertNotNil(paths["/api/v1/captures/{capture_id}/measurements"])
        XCTAssertNotNil(paths["/api/v1/captures/{capture_id}/judgments"])
    }

    private var openAPIDocumentURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "OpenAPI/color_matching.json")
    }
}

private extension Dictionary where Key == String, Value == Any {
    func value<T>(for key: String, as type: T.Type) -> T? {
        self[key] as? T
    }
}
