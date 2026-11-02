import Foundation
import XCTest

/// Guards the vendored OpenAPI document that feeds the generated client.
///
/// The document must be vendored at `iOS/OpenAPI/color-matching-openapi.json`
/// (see `docs/ios-openapi-generated-client.md`). These tests pin the six API
/// surfaces the app consumes so that server-side drift shows up as a
/// regeneration diff and a CI failure instead of a runtime surprise.
final class OpenAPIDocumentContractTests: XCTestCase {
    private static var cachedDocument: [String: Any]?

    private func document() throws -> [String: Any] {
        if let cachedDocument = Self.cachedDocument { return cachedDocument }
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "OpenAPI/color-matching-openapi.json")
        guard FileManager.default.fileExists(atPath: url.path) else {
            XCTFail("Vendored OpenAPI document is missing at \(url.path). Fetch it from GET /api/v1/openapi.json on the color_matching server; see docs/ios-openapi-generated-client.md.")
            throw NSError(domain: "OpenAPIDocumentContract", code: 1)
        }
        let parsed = try Self.jsonObject(from: try Data(contentsOf: url))
        let doc = try XCTUnwrap(parsed as? [String: Any])
        Self.cachedDocument = doc
        return doc
    }

    func testVendoredDocumentIsAnOpenAPISpecForColorMatching() throws {
        let doc = try document()
        let version = try XCTUnwrap(doc["openapi"] as? String)
        XCTAssertTrue(version.hasPrefix("3."), "expected OpenAPI 3.x, got \(version)")
        let info = try XCTUnwrap(doc["info"] as? [String: Any])
        XCTAssertEqual(info["title"] as? String, "Color Matching API")
    }

    func testDocumentExposesTheSixSurfacesUsedByTheApp() throws {
        let expected: [String: String] = [
            "GET /api/v1/test_sheets/recent": "ColorMatchingWeb.TestSheetController.recent",
            "GET /api/v1/test_sheets/{sheet_id}/manifest": "ColorMatchingWeb.TestSheetController.manifest",
            "GET /api/v1/test_sheets/{sheet_id}/ranked_results": "ColorMatchingWeb.TestSheetController.ranked_results",
            "POST /api/v1/test_sheets/{sheet_id}/captures": "ColorMatchingWeb.CaptureController.create",
            "POST /api/v1/captures/{capture_id}/measurements": "ColorMatchingWeb.CaptureController.upload_measurements",
            "POST /api/v1/captures/{capture_id}/judgments": "ColorMatchingWeb.CaptureController.upload_judgments",
        ]
        for (surface, operationID) in expected {
            let parts = surface.split(separator: " ")
            let operation = try operationDocument(verb: String(parts[0]), path: String(parts[1]))
            XCTAssertEqual(operation["operationId"] as? String, operationID, "unexpected operationId for \(surface)")
        }
    }

    func testManifestOperationReturnsTestSheetManifestSchema() throws {
        let ref = try responseSchemaRef(verb: "get", path: "/api/v1/test_sheets/{sheet_id}/manifest", status: "200")
        XCTAssertEqual(ref, "#/components/schemas/TestSheetManifest")
    }

    func testRecentSheetsOperationReturnsRecentSheetsResponseSchema() throws {
        let ref = try responseSchemaRef(verb: "get", path: "/api/v1/test_sheets/recent", status: "200")
        XCTAssertEqual(ref, "#/components/schemas/RecentSheetsResponse")
    }

    func testRankedResultsOperationReturnsRankedResultsSchema() throws {
        let ref = try responseSchemaRef(verb: "get", path: "/api/v1/test_sheets/{sheet_id}/ranked_results", status: "200")
        XCTAssertEqual(ref, "#/components/schemas/RankedResults")
    }

    func testCreateCaptureExpectsCaptureRequestAndReturns201WithCaptureID() throws {
        let operation = try operationDocument(verb: "post", path: "/api/v1/test_sheets/{sheet_id}/captures")
        let requestRef = try XCTUnwrap(
            Self.value(at: ["requestBody", "content", "application/json", "schema", "$ref"], in: operation) as? String
        )
        XCTAssertEqual(requestRef, "#/components/schemas/CaptureRequest")
        let responseRef = try responseSchemaRef(
            verb: "post",
            path: "/api/v1/test_sheets/{sheet_id}/captures",
            status: "201"
        )
        XCTAssertEqual(responseRef, "#/components/schemas/CaptureCreatedResponse")
    }

    func testUploadMeasurementsReturns200WithCountedResponseNotNoContent() throws {
        let operation = try operationDocument(verb: "post", path: "/api/v1/captures/{capture_id}/measurements")
        let requestRef = try XCTUnwrap(
            Self.value(at: ["requestBody", "content", "application/json", "schema", "$ref"], in: operation) as? String
        )
        XCTAssertEqual(requestRef, "#/components/schemas/MeasurementUploadRequest")
        let responseRef = try responseSchemaRef(
            verb: "post",
            path: "/api/v1/captures/{capture_id}/measurements",
            status: "200"
        )
        XCTAssertEqual(responseRef, "#/components/schemas/MeasurementUploadResponse")
        let responses = try XCTUnwrap(operation["responses"] as? [String: Any])
        XCTAssertNil(responses["204"], "measurement upload now returns 200 with a JSON body, not 204")
    }

    func testUploadJudgmentsReturns200WithCountedResponse() throws {
        let operation = try operationDocument(verb: "post", path: "/api/v1/captures/{capture_id}/judgments")
        let requestRef = try XCTUnwrap(
            Self.value(at: ["requestBody", "content", "application/json", "schema", "$ref"], in: operation) as? String
        )
        XCTAssertEqual(requestRef, "#/components/schemas/JudgmentUploadRequest")
        let responseRef = try responseSchemaRef(
            verb: "post",
            path: "/api/v1/captures/{capture_id}/judgments",
            status: "200"
        )
        XCTAssertEqual(responseRef, "#/components/schemas/JudgmentUploadResponse")
    }

    func testBearerSecuritySchemeIsDeclared() throws {
        let doc = try document()
        let schemes = try XCTUnwrap(Self.value(at: ["components", "securitySchemes"], in: doc) as? [String: Any])
        let bearer = try XCTUnwrap(schemes["bearerAuth"] as? [String: Any])
        XCTAssertEqual(bearer["type"] as? String, "http")
        XCTAssertEqual(bearer["scheme"] as? String, "bearer")
    }

    func testComponentSchemasUsedByTheAppExist() throws {
        let doc = try document()
        let schemas = try XCTUnwrap(Self.value(at: ["components", "schemas"], in: doc) as? [String: Any])
        let expected = [
            "TestSheetManifest",
            "RankedResults",
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
        ]
        for name in expected {
            XCTAssertNotNil(schemas[name], "components/schemas is missing \(name)")
        }
    }

    func testPathParametersKeepSnakeCaseNames() throws {
        let sheetOperations = [
            try operationDocument(verb: "get", path: "/api/v1/test_sheets/{sheet_id}/manifest"),
            try operationDocument(verb: "get", path: "/api/v1/test_sheets/{sheet_id}/ranked_results"),
            try operationDocument(verb: "post", path: "/api/v1/test_sheets/{sheet_id}/captures"),
        ]
        for operation in sheetOperations {
            XCTAssertTrue(Self.hasPathParameter(named: "sheet_id", in: operation))
        }
        let captureOperations = [
            try operationDocument(verb: "post", path: "/api/v1/captures/{capture_id}/measurements"),
            try operationDocument(verb: "post", path: "/api/v1/captures/{capture_id}/judgments"),
        ]
        for operation in captureOperations {
            XCTAssertTrue(Self.hasPathParameter(named: "capture_id", in: operation))
        }
    }

    private func operationDocument(verb: String, path: String) throws -> [String: Any] {
        let doc = try document()
        let paths = try XCTUnwrap(doc["paths"] as? [String: Any], "document has no paths")
        let pathItem = try XCTUnwrap(paths[path] as? [String: Any], "document has no path \(path)")
        return try XCTUnwrap(pathItem[verb] as? [String: Any], "path \(path) has no \(verb) operation")
    }

    private func responseSchemaRef(verb: String, path: String, status: String) throws -> String {
        let operation = try operationDocument(verb: verb, path: path)
        let ref = try XCTUnwrap(
            Self.value(at: ["responses", status, "content", "application/json", "schema", "$ref"], in: operation) as? String,
            "\(verb) \(path) is missing a \(status) application/json schema ref"
        )
        return ref
    }

    private static func hasPathParameter(named name: String, in operation: [String: Any]) -> Bool {
        guard let parameters = operation["parameters"] as? [[String: Any]] else { return false }
        return parameters.contains { parameter in
            (parameter["name"] as? String) == name && (parameter["in"] as? String) == "path"
        }
    }

    private static func value(at keyPath: [String], in json: Any) -> Any? {
        keyPath.reduce(json) { current, key in
            (current as? [String: Any])?[key]
        }
    }

    private static func jsonObject(from data: Data) throws -> Any {
        try JSONSerialization.jsonObject(with: data)
    }
}
