import Foundation
import XCTest

final class OpenAPIContractTests: XCTestCase {
    func testVendoredSpecDefinesEveryAppOperationAndGeneratedClientDependencies() throws {
        let package = try String(contentsOf: packageURL(), encoding: .utf8)
        XCTAssertTrue(package.contains("swift-openapi-generator"))
        XCTAssertTrue(package.contains("swift-openapi-runtime"))

        let specification = try specificationJSON()
        let paths = try XCTUnwrap(specification["paths"] as? [String: Any])

        for path in requiredPaths {
            XCTAssertNotNil(paths[path], "Missing OpenAPI path: \(path)")
        }
    }

    func testVendoredSpecContainsTheFieldsRequiredToDecodeAndUploadAppData() throws {
        let specification = try specificationJSON()
        let components = try XCTUnwrap(specification["components"] as? [String: Any])
        let schemas = try XCTUnwrap(components["schemas"] as? [String: Any])

        XCTAssertTrue(try schema(named: "TestSheetManifest", in: schemas).contains("registration_markers"))
        XCTAssertTrue(try schema(named: "TestSheetManifest", in: schemas).contains("patches"))
        XCTAssertTrue(try schema(named: "TestSheetManifest", in: schemas).contains("pairs"))
        XCTAssertTrue(try schema(named: "TestSheetManifest", in: schemas).contains("capture_profile"))
        XCTAssertTrue(try schema(named: "RankedResults", in: schemas).contains("results"))
        XCTAssertTrue(try schema(named: "MeasurementUploadRequest", in: schemas).contains("scoring_algorithm_version"))
    }

    private var requiredPaths: [String] {
        [
            "/api/v1/test_sheets/recent",
            "/api/v1/test_sheets/{sheet_id}/manifest",
            "/api/v1/test_sheets/{sheet_id}/captures",
            "/api/v1/captures/{capture_id}/measurements",
            "/api/v1/captures/{capture_id}/judgments",
            "/api/v1/test_sheets/{sheet_id}/ranked_results"
        ]
    }

    private func packageURL() -> URL {
        packageRoot.appendingPathComponent("Package.swift")
    }

    private func specificationJSON() throws -> [String: Any] {
        let data = try Data(contentsOf: packageRoot.appendingPathComponent("OpenAPI/color-matching.openapi.json"))
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private func schema(named name: String, in schemas: [String: Any]) throws -> String {
        let data = try JSONSerialization.data(withJSONObject: schemas[name] ?? [:], options: [.sortedKeys])
        return try XCTUnwrap(String(data: data, encoding: .utf8))
    }

    private var packageRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
