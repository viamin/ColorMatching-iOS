import Foundation
import XCTest

final class OpenAPIClientAdoptionTests: XCTestCase {
    func testPackagePinsOpenAPIGeneratorAndRuntimeAndVendorsTheServerSpec() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let package = try String(contentsOf: repositoryRoot.appending(path: "iOS/Package.swift"))
        let specURL = repositoryRoot.appending(path: "iOS/OpenAPI/color_matching.openapi.json")

        XCTAssertTrue(package.contains("swift-openapi-generator"))
        XCTAssertTrue(package.contains("swift-openapi-runtime"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: specURL.path))
        guard FileManager.default.fileExists(atPath: specURL.path) else { return }

        let spec = try String(contentsOf: specURL)
        XCTAssertTrue(spec.contains("/api/v1/test_sheets/{sheet_id}/manifest"))
        XCTAssertTrue(spec.contains("/api/v1/test_sheets/recent"))
        XCTAssertTrue(spec.contains("/api/v1/test_sheets/{sheet_id}/captures"))
        XCTAssertTrue(spec.contains("/api/v1/captures/{capture_id}/measurements"))
        XCTAssertTrue(spec.contains("/api/v1/captures/{capture_id}/judgments"))
        XCTAssertTrue(spec.contains("/api/v1/test_sheets/{sheet_id}/ranked_results"))
    }
}
