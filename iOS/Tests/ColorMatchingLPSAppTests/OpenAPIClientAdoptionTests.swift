import Foundation
import XCTest

final class OpenAPIClientAdoptionTests: XCTestCase {
    func testPackageUsesOpenAPIGeneratorAndRuntime() throws {
        let package = try String(contentsOf: packageManifestURL)

        XCTAssertTrue(package.contains("swift-openapi-generator"))
        XCTAssertTrue(package.contains("swift-openapi-runtime"))
        XCTAssertTrue(package.contains("OpenAPIGenerator"))
    }

    func testVendoredOpenAPIDocumentIncludesEveryCompanionSurface() throws {
        guard FileManager.default.fileExists(atPath: openAPIDocumentURL.path) else {
            XCTFail("The generated client target must vendor openapi.json")
            return
        }

        let document = try Data(contentsOf: openAPIDocumentURL)
        let json = try XCTUnwrap(try JSONSerialization.jsonObject(with: document) as? [String: Any])
        let paths = try XCTUnwrap(json["paths"] as? [String: Any])

        for path in [
            "/api/v1/test_sheets/recent",
            "/api/v1/test_sheets/{sheet_id}/manifest",
            "/api/v1/test_sheets/{sheet_id}/captures",
            "/api/v1/captures/{capture_id}/measurements",
            "/api/v1/captures/{capture_id}/judgments",
            "/api/v1/test_sheets/{sheet_id}/ranked_results"
        ] {
            XCTAssertNotNil(paths[path], "Missing OpenAPI path: \(path)")
        }
    }

    private var packageManifestURL: URL {
        repositoryURL.appending(path: "iOS/Package.swift")
    }

    private var openAPIDocumentURL: URL {
        repositoryURL.appending(path: "iOS/Sources/ColorMatchingAPI/openapi.json")
    }

    private var repositoryURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
