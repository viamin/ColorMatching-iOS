import Foundation
import XCTest

final class OpenAPISpecCoverageTests: XCTestCase {
    private static let vendoredSpecURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appending(path: "OpenAPI/color-matching.json")

    func testVendoredSpecDocumentExists() throws {
        let url = Self.vendoredSpecURL
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: url.path),
            "The OpenAPI document published by viamin/color_matching (GET /api/v1/openapi.json, merged in viamin/color_matching#113) must be vendored at iOS/OpenAPI/color-matching.json"
        )
        _ = try specDocument()
    }

    func testSpecDescribesEverySurfaceTheAppUses() throws {
        let spec = try specDocument()
        XCTAssertEqual(try XCTUnwrap(spec["info"] as? [String: Any])["title"] as? String, "Color Matching API")
        XCTAssertTrue(try XCTUnwrap(spec["openapi"] as? String).hasPrefix("3."))

        XCTAssertNoThrow(try operation("get", "/api/v1/test_sheets/recent", in: spec))
        XCTAssertNoThrow(try operation("get", "/api/v1/test_sheets/{sheet_id}/manifest", in: spec))
        XCTAssertNoThrow(try operation("get", "/api/v1/test_sheets/{sheet_id}/ranked_results", in: spec))
        XCTAssertNoThrow(try operation("post", "/api/v1/test_sheets/{sheet_id}/captures", in: spec))
        XCTAssertNoThrow(try operation("post", "/api/v1/captures/{capture_id}/measurements", in: spec))
        XCTAssertNoThrow(try operation("post", "/api/v1/captures/{capture_id}/judgments", in: spec))
    }

    func testSpecPinsCompatibilityVersions() throws {
        let spec = try specDocument()
        XCTAssertTrue(
            try enumValues(of: "TestSheetManifest", property: "schema_version", in: spec).contains("lps-sheet-manifest/v1"),
            "TestSheetManifest.schema_version must pin the lps-sheet-manifest/v1 compatibility version"
        )
        XCTAssertTrue(
            try enumValues(of: "RankedResults", property: "schema_version", in: spec).contains("lps-ranked-results/v1"),
            "RankedResults.schema_version must pin the lps-ranked-results/v1 compatibility version"
        )
        let manifest = try schema("TestSheetManifest", in: spec)
        let captureProfile = try XCTUnwrap(
            (manifest["properties"] as? [String: Any])?["capture_profile"] as? [String: Any]
        )
        let scoringVersion = try XCTUnwrap(
            ((captureProfile["properties"] as? [String: Any])?["scoring_algorithm_version"] as? [String: Any])
        )
        XCTAssertEqual((scoringVersion["enum"] as? [String]) ?? [], ["lps-distance-v1"])
    }

    func testSpecDeclaresUploadResponses() throws {
        let spec = try specDocument()
        XCTAssertTrue(
            try requiredFields(of: "CaptureCreatedResponse", in: spec).contains("capture_id"),
            "CaptureCreatedResponse must require capture_id"
        )
        let measurementRequired = try requiredFields(of: "MeasurementUploadResponse", in: spec)
        XCTAssertTrue(measurementRequired.contains("capture_id"))
        XCTAssertTrue(measurementRequired.contains("measurement_count"))
        XCTAssertTrue(measurementRequired.contains("pair_score_count"))

        let judgmentRequired = try requiredFields(of: "JudgmentUploadResponse", in: spec)
        XCTAssertTrue(judgmentRequired.contains("capture_id"))
        XCTAssertTrue(judgmentRequired.contains("judgment_count"))
    }

    func testSpecDeclaresBearerAuthentication() throws {
        let spec = try specDocument()
        let components = try XCTUnwrap(spec["components"] as? [String: Any])
        let schemes = try XCTUnwrap(components["securitySchemes"] as? [String: Any])
        let bearer = try XCTUnwrap(schemes["bearerAuth"] as? [String: Any])
        XCTAssertEqual(bearer["type"] as? String, "http")
        XCTAssertEqual(bearer["scheme"] as? String, "bearer")
    }

    private func specDocument(file: StaticString = #filePath, line: UInt = #line) throws -> [String: Any] {
        let data: Data
        do {
            data = try Data(contentsOf: Self.vendoredSpecURL)
        } catch {
            XCTFail("Cannot read vendored OpenAPI document at \(Self.vendoredSpecURL.path): \(error)", file: file, line: line)
            throw error
        }
        do {
            return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        } catch {
            XCTFail("Vendored OpenAPI document is not valid JSON: \(error)", file: file, line: line)
            throw error
        }
    }

    private func operation(_ method: String, _ path: String, in spec: [String: Any], file: StaticString = #filePath, line: UInt = #line) throws -> [String: Any] {
        let paths = try XCTUnwrap(spec["paths"] as? [String: Any], file: file, line: line)
        let pathItem = try XCTUnwrap(paths[path] as? [String: Any], "Spec is missing path \(path)", file: file, line: line)
        return try XCTUnwrap(pathItem[method] as? [String: Any], "Spec is missing \(method.uppercased()) \(path)", file: file, line: line)
    }

    private func schema(_ name: String, in spec: [String: Any], file: StaticString = #filePath, line: UInt = #line) throws -> [String: Any] {
        let components = try XCTUnwrap(spec["components"] as? [String: Any], file: file, line: line)
        let schemas = try XCTUnwrap(components["schemas"] as? [String: Any], file: file, line: line)
        return try XCTUnwrap(schemas[name] as? [String: Any], "Spec is missing schema \(name)", file: file, line: line)
    }

    private func requiredFields(of schemaName: String, in spec: [String: Any]) throws -> [String] {
        let schema = try schema(schemaName, in: spec)
        return (schema["required"] as? [String]) ?? []
    }

    private func enumValues(of schemaName: String, property: String, in spec: [String: Any]) throws -> [String] {
        let schema = try schema(schemaName, in: spec)
        let properties = try XCTUnwrap(schema["properties"] as? [String: Any])
        let propertySchema = try XCTUnwrap(properties[property] as? [String: Any])
        return (propertySchema["enum"] as? [String]) ?? []
    }
}
