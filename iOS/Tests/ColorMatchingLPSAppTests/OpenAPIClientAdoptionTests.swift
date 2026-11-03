import Foundation
import XCTest

final class OpenAPIClientAdoptionTests: XCTestCase {
    func testPackageWiresGeneratorRuntimeAndVendoredSheetCaptureSpec() throws {
        let package = try String(contentsOf: repositoryURL.appending(path: "iOS/Package.swift"))
        let specificationURL = repositoryURL.appending(path: "iOS/Sources/ColorMatchingLPSAppCore/openapi.yaml")

        XCTAssertTrue(package.contains("swift-openapi-generator"))
        XCTAssertTrue(package.contains("swift-openapi-runtime"))
        XCTAssertTrue(package.contains("OpenAPIGenerator"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: specificationURL.path))

        let specification = try String(contentsOf: specificationURL)
        XCTAssertTrue(specification.contains("/api/v1/test_sheets/{sheet_id}/manifest"))
        XCTAssertTrue(specification.contains("/api/v1/test_sheets/recent"))
        XCTAssertTrue(specification.contains("/api/v1/test_sheets/{sheet_id}/captures"))
        XCTAssertTrue(specification.contains("/api/v1/captures/{capture_id}/measurements"))
        XCTAssertTrue(specification.contains("/api/v1/captures/{capture_id}/judgments"))
        XCTAssertTrue(specification.contains("/api/v1/test_sheets/{sheet_id}/ranked_results"))
    }

    private var repositoryURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
