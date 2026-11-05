import Foundation
import XCTest

final class OpenAPIClientWiringTests: XCTestCase {
    func testPackageDeclaresOpenAPIGeneratorAndRuntimeDependencies() throws {
        let package = try packageManifest()

        XCTAssertTrue(package.contains("swift-openapi-generator"))
        XCTAssertTrue(package.contains("swift-openapi-runtime"))
        XCTAssertTrue(package.contains("OpenAPIGenerator"))
        XCTAssertTrue(package.contains("OpenAPIURLSession"))
    }

    func testVendoredSpecificationCoversEveryCompanionAPISurface() throws {
        let specification = try String(contentsOf: openAPISpecificationURL())

        [
            "/api/v1/test_sheets/recent",
            "/api/v1/test_sheets/{sheet_id}/manifest",
            "/api/v1/test_sheets/{sheet_id}/captures",
            "/api/v1/captures/{capture_id}/measurements",
            "/api/v1/captures/{capture_id}/judgments",
            "/api/v1/test_sheets/{sheet_id}/ranked_results"
        ].forEach { path in
            XCTAssertTrue(specification.contains(path), "Missing OpenAPI path: \(path)")
        }
    }

    func testAPIClientUsesGeneratedClientInsteadOfHandwrittenTransportModels() throws {
        let client = try String(contentsOf: apiClientURL())

        XCTAssertTrue(client.contains("OpenAPI"), "APIClient should delegate endpoint calls to the generated client")
        XCTAssertFalse(client.contains("private struct CreateCaptureRequest"))
        XCTAssertFalse(client.contains("private struct MeasurementUploadRequest"))
        XCTAssertFalse(client.contains("private struct JudgmentUploadRequest"))
    }

    func testAPIClientExposesRankedResultsThroughTheGeneratedClient() throws {
        let client = try String(contentsOf: apiClientURL())

        XCTAssertTrue(client.contains("fetchRankedResults"))
        XCTAssertTrue(client.contains("ranked_results"))
    }

    private func packageManifest() throws -> String {
        try String(contentsOf: repositoryURL().appending(path: "iOS/Package.swift"))
    }

    private func openAPISpecificationURL() -> URL {
        repositoryURL().appending(path: "iOS/OpenAPI/openapi.json")
    }

    private func apiClientURL() -> URL {
        repositoryURL().appending(path: "iOS/Sources/ColorMatchingLPSAppCore/APIClient.swift")
    }

    private func repositoryURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
