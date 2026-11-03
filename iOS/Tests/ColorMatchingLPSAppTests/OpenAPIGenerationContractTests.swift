import Foundation
import XCTest

final class OpenAPIGenerationContractTests: XCTestCase {
    func testGeneratedClientInputsCoverEveryAppUsedOperation() throws {
        let package = try String(contentsOf: packageURL, encoding: .utf8)
        let spec = try String(contentsOf: specURL, encoding: .utf8)

        XCTAssertTrue(package.contains("swift-openapi-generator"))
        XCTAssertTrue(package.contains("swift-openapi-runtime"))
        XCTAssertTrue(package.contains("OpenAPIGenerator"))
        XCTAssertTrue(package.contains("OpenAPIRuntime"))
        XCTAssertTrue(spec.contains("/api/v1/test_sheets/{sheet_id}/manifest"))
        XCTAssertTrue(spec.contains("/api/v1/test_sheets/recent"))
        XCTAssertTrue(spec.contains("/api/v1/test_sheets/{sheet_id}/captures"))
        XCTAssertTrue(spec.contains("/api/v1/captures/{capture_id}/measurements"))
        XCTAssertTrue(spec.contains("/api/v1/captures/{capture_id}/judgments"))
        XCTAssertTrue(spec.contains("/api/v1/test_sheets/{sheet_id}/ranked_results"))
    }

    private var packageURL: URL {
        sourceDirectory
            .appendingPathComponent("../../Package.swift")
            .standardizedFileURL
    }

    private var specURL: URL {
        sourceDirectory
            .appendingPathComponent("../../OpenAPI/color-matching-openapi.json")
            .standardizedFileURL
    }

    private var sourceDirectory: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    }
}
