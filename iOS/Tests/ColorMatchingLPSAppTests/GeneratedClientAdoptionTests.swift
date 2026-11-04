import Foundation
import XCTest

final class GeneratedClientAdoptionTests: XCTestCase {
    func testPackageAndVendoredSpecEnableGeneratedClient() throws {
        let iOSRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let package = try String(contentsOf: iOSRoot.appending(path: "Package.swift"), encoding: .utf8)
        let specificationURL = iOSRoot.appending(path: "OpenAPI/color-matching.json")

        XCTAssertTrue(package.contains("swift-openapi-generator"))
        XCTAssertTrue(package.contains("swift-openapi-runtime"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: specificationURL.path))
    }

    func testVendoredSpecDescribesEverySurfaceUsedByTheApp() throws {
        let iOSRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let specificationURL = iOSRoot.appending(path: "OpenAPI/color-matching.json")
        guard FileManager.default.fileExists(atPath: specificationURL.path) else {
            XCTFail("Vendor the OpenAPI snapshot at \(specificationURL.path)")
            return
        }
        let data = try Data(contentsOf: specificationURL)
        let document = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let paths = try XCTUnwrap(document["paths"] as? [String: Any])

        [
            "/api/v1/test_sheets/{sheet_id}/manifest",
            "/api/v1/test_sheets/recent",
            "/api/v1/test_sheets/{sheet_id}/captures",
            "/api/v1/captures/{capture_id}/measurements",
            "/api/v1/captures/{capture_id}/judgments",
            "/api/v1/test_sheets/{sheet_id}/ranked_results"
        ].forEach { XCTAssertNotNil(paths[$0], "Missing OpenAPI path: \($0)") }
    }
}
