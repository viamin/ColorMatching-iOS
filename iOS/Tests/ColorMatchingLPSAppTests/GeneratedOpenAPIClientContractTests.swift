import Foundation
import XCTest

final class GeneratedOpenAPIClientContractTests: XCTestCase {
    func testPackageDeclaresTheOpenAPIClientGeneratorAndRuntime() throws {
        let package = try String(contentsOf: iOSDirectory.appending(path: "Package.swift"))

        XCTAssertTrue(package.contains("swift-openapi-generator"))
        XCTAssertTrue(package.contains("swift-openapi-runtime"))
        XCTAssertTrue(package.contains("OpenAPIGenerator"))
        XCTAssertTrue(package.contains("OpenAPIRuntime"))
    }

    func testVendoredSpecificationContainsEveryCompanionOperation() throws {
        let specification = try Data(contentsOf: iOSDirectory.appending(path: "Sources/ColorMatchingLPSAppCore/openapi.json"))
        let document = try XCTUnwrap(try JSONSerialization.jsonObject(with: specification) as? [String: Any])
        let paths = try XCTUnwrap(document["paths"] as? [String: Any])

        XCTAssertNotNil(paths["/api/v1/test_sheets/{sheet_id}/manifest"])
        XCTAssertNotNil(paths["/api/v1/test_sheets/recent"])
        XCTAssertNotNil(paths["/api/v1/test_sheets/{sheet_id}/captures"])
        XCTAssertNotNil(paths["/api/v1/captures/{capture_id}/measurements"])
        XCTAssertNotNil(paths["/api/v1/captures/{capture_id}/judgments"])
        XCTAssertNotNil(paths["/api/v1/test_sheets/{sheet_id}/ranked_results"])
    }

    private var iOSDirectory: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
