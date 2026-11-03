import Foundation
import XCTest

final class OpenAPIClientContractTests: XCTestCase {
    func testPackageDeclaresGeneratedClientDependenciesAndPlugin() throws {
        let package = try String(contentsOf: packageURL, encoding: .utf8)

        XCTAssertTrue(package.contains("swift-openapi-generator"))
        XCTAssertTrue(package.contains("swift-openapi-runtime"))
        XCTAssertTrue(package.contains("OpenAPIGenerator"))
        XCTAssertTrue(package.contains("ColorMatchingAPI"))
    }

    func testVendoredSpecCoversEveryCompanionSurface() throws {
        let spec = try XCTUnwrap(loadVendoredSpec())
        let paths = try XCTUnwrap(spec["paths"] as? [String: Any])

        XCTAssertNotNil(paths["/api/v1/test_sheets/recent"])
        XCTAssertNotNil(paths["/api/v1/test_sheets/{sheet_id}/manifest"])
        XCTAssertNotNil(paths["/api/v1/test_sheets/{sheet_id}/captures"])
        XCTAssertNotNil(paths["/api/v1/captures/{capture_id}/measurements"])
        XCTAssertNotNil(paths["/api/v1/captures/{capture_id}/judgments"])
        XCTAssertNotNil(paths["/api/v1/test_sheets/{sheet_id}/ranked_results"])
    }

    private var packageURL: URL {
        repositoryURL.appending(path: "iOS/Package.swift")
    }

    private var specURL: URL {
        repositoryURL.appending(path: "iOS/Sources/ColorMatchingAPI/openapi.json")
    }

    private var repositoryURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func loadVendoredSpec() -> [String: Any]? {
        guard let data = try? Data(contentsOf: specURL) else {
            XCTFail("Vendor the published /api/v1/openapi.json as ColorMatchingAPI input")
            return nil
        }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }
}
