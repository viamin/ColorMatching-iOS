import Foundation
import XCTest

/// Pins the vendored OpenAPI document (fetched from the published color_matching
/// spec, viamin/color_matching#110) to the surfaces the iOS companion app uses.
///
/// These assertions fail until `iOS/OpenAPI/color-matching-openapi.json` is
/// checked in, and keep failing if the server spec drifts away from the
/// surfaces this app depends on.
final class OpenAPIDocumentTests: XCTestCase {
    private static let packageRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    private static var vendoredSpecURL: URL {
        packageRoot.appendingPathComponent("OpenAPI/color-matching-openapi.json")
    }

    func testVendoredSpecIsCheckedInAndParsesAsOpenAPI3() throws {
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: Self.vendoredSpecURL.path),
            "Vendor the published OpenAPI document at iOS/OpenAPI/color-matching-openapi.json "
                + "(served by color_matching at GET /api/v1/openapi.json, viamin/color_matching#110)."
        )
        let data = try Data(contentsOf: Self.vendoredSpecURL)
        let document = try requireDictionary(JSONSerialization.jsonObject(with: data), "OpenAPI document root")
        let version = try XCTUnwrap(document["openapi"] as? String, "Document must declare an `openapi` version.")
        XCTAssertTrue(version.hasPrefix("3."), "Expected OpenAPI 3.x, found \(version).")
    }

    func testSpecCoversEveryAppSurfacePath() throws {
        let document = try loadDocument()
        let appSurfaces: [(method: String, path: String)] = [
            ("get", "/api/v1/test_sheets/recent"),
            ("get", "/api/v1/test_sheets/{sheet_id}/manifest"),
            ("get", "/api/v1/test_sheets/{sheet_id}/ranked_results"),
            ("post", "/api/v1/test_sheets/{sheet_id}/captures"),
            ("post", "/api/v1/captures/{capture_id}/measurements"),
            ("post", "/api/v1/captures/{capture_id}/judgments"),
        ]
        for surface in appSurfaces {
            _ = try operation(surface.method, surface.path, in: document)
        }
    }

    func testTemplatedOperationsDeclarePathParameters() throws {
        let document = try loadDocument()
        let templatedSurfaces: [(method: String, path: String, parameter: String)] = [
            ("get", "/api/v1/test_sheets/{sheet_id}/manifest", "sheet_id"),
            ("get", "/api/v1/test_sheets/{sheet_id}/ranked_results", "sheet_id"),
            ("post", "/api/v1/test_sheets/{sheet_id}/captures", "sheet_id"),
            ("post", "/api/v1/captures/{capture_id}/measurements", "capture_id"),
            ("post", "/api/v1/captures/{capture_id}/judgments", "capture_id"),
        ]
        for surface in templatedSurfaces {
            let operation = try self.operation(surface.method, surface.path, in: document)
            let parameters = try requireArray(operation["parameters"], "\(surface.method) \(surface.path).parameters")
            let declaresParameter = parameters.contains {
                ($0["name"] as? String) == surface.parameter && ($0["in"] as? String) == "path"
            }
            XCTAssertTrue(
                declaresParameter,
                "\(surface.method) \(surface.path) must declare path parameter {\(surface.parameter)}."
            )
        }
    }

    func testSheetSurfacesAreProtectedByBearerAuth() throws {
        let document = try loadDocument()
        let components = try requireDictionary(document["components"], "components")
        let securitySchemes = try requireDictionary(components["securitySchemes"], "components.securitySchemes")
        let bearerAuth = try requireDictionary(securitySchemes["bearerAuth"], "securitySchemes.bearerAuth")
        XCTAssertEqual(bearerAuth["type"] as? String, "http")
        XCTAssertEqual(bearerAuth["scheme"] as? String, "bearer")

        let manifest = try operation("get", "/api/v1/test_sheets/{sheet_id}/manifest", in: document)
        let security = try requireArray(manifest["security"], "manifest operation security")
        XCTAssertTrue(security.contains { $0["bearerAuth"] != nil }, "Manifest operation must require bearerAuth.")
    }

    func testManifestSchemaPinsCompatibilityVersions() throws {
        let document = try loadDocument()
        let schema = try resolveReference(
            try jsonResponseSchemaRef("200", method: "get", path: "/api/v1/test_sheets/{sheet_id}/manifest", in: document),
            in: document
        )
        XCTAssertTrue(
            requiredProperties(schema).isSuperset(of: ["schema_version", "sheet_id", "capture_profile"]),
            "TestSheetManifest must require schema_version, sheet_id and capture_profile."
        )
        let properties = try requireDictionary(schema["properties"], "TestSheetManifest.properties")
        let schemaVersion = try requireDictionary(properties["schema_version"], "schema_version")
        XCTAssertEqual(enumValues(schemaVersion), ["lps-sheet-manifest/v1"])
        let captureProfile = try requireDictionary(properties["capture_profile"], "capture_profile")
        XCTAssertTrue(
            requiredProperties(captureProfile).contains("scoring_algorithm_version"),
            "capture_profile must require scoring_algorithm_version."
        )
        let scoringVersion = try requireDictionary(
            captureProfile["scoring_algorithm_version"],
            "capture_profile.scoring_algorithm_version"
        )
        XCTAssertTrue(enumValues(scoringVersion).contains("lps-distance-v1"))
    }

    func testRecentSheetsSchemaRequiresSheetFields() throws {
        let document = try loadDocument()
        let schema = try resolveReference(
            try jsonResponseSchemaRef("200", method: "get", path: "/api/v1/test_sheets/recent", in: document),
            in: document
        )
        XCTAssertTrue(requiredProperties(schema).contains("sheets"))
        let properties = try requireDictionary(schema["properties"], "RecentSheetsResponse.properties")
        let sheets = try requireDictionary(properties["sheets"], "sheets")
        let items = try requireDictionary(sheets["items"], "sheets.items")
        XCTAssertEqual(requiredProperties(items), ["sheet_id", "manifest_url", "title"])
        let itemProperties = try requireDictionary(items["properties"], "sheets.items.properties")
        let title = try requireDictionary(itemProperties["title"], "sheets.items.properties.title")
        XCTAssertEqual(title["nullable"] as? Bool, true, "title is null when the server has no display name.")
    }

    func testCreateCaptureRequestAndResponseMatchPublishedContract() throws {
        let document = try loadDocument()
        let requestRef = try requestBodySchemaRef(
            method: "post",
            path: "/api/v1/test_sheets/{sheet_id}/captures",
            in: document
        )
        XCTAssertEqual(requestRef, "#/components/schemas/CaptureRequest")
        let requestSchema = try resolveReference(requestRef, in: document)
        let properties = try requireDictionary(requestSchema["properties"], "CaptureRequest.properties")
        let metadata = try requireDictionary(properties["metadata"], "CaptureRequest.properties.metadata")
        XCTAssertEqual(metadata["$ref"] as? String, "#/components/schemas/CaptureMetadata")
        let metadataSchema = try resolveReference("#/components/schemas/CaptureMetadata", in: document)
        XCTAssertTrue(
            requiredProperties(metadataSchema)
                .isSuperset(of: ["device_model", "lens", "image_width", "image_height", "app_version", "timestamp"]),
            "CaptureMetadata must require the fields the app always captures."
        )

        let createdRef = try jsonResponseSchemaRef(
            "201",
            method: "post",
            path: "/api/v1/test_sheets/{sheet_id}/captures",
            in: document
        )
        XCTAssertEqual(createdRef, "#/components/schemas/CaptureCreatedResponse")
        let createdSchema = try resolveReference(createdRef, in: document)
        XCTAssertEqual(requiredProperties(createdSchema), ["capture_id"])
    }

    func testMeasurementUploadMatchesPublishedContract() throws {
        let document = try loadDocument()
        let requestRef = try requestBodySchemaRef(
            method: "post",
            path: "/api/v1/captures/{capture_id}/measurements",
            in: document
        )
        XCTAssertEqual(requestRef, "#/components/schemas/MeasurementUploadRequest")
        let requestSchema = try resolveReference(requestRef, in: document)
        let properties = try requireDictionary(requestSchema["properties"], "MeasurementUploadRequest.properties")
        let measurements = try requireDictionary(properties["measurements"], "measurements")
        let measurementItems = try requireDictionary(measurements["items"], "measurements.items")
        XCTAssertTrue(
            requiredProperties(measurementItems)
                .isSuperset(of: ["patch_id", "linear_rgb_median", "normalized_linear_rgb_median"]),
            "Published contract requires normalized_linear_rgb_median on every measurement."
        )
        let pairScores = try requireDictionary(properties["pair_scores"], "pair_scores")
        let pairScoreItems = try requireDictionary(pairScores["items"], "pair_scores.items")
        XCTAssertEqual(pairScoreItems["$ref"] as? String, "#/components/schemas/PairScoreRequest")
        let pairScoreSchema = try resolveReference("#/components/schemas/PairScoreRequest", in: document)
        XCTAssertTrue(requiredProperties(pairScoreSchema).isSuperset(of: ["pair_id", "algorithm_version"]))
        XCTAssertNotNil(
            pairScoreSchema["anyOf"],
            "PairScoreRequest accepts score, similarity or distance through anyOf."
        )

        let responseRef = try jsonResponseSchemaRef(
            "200",
            method: "post",
            path: "/api/v1/captures/{capture_id}/measurements",
            in: document
        )
        XCTAssertEqual(responseRef, "#/components/schemas/MeasurementUploadResponse")
        let responseSchema = try resolveReference(responseRef, in: document)
        XCTAssertEqual(
            requiredProperties(responseSchema),
            ["capture_id", "measurement_count", "pair_score_count"],
            "Measurement upload answers 200 with accepted counts, not 204 with an empty body."
        )
    }

    func testJudgmentUploadMatchesPublishedContract() throws {
        let document = try loadDocument()
        let requestRef = try requestBodySchemaRef(
            method: "post",
            path: "/api/v1/captures/{capture_id}/judgments",
            in: document
        )
        XCTAssertEqual(requestRef, "#/components/schemas/JudgmentUploadRequest")
        let requestSchema = try resolveReference(requestRef, in: document)
        XCTAssertTrue(requiredProperties(requestSchema).contains("judgments"))
        let properties = try requireDictionary(requestSchema["properties"], "JudgmentUploadRequest.properties")
        let judgments = try requireDictionary(properties["judgments"], "judgments")
        let judgmentItems = try requireDictionary(judgments["items"], "judgments.items")
        XCTAssertEqual(requiredProperties(judgmentItems), ["pair_id", "judgment"])

        let responseRef = try jsonResponseSchemaRef(
            "200",
            method: "post",
            path: "/api/v1/captures/{capture_id}/judgments",
            in: document
        )
        XCTAssertEqual(responseRef, "#/components/schemas/JudgmentUploadResponse")
        let responseSchema = try resolveReference(responseRef, in: document)
        XCTAssertEqual(
            requiredProperties(responseSchema),
            ["capture_id", "judgment_count"],
            "Judgment upload answers 200 with accepted count, not 204 with an empty body."
        )
    }

    func testRankedResultsSchemaPinsCompatibilityVersion() throws {
        let document = try loadDocument()
        let schema = try resolveReference(
            try jsonResponseSchemaRef(
                "200",
                method: "get",
                path: "/api/v1/test_sheets/{sheet_id}/ranked_results",
                in: document
            ),
            in: document
        )
        XCTAssertEqual(requiredProperties(schema), ["schema_version", "sheet_id"])
        let properties = try requireDictionary(schema["properties"], "RankedResults.properties")
        let schemaVersion = try requireDictionary(properties["schema_version"], "schema_version")
        XCTAssertEqual(enumValues(schemaVersion), ["lps-ranked-results/v1"])
    }

    private func loadDocument() throws -> [String: Any] {
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: Self.vendoredSpecURL.path),
            "Vendor the published OpenAPI document at iOS/OpenAPI/color-matching-openapi.json."
        )
        let data = try Data(contentsOf: Self.vendoredSpecURL)
        return try requireDictionary(JSONSerialization.jsonObject(with: data), "OpenAPI document root")
    }

    private func operation(_ method: String, _ path: String, in document: [String: Any]) throws -> [String: Any] {
        let paths = try requireDictionary(document["paths"], "paths")
        let pathItem = try requireDictionary(paths[path], "paths[\(path)]")
        return try requireDictionary(pathItem[method], "paths[\(path)].\(method)")
    }

    private func response(_ status: String, of operation: [String: Any], label: String) throws -> [String: Any] {
        let responses = try requireDictionary(operation["responses"], "\(label).responses")
        return try requireDictionary(responses[status], "\(label).responses[\(status)]")
    }

    private func jsonResponseSchemaRef(
        _ status: String,
        method: String,
        path: String,
        in document: [String: Any]
    ) throws -> String {
        let operation = try self.operation(method, path, in: document)
        let response = try self.response(status, of: operation, label: "\(method) \(path)")
        return try contentSchemaRef(of: response, label: "\(method) \(path) \(status)")
    }

    private func requestBodySchemaRef(method: String, path: String, in document: [String: Any]) throws -> String {
        let operation = try self.operation(method, path, in: document)
        let requestBody = try requireDictionary(operation["requestBody"], "\(method) \(path).requestBody")
        return try contentSchemaRef(of: requestBody, label: "\(method) \(path) requestBody")
    }

    private func contentSchemaRef(of payload: [String: Any], label: String) throws -> String {
        let content = try requireDictionary(payload["content"], "\(label).content")
        let json = try requireDictionary(content["application/json"], "\(label).content.application/json")
        let schema = try requireDictionary(json["schema"], "\(label).content.application/json.schema")
        return try XCTUnwrap(schema["$ref"] as? String, "\(label) must reference a component schema via $ref.")
    }

    private func resolveReference(_ ref: String, in document: [String: Any]) throws -> [String: Any] {
        var current = document
        for segment in ref.split(separator: "/").dropFirst() {
            current = try XCTUnwrap(
                current[String(segment)] as? [String: Any],
                "Unresolvable $ref segment '\(segment)' in \(ref)."
            )
        }
        return current
    }

    private func requiredProperties(_ schema: [String: Any]) -> Set<String> {
        Set((schema["required"] as? [String]) ?? [])
    }

    private func enumValues(_ schema: [String: Any]) -> [String] {
        (schema["enum"] as? [String]) ?? []
    }

    private func requireDictionary(_ value: Any?, _ label: String) throws -> [String: Any] {
        try XCTUnwrap(value as? [String: Any], "Expected a JSON object for \(label).")
    }

    private func requireArray(_ value: Any?, _ label: String) throws -> [[String: Any]] {
        try XCTUnwrap(value as? [[String: Any]], "Expected an array of JSON objects for \(label).")
    }
}
