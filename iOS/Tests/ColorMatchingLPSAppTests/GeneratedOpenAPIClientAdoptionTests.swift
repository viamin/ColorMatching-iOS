import Foundation
import XCTest

final class GeneratedOpenAPIClientAdoptionTests: XCTestCase {
    func testPackageDeclaresOpenAPIGeneratorAndRuntimeDependencies() throws {
        let package = try String(contentsOf: repositoryURL.appending(path: "iOS/Package.swift"))

        XCTAssertTrue(package.contains("swift-openapi-generator"))
        XCTAssertTrue(package.contains("swift-openapi-runtime"))
    }

    func testVendoredSpecificationCoversEveryCompanionSurface() throws {
        let specification = try String(contentsOf: repositoryURL.appending(path: "iOS/OpenAPI/openapi.json"))

        [
            "/api/v1/test_sheets/{sheet_id}/manifest",
            "/api/v1/test_sheets/recent",
            "/api/v1/test_sheets/{sheet_id}/captures",
            "/api/v1/captures/{capture_id}/measurements",
            "/api/v1/captures/{capture_id}/judgments",
            "/api/v1/test_sheets/{sheet_id}/ranked_results"
        ].forEach { path in
            XCTAssertTrue(specification.contains(path), "Missing OpenAPI path: \(path)")
        }
    }

    func testHandWrittenTransportModelsAreReplacedByGeneratedClientTypes() throws {
        let client = try String(contentsOf: repositoryURL.appending(path: "iOS/Sources/ColorMatchingLPSAppCore/APIClient.swift"))

        XCTAssertTrue(client.contains("import OpenAPIRuntime"))
        XCTAssertFalse(client.contains("private struct CreateCaptureRequest"))
        XCTAssertFalse(client.contains("private struct MeasurementUploadRequest"))
        XCTAssertFalse(client.contains("private struct JudgmentUploadRequest"))
    }

    private var repositoryURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
