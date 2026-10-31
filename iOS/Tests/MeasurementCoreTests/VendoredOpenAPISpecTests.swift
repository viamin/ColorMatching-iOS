import Foundation
import XCTest

final class VendoredOpenAPISpecTests: XCTestCase {
    func testVendoredSpecCoversAppSurfaces() throws {
        let specFile = Self.packageRoot
            .appendingPathComponent("Sources/ColorMatchingOpenAPI/openapi.json")

        XCTAssertTrue(
            FileManager.default.fileExists(atPath: specFile.path),
            "Missing vendored OpenAPI document at \(specFile.path)"
        )

        let spec = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(contentsOf: specFile)) as? [String: Any]
        )
        let version = try XCTUnwrap(spec["openapi"] as? String)
        XCTAssertTrue(version.hasPrefix("3."), "Expected an OpenAPI 3 document, got \(version)")

        let paths = Set(((spec["paths"] as? [String: Any]) ?? [:]).keys)
        let appSurfaces = [
            "/api/v1/test_sheets/recent",
            "/api/v1/test_sheets/{sheet_id}/manifest",
            "/api/v1/test_sheets/{sheet_id}/ranked_results",
            "/api/v1/test_sheets/{sheet_id}/captures",
            "/api/v1/captures/{capture_id}/measurements",
            "/api/v1/captures/{capture_id}/judgments",
        ]
        for surface in appSurfaces {
            XCTAssertTrue(paths.contains(surface), "Vendored spec is missing app surface \(surface)")
        }

        let schemas = Set(((((spec["components"] as? [String: Any]) ?? [:])["schemas"] as? [String: Any]) ?? [:]).keys)
        let appSchemas = [
            "TestSheetManifest",
            "RankedResults",
            "RecentSheetsResponse",
            "CaptureMetadata",
            "CaptureRequest",
            "CaptureCreatedResponse",
            "MeasurementUploadRequest",
            "MeasurementUploadResponse",
            "JudgmentUploadRequest",
            "JudgmentUploadResponse",
        ]
        for schema in appSchemas {
            XCTAssertTrue(schemas.contains(schema), "Vendored spec is missing schema \(schema)")
        }
    }

    func testGeneratorConfigExposesPublicAccessLevels() throws {
        let configFile = Self.packageRoot
            .appendingPathComponent("Sources/ColorMatchingOpenAPI/openapi-generator-config.yaml")

        XCTAssertTrue(
            FileManager.default.fileExists(atPath: configFile.path),
            "Missing OpenAPI generator config at \(configFile.path)"
        )

        let config = try String(contentsOf: configFile, encoding: .utf8)
        XCTAssertTrue(
            config.contains("public"),
            "Generated types must use public access so the wrapper can re-export them"
        )
    }

    private static var packageRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
