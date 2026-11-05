import Foundation
import XCTest

final class OpenAPIClientAdoptionTests: XCTestCase {
    func testGeneratedClientInputsAreTrackedInThePackage() throws {
        let package = try String(contentsOf: repositoryRoot.appending(path: "iOS/Package.swift"))

        XCTAssertTrue(package.contains("swift-openapi-generator"))
        XCTAssertTrue(package.contains("swift-openapi-runtime"))
        XCTAssertTrue(package.contains("OpenAPIGenerator"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: repositoryRoot.appending(path: "iOS/openapi.yaml").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: repositoryRoot.appending(path: "iOS/openapi-generator-config.yaml").path))
    }

    func testGeneratedClientSpecificationContainsEveryCompanionOperation() throws {
        let specification = try String(contentsOf: repositoryRoot.appending(path: "iOS/openapi.yaml"))

        [
            "/api/v1/test_sheets/{sheet_id}/manifest",
            "/api/v1/test_sheets/recent",
            "/api/v1/test_sheets/{sheet_id}/captures",
            "/api/v1/captures/{capture_id}/measurements",
            "/api/v1/captures/{capture_id}/judgments",
            "/api/v1/test_sheets/{sheet_id}/ranked_results"
        ].forEach { path in
            XCTAssertTrue(specification.contains(path), "Missing generated-client operation for \(path)")
        }
    }

    private var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
