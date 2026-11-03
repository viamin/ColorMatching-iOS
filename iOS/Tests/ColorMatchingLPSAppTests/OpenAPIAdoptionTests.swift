import Foundation
import XCTest

final class OpenAPIAdoptionTests: XCTestCase {
    func testPackageAndVendoredSpecCoverTheAppAPI() throws {
        let package = try String(contentsOf: packageURL, encoding: .utf8)
        XCTAssertTrue(package.contains("swift-openapi-generator"))
        XCTAssertTrue(package.contains("swift-openapi-runtime"))

        let data = try XCTUnwrap(
            try? Data(contentsOf: openAPIURL),
            "Vendor the OpenAPI document from color_matching at iOS/OpenAPI/color-matching.json."
        )
        let document = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let paths = try XCTUnwrap(document["paths"] as? [String: Any])

        for path in requiredPaths {
            XCTAssertNotNil(paths[path], "Missing required OpenAPI path: \(path)")
        }
    }

    private var packageURL: URL {
        iosDirectory.appending(path: "Package.swift")
    }

    private var openAPIURL: URL {
        iosDirectory.appending(path: "OpenAPI/color-matching.json")
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
