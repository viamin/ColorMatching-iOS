import Foundation
import XCTest

final class GeneratedOpenAPIContractTests: XCTestCase {
    func testGeneratedClientInputsCoverEveryAppOperation() throws {
        let package = try String(contentsOf: packageURL)
        XCTAssertTrue(package.contains("swift-openapi-generator"))
        XCTAssertTrue(package.contains("swift-openapi-runtime"))

        let document = try Data(contentsOf: openAPIDocumentURL)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: document) as? [String: Any])
        let paths = try XCTUnwrap(json["paths"] as? [String: Any])

        XCTAssertNotNil(paths["/api/v1/test_sheets/recent"])
        XCTAssertNotNil(paths["/api/v1/test_sheets/{sheet_id}/manifest"])
        XCTAssertNotNil(paths["/api/v1/test_sheets/{sheet_id}/captures"])
        XCTAssertNotNil(paths["/api/v1/captures/{capture_id}/measurements"])
        XCTAssertNotNil(paths["/api/v1/captures/{capture_id}/judgments"])
        XCTAssertNotNil(paths["/api/v1/test_sheets/{sheet_id}/ranked_results"])
    }

    private var packageURL: URL {
        sourceRoot.appending(path: "Package.swift")
    }

    private var openAPIDocumentURL: URL {
        sourceRoot.appending(path: "OpenAPI/openapi.json")
    }

    private var sourceRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
