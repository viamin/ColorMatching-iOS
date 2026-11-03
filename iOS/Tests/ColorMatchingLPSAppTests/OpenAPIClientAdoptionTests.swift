import Foundation
import XCTest

final class OpenAPIClientAdoptionTests: XCTestCase {
    func testPackageVendorsThePublishedSpecAndDeclaresGeneratorAndRuntime() throws {
        let packageRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let package = try String(contentsOf: packageRoot.appending(path: "Package.swift"))

        XCTAssertTrue(package.contains("swift-openapi-generator"))
        XCTAssertTrue(package.contains("swift-openapi-runtime"))
        XCTAssertTrue(package.contains("ColorMatchingAPI"))

        let documentURL = packageRoot.appending(path: "OpenAPI/color-matching-api-v1.json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: documentURL.path))
        guard FileManager.default.fileExists(atPath: documentURL.path) else { return }

        let document = try JSONSerialization.jsonObject(with: Data(contentsOf: documentURL))
        let paths = try XCTUnwrap((document as? [String: Any])?["paths"] as? [String: Any])
        let expectedPaths = [
            "/api/v1/test_sheets/{sheet_id}/manifest",
            "/api/v1/test_sheets/recent",
            "/api/v1/test_sheets/{sheet_id}/captures",
            "/api/v1/captures/{capture_id}/measurements",
            "/api/v1/captures/{capture_id}/judgments",
            "/api/v1/test_sheets/{sheet_id}/ranked_results"
        ]

        expectedPaths.forEach { XCTAssertNotNil(paths[$0], "Missing OpenAPI path: \($0)") }
    }
}
