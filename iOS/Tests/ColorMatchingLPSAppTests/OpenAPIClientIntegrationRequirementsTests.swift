import Foundation
import XCTest

final class OpenAPIClientIntegrationRequirementsTests: XCTestCase {
    func testPackageDeclaresTheOpenAPIGeneratorRuntimeAndGeneratedClientTarget() throws {
        let package = try String(contentsOf: repositoryRoot.appending(path: "iOS/Package.swift"))

        XCTAssertTrue(package.contains("swift-openapi-generator"))
        XCTAssertTrue(package.contains("swift-openapi-runtime"))
        XCTAssertTrue(package.contains("OpenAPIGenerator"))
        XCTAssertTrue(package.contains("ColorMatchingAPI"))
    }

    func testVendoredSpecificationContainsEveryEndpointUsedByTheCompanion() throws {
        let specificationURL = repositoryRoot.appending(path: "iOS/Sources/ColorMatchingAPI/openapi.json")
        let specification = try JSONSerialization.jsonObject(with: Data(contentsOf: specificationURL))
        let paths = try XCTUnwrap((specification as? [String: Any])?["paths"] as? [String: Any])

        XCTAssertNotNil(paths["/api/v1/test_sheets/{sheet_id}/manifest"])
        XCTAssertNotNil(paths["/api/v1/test_sheets/recent"])
        XCTAssertNotNil(paths["/api/v1/test_sheets/{sheet_id}/captures"])
        XCTAssertNotNil(paths["/api/v1/captures/{capture_id}/measurements"])
        XCTAssertNotNil(paths["/api/v1/captures/{capture_id}/judgments"])
        XCTAssertNotNil(paths["/api/v1/test_sheets/{sheet_id}/ranked_results"])
    }

    private var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
