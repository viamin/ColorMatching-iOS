import Foundation
import XCTest

final class OpenAPIClientAdoptionTests: XCTestCase {
    func testPackageGeneratesClientFromVendoredColorMatchingSpecification() throws {
        let package = try String(contentsOf: packageURL)

        XCTAssertTrue(package.contains("swift-openapi-generator"))
        XCTAssertTrue(package.contains("swift-openapi-runtime"))
        XCTAssertTrue(package.contains("openapi/color-matching.yaml"))
    }

    func testGeneratedSpecificationCoversEveryAppAPISurface() throws {
        let specification = try String(contentsOf: specificationURL)

        for path in requiredPaths {
            XCTAssertTrue(specification.contains(path), "Missing OpenAPI path: \(path)")
        }
    }

    func testAPILayerUsesGeneratedClientInsteadOfHandWrittenTransportModels() throws {
        let apiClient = try String(contentsOf: apiClientURL)

        XCTAssertFalse(apiClient.contains("private struct CreateCaptureRequest"))
        XCTAssertFalse(apiClient.contains("private struct MeasurementUploadRequest"))
        XCTAssertFalse(apiClient.contains("private struct JudgmentUploadRequest"))
        XCTAssertTrue(apiClient.contains("OpenAPI"), "The adapter should invoke the generated OpenAPI client.")
    }

    private var packageURL: URL {
        iosDirectory.appending(path: "Package.swift")
    }

    private var specificationURL: URL {
        iosDirectory.appending(path: "openapi/color-matching.yaml")
    }

    private var apiClientURL: URL {
        iosDirectory.appending(path: "Sources/ColorMatchingLPSAppCore/APIClient.swift")
    }

    private var iosDirectory: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private let requiredPaths = [
        "/api/v1/test_sheets/{sheet_id}/manifest",
        "/api/v1/test_sheets/recent",
        "/api/v1/test_sheets/{sheet_id}/captures",
        "/api/v1/captures/{capture_id}/measurements",
        "/api/v1/captures/{capture_id}/judgments",
        "/api/v1/test_sheets/{sheet_id}/ranked_results"
    ]
}
