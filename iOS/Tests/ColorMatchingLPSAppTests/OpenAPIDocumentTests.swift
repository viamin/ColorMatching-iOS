import Foundation
import XCTest

final class OpenAPIDocumentTests: XCTestCase {
    private struct ExpectedOperation {
        let path: String
        let method: String
        let operationID: String
    }

    private let usedOperations = [
        ExpectedOperation(path: "/api/v1/test_sheets/{sheet_id}/manifest", method: "get", operationID: "getTestSheetManifest"),
        ExpectedOperation(path: "/api/v1/test_sheets/recent", method: "get", operationID: "listRecentTestSheets"),
        ExpectedOperation(path: "/api/v1/test_sheets/{sheet_id}/captures", method: "post", operationID: "createCapture"),
        ExpectedOperation(path: "/api/v1/captures/{capture_id}/measurements", method: "post", operationID: "uploadMeasurements"),
        ExpectedOperation(path: "/api/v1/captures/{capture_id}/judgments", method: "post", operationID: "uploadJudgments"),
        ExpectedOperation(path: "/api/v1/test_sheets/{sheet_id}/ranked_results", method: "get", operationID: "getRankedResults")
    ]

    func testVendoredSpecExistsAndDeclaresOpenAPI3() throws {
        let spec = try Self.specDocument()
        let version = try XCTUnwrap(spec["openapi"] as? String)
        XCTAssertTrue(version.hasPrefix("3."), "vendored spec must be OpenAPI 3, got \(version)")
    }

    func testVendoredSpecCoversEveryEndpointUsedByTheApp() throws {
        let spec = try Self.specDocument()
        for operation in usedOperations {
            let methodOperation = try Self.operation(operation.method, operation.path, in: spec)
            let operationID = try XCTUnwrap(methodOperation["operationId"] as? String)
            XCTAssertEqual(operationID, operation.operationID, "\(operation.method) \(operation.path)")
        }
    }

    func testVendoredSpecServesItselfAndDeclaresBearerAuth() throws {
        let spec = try Self.specDocument()
        _ = try Self.operation("get", "/api/v1/openapi.json", in: spec)
        let components = try XCTUnwrap(spec["components"] as? [String: Any])
        let schemes = try XCTUnwrap(components["securitySchemes"] as? [String: Any])
        let bearer = try XCTUnwrap(schemes["bearerAuth"] as? [String: Any])
        XCTAssertEqual(bearer["scheme"] as? String, "bearer")
    }

    func testVendoredSpecKeepsCompatibilityVersionsMachineVisible() throws {
        let spec = try Self.specDocument()
        try Self.assertEnumValue("lps-sheet-manifest/v1", schema: "TestSheetManifest", property: "schema_version", in: spec)
        try Self.assertEnumValue("lps-ranked-results/v1", schema: "RankedResults", property: "schema_version", in: spec)
        try Self.assertEnumValue(
            "lps-distance-v1",
            schema: "TestSheetManifest",
            property: "scoring_algorithm_version",
            parentProperty: "capture_profile",
            in: spec
        )
    }

    func testVendoredSpecTypesUploadResponsesTheProseContractOmitted() throws {
        let spec = try Self.specDocument()
        try Self.assertRequired(["capture_id", "measurement_count", "pair_score_count"], schema: "MeasurementUploadResponse", in: spec)
        try Self.assertRequired(["capture_id", "judgment_count"], schema: "JudgmentUploadResponse", in: spec)
        try Self.assertRequired(["capture_id"], schema: "CaptureCreatedResponse", in: spec)
    }

    private static func specDocument() throws -> [String: Any] {
        let url = URL(fileURLWithPath: repoFile("iOS/OpenAPI/color-matching-openapi.json"))
        let data = try Data(contentsOf: url)
        let object = try JSONSerialization.jsonObject(with: data)
        return try XCTUnwrap(object as? [String: Any])
    }

    private static func repoFile(_ relativePath: String) -> String {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(relativePath)
            .path
    }

    private static func operation(_ method: String, _ path: String, in spec: [String: Any]) throws -> [String: Any] {
        let paths = try XCTUnwrap(spec["paths"] as? [String: Any])
        let pathItem = try XCTUnwrap(paths[path] as? [String: Any])
        return try XCTUnwrap(pathItem[method] as? [String: Any])
    }

    private static func schema(_ name: String, in spec: [String: Any]) throws -> [String: Any] {
        let components = try XCTUnwrap(spec["components"] as? [String: Any])
        let schemas = try XCTUnwrap(components["schemas"] as? [String: Any])
        return try XCTUnwrap(schemas[name] as? [String: Any])
    }

    private static func assertRequired(_ fields: [String], schema name: String, in spec: [String: Any]) throws {
        let schema = try Self.schema(name, in: spec)
        let required = try XCTUnwrap(schema["required"] as? [String])
        for field in fields {
            XCTAssertTrue(required.contains(field), "\(name) must require \(field)")
        }
    }

    private static func assertEnumValue(
        _ value: String,
        schema name: String,
        property: String,
        parentProperty: String? = nil,
        in spec: [String: Any]
    ) throws {
        var schema = try Self.schema(name, in: spec)
        if let parentProperty {
            let properties = try XCTUnwrap(schema["properties"] as? [String: Any])
            schema = try XCTUnwrap(properties[parentProperty] as? [String: Any])
        }
        let properties = try XCTUnwrap(schema["properties"] as? [String: Any])
        let propertySchema = try XCTUnwrap(properties[property] as? [String: Any])
        let values = try XCTUnwrap(propertySchema["enum"] as? [String])
        XCTAssertTrue(values.contains(value), "\(name).\(property) enum must contain \(value), got \(values)")
    }
}
