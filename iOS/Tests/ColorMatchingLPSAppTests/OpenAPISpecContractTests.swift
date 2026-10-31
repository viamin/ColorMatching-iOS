import Foundation
import XCTest

/// Pins the vendored OpenAPI document (`Fixtures/openapi.json`) to the
/// `/api/v1` surfaces the iOS companion app consumes, as published by
/// viamin/color_matching#110 (spec served at `GET /api/v1/openapi.json`).
///
/// These structural assertions are the drift tripwire between the published
/// spec and this app: when the vendored document is refreshed from the server,
/// any change to the app-facing operations or schemas must be acknowledged here
/// (and in `GeneratedClientContractTests`) before CI passes.
///
/// The delta record between the prose contract
/// (`docs/color-matching-api-contract.md`) and this document lives in
/// `docs/openapi-contract-deltas.md`.
final class OpenAPISpecContractTests: XCTestCase {

    // MARK: - Document

    func testVendoredDocumentIsOpenAPI30WithBearerAuth() throws {
        let document = try Self.loadDocument()
        XCTAssertEqual(document["openapi"] as? String, "3.0.3")
        let info = try XCTUnwrap(document["info"] as? [String: Any])
        XCTAssertEqual(info["title"] as? String, "Color Matching API")
        XCTAssertEqual(info["version"] as? String, "v1")

        let components = try XCTUnwrap(document["components"] as? [String: Any])
        let securitySchemes = try XCTUnwrap(components["securitySchemes"] as? [String: Any])
        let bearerAuth = try XCTUnwrap(securitySchemes["bearerAuth"] as? [String: Any])
        XCTAssertEqual(bearerAuth["type"] as? String, "http")
        XCTAssertEqual(bearerAuth["scheme"] as? String, "bearer")
    }

    func testVendoredDocumentCoversExactlyTheAppFacingOperations() throws {
        let document = try Self.loadDocument()
        let paths = try XCTUnwrap(document["paths"] as? [String: Any])
        XCTAssertEqual(Set(paths.keys), Set([
            "/api/v1/test_sheets/recent",
            "/api/v1/test_sheets/{sheet_id}/manifest",
            "/api/v1/test_sheets/{sheet_id}/ranked_results",
            "/api/v1/test_sheets/{sheet_id}/captures",
            "/api/v1/captures/{capture_id}/measurements",
            "/api/v1/captures/{capture_id}/judgments",
        ]))

        let expectedOperations = [
            ("/api/v1/test_sheets/recent", "get", "listRecentTestSheets"),
            ("/api/v1/test_sheets/{sheet_id}/manifest", "get", "getTestSheetManifest"),
            ("/api/v1/test_sheets/{sheet_id}/ranked_results", "get", "getRankedResults"),
            ("/api/v1/test_sheets/{sheet_id}/captures", "post", "createCapture"),
            ("/api/v1/captures/{capture_id}/measurements", "post", "uploadMeasurements"),
            ("/api/v1/captures/{capture_id}/judgments", "post", "uploadJudgments"),
        ]
        for (path, method, operationID) in expectedOperations {
            let operation = try Self.operation(path, method, in: document)
            XCTAssertEqual(operation["operationId"] as? String, operationID)
            XCTAssertEqual(operation["security"] as? [[String: [String]]], [["bearerAuth": []]])
        }
    }

    // MARK: - Test-sheet reads

    func testManifestOperationReturnsVersionedManifestWithSheetID() throws {
        let document = try Self.loadDocument()
        let operation = try Self.operation("/api/v1/test_sheets/{sheet_id}/manifest", "get", in: document)

        let parameter = try XCTUnwrap((operation["parameters"] as? [[String: Any]])?.first)
        XCTAssertEqual(parameter["name"] as? String, "sheet_id")
        XCTAssertEqual(parameter["in"] as? String, "path")
        XCTAssertEqual(parameter["required"] as? Bool, true)

        XCTAssertEqual(Set(Self.responseStatusCodes(operation)), ["200", "401", "404"])
        XCTAssertEqual(try Self.responseSchemaName(operation, status: "200"), "TestSheetManifest")

        let manifest = try Self.schema("TestSheetManifest", in: document)
        XCTAssertEqual(manifest["required"] as? [String], ["schema_version", "sheet_id", "capture_profile"])
        let schemaVersion = try XCTUnwrap((manifest["properties"] as? [String: Any])?["schema_version"] as? [String: Any])
        XCTAssertEqual(schemaVersion["enum"] as? [String], ["lps-sheet-manifest/v1"])

        let captureProfile = try XCTUnwrap((manifest["properties"] as? [String: Any])?["capture_profile"] as? [String: Any])
        XCTAssertEqual(captureProfile["required"] as? [String], ["scoring_algorithm_version"])
        let scoringVersion = try XCTUnwrap((captureProfile["properties"] as? [String: Any])?["scoring_algorithm_version"] as? [String: Any])
        XCTAssertEqual(scoringVersion["enum"] as? [String], ["lps-distance-v1"])
    }

    func testRecentSheetsOperationReturnsNullableTitles() throws {
        let document = try Self.loadDocument()
        let operation = try Self.operation("/api/v1/test_sheets/recent", "get", in: document)

        XCTAssertEqual(Set(Self.responseStatusCodes(operation)), ["200", "401"])
        XCTAssertEqual(try Self.responseSchemaName(operation, status: "200"), "RecentSheetsResponse")

        let recent = try Self.schema("RecentSheetsResponse", in: document)
        XCTAssertEqual(recent["required"] as? [String], ["sheets"])
        let sheets = try XCTUnwrap((recent["properties"] as? [String: Any])?["sheets"] as? [String: Any])
        let sheet = try XCTUnwrap(sheets["items"] as? [String: Any])
        XCTAssertEqual(sheet["required"] as? [String], ["sheet_id", "manifest_url", "title"])
        let title = try XCTUnwrap((sheet["properties"] as? [String: Any])?["title"] as? [String: Any])
        XCTAssertEqual(title["nullable"] as? Bool, true)
    }

    func testRankedResultsOperationReturnsVersionedStub() throws {
        let document = try Self.loadDocument()
        let operation = try Self.operation("/api/v1/test_sheets/{sheet_id}/ranked_results", "get", in: document)

        XCTAssertEqual(Set(Self.responseStatusCodes(operation)), ["200", "401", "404"])
        XCTAssertEqual(try Self.responseSchemaName(operation, status: "200"), "RankedResults")

        let ranked = try Self.schema("RankedResults", in: document)
        XCTAssertEqual(ranked["required"] as? [String], ["schema_version", "sheet_id"])
        let schemaVersion = try XCTUnwrap((ranked["properties"] as? [String: Any])?["schema_version"] as? [String: Any])
        XCTAssertEqual(schemaVersion["enum"] as? [String], ["lps-ranked-results/v1"])
    }

    // MARK: - Capture session creation

    func testCreateCaptureOperationAcceptsNestedMetadataAndQuality() throws {
        let document = try Self.loadDocument()
        let operation = try Self.operation("/api/v1/test_sheets/{sheet_id}/captures", "post", in: document)

        XCTAssertEqual(
            try Self.requestBodySchemaName(operation), "CaptureRequest",
            "capture creation must accept the nested metadata/quality shape the app sends today")
        XCTAssertEqual(Set(Self.responseStatusCodes(operation)), ["201", "401", "404", "422"])
        XCTAssertEqual(try Self.responseSchemaName(operation, status: "201"), "CaptureCreatedResponse")

        let captureRequest = try Self.schema("CaptureRequest", in: document)
        let properties = try XCTUnwrap(captureRequest["properties"] as? [String: Any])
        XCTAssertEqual((properties["metadata"] as? [String: Any])?["$ref"] as? String, "#/components/schemas/CaptureMetadata")
        let quality = try XCTUnwrap(properties["quality"] as? [String: Any])
        XCTAssertEqual(Set((quality["properties"] as? [String: Any]).keys), ["detected_marker_count", "blur_score", "rejections"])

        let variants = try XCTUnwrap(captureRequest["anyOf"] as? [[String: Any]])
        XCTAssertEqual(variants.count, 2, "spec keeps a legacy flat variant alongside the nested metadata variant")

        let metadata = try Self.schema("CaptureMetadata", in: document)
        XCTAssertEqual(
            metadata["required"] as? [String],
            ["device_model", "lens", "image_width", "image_height", "app_version", "timestamp"])
        let timestamp = try XCTUnwrap(((metadata["properties"] as? [String: Any])?["timestamp"] as? [String: Any]))
        XCTAssertEqual(timestamp["format"] as? String, "date-time")
    }

    // MARK: - Measurement upload

    func testMeasurementUploadOperationSendsRgbPayloadsAndPairScores() throws {
        let document = try Self.loadDocument()
        let operation = try Self.operation("/api/v1/captures/{capture_id}/measurements", "post", in: document)

        XCTAssertEqual(try Self.requestBodySchemaName(operation), "MeasurementUploadRequest")
        XCTAssertEqual(Set(Self.responseStatusCodes(operation)), ["200", "401", "404", "422"])
        XCTAssertEqual(try Self.responseSchemaName(operation, status: "200"), "MeasurementUploadResponse")

        let upload = try Self.schema("MeasurementUploadRequest", in: document)
        XCTAssertNil(upload["required"], "top-level scoring_algorithm_version from the prose contract is gone in the spec")
        let properties = try XCTUnwrap(upload["properties"] as? [String: Any])
        let measurementItem = try XCTUnwrap(((properties["measurements"] as? [String: Any])?["items"] as? [String: Any]))
        XCTAssertEqual(
            measurementItem["required"] as? [String],
            ["patch_id", "linear_rgb_median", "normalized_linear_rgb_median"])
        XCTAssertNil(
            (measurementItem["properties"] as? [String: Any])?["stats"],
            "per-measurement stats from the prose contract are gone in the spec")
        let pairScores = try XCTUnwrap(properties["pair_scores"] as? [String: Any])
        XCTAssertEqual((pairScores["items"] as? [String: Any])?["$ref"] as? String, "#/components/schemas/PairScoreRequest")
    }

    func testRgbPayloadAcceptsArrayObjectAndStringForms() throws {
        let document = try Self.loadDocument()
        let rgbPayload = try Self.schema("RgbPayload", in: document)
        let variants = try XCTUnwrap(rgbPayload["anyOf"] as? [[String: Any]])
        XCTAssertEqual(variants.count, 3)
        XCTAssertEqual(variants[0]["type"] as? String, "array")
        XCTAssertEqual(variants[1]["type"] as? String, "object")
        XCTAssertEqual(Set((variants[1]["properties"] as? [String: Any]).keys), ["r", "g", "b"])
        XCTAssertEqual(variants[2]["type"] as? String, "string")
    }

    func testPairScoreRequiresExactlyOneScoreShape() throws {
        let document = try Self.loadDocument()
        let pairScore = try Self.schema("PairScoreRequest", in: document)
        XCTAssertEqual(pairScore["required"] as? [String], ["pair_id", "algorithm_version"])
        let variants = try XCTUnwrap(pairScore["anyOf"] as? [[String: Any]])
        XCTAssertEqual(
            variants.map { ($0["required"] as? [String])?.first },
            ["score", "similarity", "distance"])
    }

    func testMeasurementUploadResponseIsTypedJSONBody() throws {
        let document = try Self.loadDocument()
        let response = try Self.schema("MeasurementUploadResponse", in: document)
        XCTAssertEqual(
            response["required"] as? [String],
            ["capture_id", "measurement_count", "pair_score_count"],
            "unlike the prose contract, the spec requires a typed 200 JSON body (not a bare 2xx)")
    }

    // MARK: - Judgment upload

    func testJudgmentUploadOperationRoundTripsTypedBody() throws {
        let document = try Self.loadDocument()
        let operation = try Self.operation("/api/v1/captures/{capture_id}/judgments", "post", in: document)

        XCTAssertEqual(try Self.requestBodySchemaName(operation), "JudgmentUploadRequest")
        XCTAssertEqual(Set(Self.responseStatusCodes(operation)), ["200", "401", "404", "422"])
        XCTAssertEqual(try Self.responseSchemaName(operation, status: "200"), "JudgmentUploadResponse")

        let upload = try Self.schema("JudgmentUploadRequest", in: document)
        let judgmentItem = try XCTUnwrap((((upload["properties"] as? [String: Any])?["judgments"] as? [String: Any])?["items"] as? [String: Any]))
        XCTAssertEqual(judgmentItem["required"] as? [String], ["pair_id", "judgment"])
        let judgment = try XCTUnwrap((judgmentItem["properties"] as? [String: Any])?["judgment"] as? [String: Any])
        XCTAssertNil(judgment["enum"], "spec does not enforce the prose match/near_match/no_match enum (gap)")

        let response = try Self.schema("JudgmentUploadResponse", in: document)
        XCTAssertEqual(response["required"] as? [String], ["capture_id", "judgment_count"])
    }

    // MARK: - Documented endpoint gaps (see docs/openapi-contract-deltas.md)

    func testManifestSchemaStillOmitsSheetGeometryFieldsTheAppNeeds() throws {
        let document = try Self.loadDocument()
        let manifest = try Self.schema("TestSheetManifest", in: document)
        let properties = try XCTUnwrap(manifest["properties"] as? [String: Any])
        for missing in ["sheet_version", "manifest_url", "created_at", "page", "registration_markers", "printer_profile", "patches", "pairs"] {
            XCTAssertNil(properties[missing], """
                \(missing) is now declared in the published manifest schema. The endpoint gap recorded in \
                docs/openapi-contract-deltas.md has been closed server-side: regenerate the client, extend \
                GeneratedClientContractTests, and update the delta record.
                """)
        }
    }

    // MARK: - Helpers

    private static func loadDocument() throws -> [String: Any] {
        let fixtureURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/openapi.json")
        let data = try Data(contentsOf: fixtureURL)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private static func operation(_ path: String, _ method: String, in document: [String: Any]) throws -> [String: Any] {
        let paths = try XCTUnwrap(document["paths"] as? [String: Any])
        let pathItem = try XCTUnwrap(paths[path] as? [String: Any], "missing path \(path)")
        return try XCTUnwrap(pathItem[method] as? [String: Any], "missing \(method.uppercased()) \(path)")
    }

    private static func schema(_ name: String, in document: [String: Any]) throws -> [String: Any] {
        let components = try XCTUnwrap(document["components"] as? [String: Any])
        let schemas = try XCTUnwrap(components["schemas"] as? [String: Any])
        return try XCTUnwrap(schemas[name] as? [String: Any], "missing schema \(name)")
    }

    private static func responseStatusCodes(_ operation: [String: Any]) -> [String] {
        ((operation["responses"] as? [String: Any]) ?? [:]).keys.sorted()
    }

    private static func response(_ operation: [String: Any], status: String) throws -> [String: Any] {
        let responses = try XCTUnwrap(operation["responses"] as? [String: Any])
        return try XCTUnwrap(responses[status] as? [String: Any], "missing \(status) response")
    }

    private static func responseSchemaName(_ operation: [String: Any], status: String) throws -> String {
        let response = try self.response(operation, status: status)
        let content = try XCTUnwrap(response["content"] as? [String: Any])
        let json = try XCTUnwrap(content["application/json"] as? [String: Any])
        let reference = try XCTUnwrap(json["schema"] as? [String: Any])
        return try XCTUnwrap(reference["$ref"] as? String).replacingOccurrences(of: "#/components/schemas/", with: "")
    }

    private static func requestBodySchemaName(_ operation: [String: Any]) throws -> String {
        let requestBody = try XCTUnwrap(operation["requestBody"] as? [String: Any])
        XCTAssertEqual(requestBody["required"] as? Bool, true)
        let content = try XCTUnwrap(requestBody["content"] as? [String: Any])
        let json = try XCTUnwrap(content["application/json"] as? [String: Any])
        let reference = try XCTUnwrap(json["schema"] as? [String: Any])
        return try XCTUnwrap(reference["$ref"] as? String).replacingOccurrences(of: "#/components/schemas/", with: "")
    }
}
