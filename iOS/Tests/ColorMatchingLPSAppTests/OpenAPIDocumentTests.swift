import Foundation
import XCTest

/// Guards the vendored OpenAPI document that drives the generated client.
///
/// The document is vendored at `iOS/ColorMatchingAPI/openapi.json` and is the
/// input to the `swift-openapi-generator` build plugin. These tests fail
/// whenever the vendored document is missing, no longer covers a surface the
/// app uses, or renames an operation in a way that would silently change the
/// generated Swift API.
///
/// The operation IDs asserted here are the canonical, clean identifiers the
/// vendoring step must produce (the live spec served by `color_matching`
/// derives controller-qualified IDs such as
/// `ColorMatchingWeb.TestSheetController.manifest`; vendoring overrides them).
final class OpenAPIDocumentTests: XCTestCase {
    func testVendoredSpecExistsAndParsesAsOpenAPIDocument() throws {
        let spec = try Self.loadedSpec()
        let version = try XCTUnwrap(spec["openapi"] as? String)
        XCTAssertTrue(version.hasPrefix("3."), "expected an OpenAPI 3.x document, got \(version)")
        XCTAssertNotNil(spec["paths"] as? [String: Any])
    }

    func testSpecCoversAppSurfacesWithStableOperationIDs() throws {
        let spec = try Self.loadedSpec()
        let expected: [String: [String: String]] = [
            "/api/v1/test_sheets/{sheet_id}/manifest": ["get": "getTestSheetManifest"],
            "/api/v1/test_sheets/recent": ["get": "listRecentSheets"],
            "/api/v1/test_sheets/{sheet_id}/ranked_results": ["get": "getRankedResults"],
            "/api/v1/test_sheets/{sheet_id}/captures": ["post": "createCapture"],
            "/api/v1/captures/{capture_id}/measurements": ["post": "uploadMeasurements"],
            "/api/v1/captures/{capture_id}/judgments": ["post": "uploadJudgments"],
        ]

        let paths = try XCTUnwrap(spec["paths"] as? [String: Any])
        for (path, verbsByID) in expected {
            let pathItem = try XCTUnwrap(paths[path] as? [String: Any], "missing path \(path)")
            for (verb, operationID) in verbsByID {
                let operation = try XCTUnwrap(pathItem[verb] as? [String: Any], "missing \(verb.uppercased()) \(path)")
                XCTAssertEqual(operation["operationId"] as? String, operationID, "\(verb.uppercased()) \(path)")
            }
        }
    }

    func testSpecUsesBearerAuthSecurityScheme() throws {
        let spec = try Self.loadedSpec()
        let components = try XCTUnwrap(spec["components"] as? [String: Any])
        let schemes = try XCTUnwrap(components["securitySchemes"] as? [String: Any])
        let bearer = try XCTUnwrap(schemes["bearerAuth"] as? [String: Any])
        XCTAssertEqual(bearer["type"] as? String, "http")
        XCTAssertEqual(bearer["scheme"] as? String, "bearer")
    }

    func testSpecDefinesComponentSchemasForAppSurfaces() throws {
        let spec = try Self.loadedSpec()
        let schemas = try XCTUnwrap((spec["components"] as? [String: Any])?["schemas"] as? [String: Any])
        let requiredSchemas = [
            "TestSheetManifest",
            "RecentSheetsResponse",
            "CaptureMetadata",
            "CaptureRequest",
            "CaptureCreatedResponse",
            "RgbPayload",
            "PairScoreRequest",
            "MeasurementUploadRequest",
            "MeasurementUploadResponse",
            "JudgmentUploadRequest",
            "JudgmentUploadResponse",
            "RankedResults",
            "ApiErrorResponse",
        ]
        for name in requiredSchemas {
            XCTAssertNotNil(schemas[name], "spec is missing component schema \(name)")
        }
    }

    func testManifestSchemaPinsVersionedCompatibilityStrings() throws {
        let spec = try Self.loadedSpec()
        let manifest = try Self.schema(named: "TestSheetManifest", in: spec)
        let required = try XCTUnwrap(manifest["required"] as? [String])
        for field in ["schema_version", "sheet_id", "capture_profile"] {
            XCTAssertTrue(required.contains(field), "TestSheetManifest must require \(field)")
        }

        let schemaVersion = try Self.property("schema_version", of: manifest)
        XCTAssertEqual(schemaVersion["enum"] as? [String], ["lps-sheet-manifest/v1"])

        let captureProfile = try Self.property("capture_profile", of: manifest)
        XCTAssertTrue(try Self.isRequired("scoring_algorithm_version", in: captureProfile))
        let scoring = try Self.property("scoring_algorithm_version", of: captureProfile)
        XCTAssertEqual(scoring["enum"] as? [String], ["lps-distance-v1"])
    }

    func testCaptureRequestAcceptsNestedMetadataAndQuality() throws {
        let spec = try Self.loadedSpec()
        let capture = try Self.schema(named: "CaptureRequest", in: spec)
        let metadata = try Self.property("metadata", of: capture)
        XCTAssertEqual((metadata["$ref"] as? String)?.hasSuffix("/CaptureMetadata"), true)
        let quality = try Self.property("quality", of: capture)
        for field in ["detected_marker_count", "blur_score", "rejections"] {
            XCTAssertNotNil((quality["properties"] as? [String: Any])?[field], "quality must define \(field)")
        }
    }

    func testMeasurementUploadAcceptsObjectRgbPayload() throws {
        let spec = try Self.loadedSpec()
        let rgb = try Self.schema(named: "RgbPayload", in: spec)
        let branches = try XCTUnwrap(rgb["anyOf"] as? [[String: Any]])
        let objectBranch = branches.first {
            guard let properties = $0["properties"] as? [String: Any] else { return false }
            return Set(properties.keys) == ["r", "g", "b"]
        }
        let branch = try XCTUnwrap(objectBranch, "RgbPayload must accept an object with r/g/b channels")
        XCTAssertEqual(Set((branch["required"] as? [String]) ?? []), ["r", "g", "b"])
    }

    func testUploadEndpointsReturnJSONCountResponses() throws {
        let spec = try Self.loadedSpec()
        let paths = try XCTUnwrap(spec["paths"] as? [String: Any])
        let measurement = try Self.operation(post: "/api/v1/captures/{capture_id}/measurements", in: paths)
        let measurementResponse = try Self.responseSchema(in: measurement, status: "200", spec: spec)
        XCTAssertEqual(
            Set((measurementResponse["required"] as? [String]) ?? []),
            ["capture_id", "measurement_count", "pair_score_count"]
        )

        let judgment = try Self.operation(post: "/api/v1/captures/{capture_id}/judgments", in: paths)
        let judgmentResponse = try Self.responseSchema(in: judgment, status: "200", spec: spec)
        XCTAssertEqual(
            Set((judgmentResponse["required"] as? [String]) ?? []),
            ["capture_id", "judgment_count"]
        )
    }

    func testRecentSheetsTitleIsRequiredButNullable() throws {
        let spec = try Self.loadedSpec()
        let recent = try Self.schema(named: "RecentSheetsResponse", in: spec)
        let sheets = try Self.property("sheets", of: recent)
        let items = try XCTUnwrap(sheets["items"] as? [String: Any])
        let title = try Self.property("title", of: items)
        XCTAssertEqual(title["nullable"] as? Bool, true, "title must allow null per the published spec")
        XCTAssertTrue(try Self.isRequired("title", in: items))
    }

    func testRankedResultsSchemaPinsVersionString() throws {
        let spec = try Self.loadedSpec()
        let ranked = try Self.schema(named: "RankedResults", in: spec)
        XCTAssertEqual(
            Set((ranked["required"] as? [String]) ?? []),
            ["schema_version", "sheet_id"]
        )
        let schemaVersion = try Self.property("schema_version", of: ranked)
        XCTAssertEqual(schemaVersion["enum"] as? [String], ["lps-ranked-results/v1"])
    }
}

private extension OpenAPIDocumentTests {
    struct MissingSpecError: Error {}

    /// `#filePath` is `.../iOS/Tests/ColorMatchingLPSAppTests/<this file>`, so
    /// the package root is three levels up and the vendored document lives in
    /// the generated-client target directory.
    static var specURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("ColorMatchingAPI/openapi.json")
    }

    static func loadedSpec(file: StaticString = #filePath, line: UInt = #line) throws -> [String: Any] {
        let data: Data
        let object: Any
        do {
            data = try Data(contentsOf: specURL)
            object = try JSONSerialization.jsonObject(with: data)
        } catch {
            XCTFail(
                """
                Vendored OpenAPI document missing or unparseable at \(specURL.path). \
                Fetch the spec published by viamin/color_matching#110, override the \
                operation IDs, and vendor it (see docs/openapi-generated-client.md): \(error)
                """,
                file: file,
                line: line
            )
            throw MissingSpecError()
        }
        return try XCTUnwrap(object as? [String: Any], "spec must be a JSON object")
    }

    static func schema(named name: String, in spec: [String: Any]) throws -> [String: Any] {
        let schemas = try XCTUnwrap((spec["components"] as? [String: Any])?["schemas"] as? [String: Any])
        return try XCTUnwrap(schemas[name] as? [String: Any], "missing schema \(name)")
    }

    static func property(_ name: String, of schema: [String: Any]) throws -> [String: Any] {
        let properties = try XCTUnwrap(schema["properties"] as? [String: Any], "schema has no properties")
        return try XCTUnwrap(properties[name] as? [String: Any], "missing property \(name)")
    }

    static func isRequired(_ name: String, in schema: [String: Any]) throws -> Bool {
        try XCTUnwrap(schema["required"] as? [String]).contains(name)
    }

    static func operation(post path: String, in paths: [String: Any]) throws -> [String: Any] {
        let pathItem = try XCTUnwrap(paths[path] as? [String: Any], "missing path \(path)")
        return try XCTUnwrap(pathItem["post"] as? [String: Any], "missing POST \(path)")
    }

    static func responseSchema(in operation: [String: Any], status: String, spec: [String: Any]) throws -> [String: Any] {
        let responses = try XCTUnwrap(operation["responses"] as? [String: Any])
        let response = try XCTUnwrap(responses[status] as? [String: Any], "missing \(status) response")
        let content = try XCTUnwrap(response["content"] as? [String: Any])
        let json = try XCTUnwrap(content["application/json"] as? [String: Any])
        let schema = try XCTUnwrap(json["schema"] as? [String: Any])
        guard let reference = schema["$ref"] as? String else { return schema }
        let name = reference.replacingOccurrences(of: "#/components/schemas/", with: "")
        return try schema(named: name, in: spec)
    }
}
