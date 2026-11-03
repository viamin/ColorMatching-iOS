import Foundation
import XCTest

final class GeneratedOpenAPIContractTests: XCTestCase {
    func testVendoredOpenAPIDocumentAndPackageDeclareEveryAppSurface() throws {
        let packageRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let package = try String(contentsOf: packageRoot.appending(path: "Package.swift"))
        let specificationURL = packageRoot.appending(path: "OpenAPI/openapi.json")

        XCTAssertTrue(package.contains("swift-openapi-generator"))
        XCTAssertTrue(package.contains("swift-openapi-runtime"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: specificationURL.path))

        let document = try XCTUnwrap(
            try? JSONSerialization.jsonObject(with: Data(contentsOf: specificationURL)) as? [String: Any]
        )
        let paths = try XCTUnwrap(document["paths"] as? [String: Any])

        XCTAssertNotNil(paths["/api/v1/test_sheets/{sheet_id}/manifest"])
        XCTAssertNotNil(paths["/api/v1/test_sheets/recent"])
        XCTAssertNotNil(paths["/api/v1/test_sheets/{sheet_id}/captures"])
        XCTAssertNotNil(paths["/api/v1/captures/{capture_id}/measurements"])
        XCTAssertNotNil(paths["/api/v1/captures/{capture_id}/judgments"])
        XCTAssertNotNil(paths["/api/v1/test_sheets/{sheet_id}/ranked_results"])
    }
}
