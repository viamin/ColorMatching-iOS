import Foundation
import XCTest

/// Guards the generated OpenAPI client adoption (issue #5, deliverables 1 and 2).
///
/// `viamin/color_matching#110` publishes a machine-readable OpenAPI 3 contract for
/// the `/api/v1` API this app consumes. The adoption plan (see
/// `docs/openapi-generated-client-plan.md`) vendors that document verbatim at the
/// canonical path `iOS/Sources/ColorMatchingOpenAPI/openapi.json` so
/// `swift-openapi-generator` can produce the typed client.
///
/// These tests fail until the document is vendored. They are the permanent,
/// compile-safe drift guard: if the vendored document stops covering a surface
/// the app uses, or drops a compatibility marker (`lps-sheet-manifest/v1`,
/// `lps-distance-v1`, `lps-ranked-results/v1`), the failure is local and named.
///
/// Contract deltas between the hand-written prose contract
/// (`docs/color-matching-api-contract.md`) and this spec are recorded in
/// `docs/contract-deltas-prose-vs-openapi.md`; the assertions below encode the
/// spec-side shapes, including the deltas the app must adopt (counting response
/// bodies on upload endpoints, per-score `algorithm_version`, no top-level
/// `scoring_algorithm_version`).
final class OpenAPISpecCoverageTests: XCTestCase {
    // MARK: - Deliverable 1: the published spec is vendored

    func testVendoredOpenAPIDocumentExistsAndDescribesTheAPI() throws {
        let spec = try Self.vendoredSpec()

        let version = try self.string(spec["openapi"], "openapi version")
        XCTAssertTrue(version.hasPrefix("3."), "vendored document is not OpenAPI 3.x: \(version)")

        let info = try self.object(spec["info"], "info")
        XCTAssertEqual(try self.string(info["title"], "info.title"), "Color Matching API")

        let servers = try self.array(spec["servers"], "servers")
        let server = try self.object(servers.first, "servers.first")
        let serverURL = try self.string(server["url"], "servers.first.url")
        XCTAssertTrue(serverURL.hasPrefix("/"), "server URL must be root-relative so the app supplies the base URL, got: \(serverURL)")
    }

    // MARK: - Deliverable 2: every surface the app uses is covered

    func testSpecCoversTheSixSurfacesTheAppUses() throws {
        let spec = try Self.vendoredSpec()
        let paths = try self.object(spec["paths"], "paths")

        let surfaces: [Surface] = [
            Surface(path: "/api/v1/test_sheets/recent", method: "get", operationID: "ColorMatchingWeb.TestSheetController.recent", status: "200", responseSchema: "RecentSheetsResponse"),
            Surface(path: "/api/v1/test_sheets/{sheet_id}/manifest", method: "get", operationID: "ColorMatchingWeb.TestSheetController.manifest", status: "200", responseSchema: "TestSheetManifest"),
            Surface(path: "/api/v1/test_sheets/{sheet_id}/ranked_results", method: "get", operationID: "ColorMatchingWeb.TestSheetController.ranked_results", status: "200", responseSchema: "RankedResults"),
            Surface(path: "/api/v1/test_sheets/{sheet_id}/captures", method: "post", operationID: "ColorMatchingWeb.CaptureController.create", status: "201", responseSchema: "CaptureCreatedResponse"),
            Surface(path: "/api/v1/captures/{capture_id}/measurements", method: "post", operationID: "ColorMatchingWeb.CaptureController.upload_measurements", status: "200", responseSchema: "MeasurementUploadResponse"),
            Surface(path: "/api/v1/captures/{capture_id}/judgments", method: "post", operationID: "ColorMatchingWeb.CaptureController.upload_judgments", status: "200", responseSchema: "JudgmentUploadResponse"),
        ]

        for surface in surfaces {
            let item = try self.object(paths[surface.path], "path \(surface.path)")
            let operation = try self.object(item[surface.method], "\(surface.method) \(surface.path)")

            // Vendoring is verbatim: the open_api_spex-generated operationIds survive,
            // which fixes the generated Swift method names (see the adoption plan).
            XCTAssertEqual(
                try self.string(operation["operationId"], "\(surface.path) operationId"),
                surface.operationID
            )

            let ref = try self.responseSchemaRef(operation, status: surface.status, label: surface.path)
            XCTAssertEqual(ref, "#/components/schemas/\(surface.responseSchema)", "\(surface.path) \(surface.status) response schema")
        }
    }

    func testPathParametersAreDocumentedAsRequiredStrings() throws {
        let spec = try Self.vendoredSpec()
        let paths = try self.object(spec["paths"], "paths")

        let expectations: [(path: String, method: String, name: String)] = [
            ("/api/v1/test_sheets/{sheet_id}/manifest", "get", "sheet_id"),
            ("/api/v1/test_sheets/{sheet_id}/ranked_results", "get", "sheet_id"),
            ("/api/v1/test_sheets/{sheet_id}/captures", "post", "sheet_id"),
            ("/api/v1/captures/{capture_id}/measurements", "post", "capture_id"),
            ("/api/v1/captures/{capture_id}/judgments", "post", "capture_id"),
        ]

        for expectation in expectations {
            let parameter = try self.pathParameter(paths, path: expectation.path, method: expectation.method, name: expectation.name)
            XCTAssertEqual(try self.string(parameter["in"], "\(expectation.name).in"), "path")
            XCTAssertEqual(try self.bool(parameter["required"], "\(expectation.name).required"), true)
            let schema = try self.object(parameter["schema"], "\(expectation.name).schema")
            XCTAssertEqual(try self.string(schema["type"], "\(expectation.name).schema.type"), "string")
        }
    }

    func testUploadOperationsDeclareJSONRequestBodies() throws {
        let spec = try Self.vendoredSpec()
        let paths = try self.object(spec["paths"], "paths")

        let expectations: [(path: String, schema: String)] = [
            ("/api/v1/test_sheets/{sheet_id}/captures", "CaptureRequest"),
            ("/api/v1/captures/{capture_id}/measurements", "MeasurementUploadRequest"),
            ("/api/v1/captures/{capture_id}/judgments", "JudgmentUploadRequest"),
        ]

        for expectation in expectations {
            let item = try self.object(paths[expectation.path], "path \(expectation.path)")
            let operation = try self.object(item["post"], "post \(expectation.path)")
            let body = try self.object(operation["requestBody"], "\(expectation.path) requestBody")
            let ref = try self.contentSchemaRef(body, label: "\(expectation.path) requestBody")
            XCTAssertEqual(ref, "#/components/schemas/\(expectation.schema)", "\(expectation.path) request body schema")
        }
    }

    // MARK: - Compatibility markers the app's scoring depends on

    func testManifestSchemaPinsCompatibilityVersions() throws {
        let schemas = try self.schemas()
        let manifest = try self.object(schemas["TestSheetManifest"], "TestSheetManifest")

        let required = try self.stringArray(manifest["required"], "TestSheetManifest.required")
        XCTAssertTrue(
            Set(required).isSuperset(of: ["schema_version", "sheet_id", "capture_profile"]),
            "TestSheetManifest.required lost a required field: \(required)"
        )

        let properties = try self.object(manifest["properties"], "TestSheetManifest.properties")
        let schemaVersion = try self.object(properties["schema_version"], "schema_version")
        XCTAssertEqual(try self.stringArray(schemaVersion["enum"], "schema_version.enum"), ["lps-sheet-manifest/v1"])

        let captureProfile = try self.object(properties["capture_profile"], "capture_profile")
        let scoring = try self.object(try self.object(captureProfile["properties"], "capture_profile.properties")["scoring_algorithm_version"], "scoring_algorithm_version")
        XCTAssertEqual(try self.stringArray(scoring["enum"], "scoring_algorithm_version.enum"), ["lps-distance-v1"])
        XCTAssertTrue(
            try self.stringArray(captureProfile["required"], "capture_profile.required").contains("scoring_algorithm_version"),
            "capture_profile must require scoring_algorithm_version"
        )
    }

    func testRankedResultsSchemaPinsItsVersion() throws {
        let schemas = try self.schemas()
        let ranked = try self.object(schemas["RankedResults"], "RankedResults")

        let required = try self.stringArray(ranked["required"], "RankedResults.required")
        XCTAssertTrue(Set(required).isSuperset(of: ["schema_version", "sheet_id"]), "RankedResults.required lost a field: \(required)")

        let schemaVersion = try self.object(try self.object(ranked["properties"], "RankedResults.properties")["schema_version"], "schema_version")
        XCTAssertEqual(try self.stringArray(schemaVersion["enum"], "schema_version.enum"), ["lps-ranked-results/v1"])
    }

    // MARK: - Deltas the app must adopt (see docs/contract-deltas-prose-vs-openapi.md)

    func testCaptureCreationReturns201WithCaptureID() throws {
        let schemas = try self.schemas()
        let created = try self.object(schemas["CaptureCreatedResponse"], "CaptureCreatedResponse")
        XCTAssertEqual(Set(try self.stringArray(created["required"], "CaptureCreatedResponse.required")), ["capture_id"])

        let metadata = try self.object(schemas["CaptureMetadata"], "CaptureMetadata")
        let required = try self.stringArray(metadata["required"], "CaptureMetadata.required")
        XCTAssertTrue(
            Set(required).isSuperset(of: ["device_model", "lens", "image_width", "image_height", "app_version", "timestamp"]),
            "CaptureMetadata.required lost a field: \(required)"
        )
        let timestamp = try self.object(try self.object(metadata["properties"], "CaptureMetadata.properties")["timestamp"], "timestamp")
        XCTAssertEqual(try self.string(timestamp["format"], "timestamp.format"), "date-time")
    }

    func testUploadEndpointsReturnCountingBodiesInsteadOfNoContent() throws {
        let schemas = try self.schemas()
        let spec = try Self.vendoredSpec()
        let paths = try self.object(spec["paths"], "paths")

        let measurementResponse = try self.object(schemas["MeasurementUploadResponse"], "MeasurementUploadResponse")
        XCTAssertTrue(
            Set(try self.stringArray(measurementResponse["required"], "MeasurementUploadResponse.required"))
                .isSuperset(of: ["capture_id", "measurement_count", "pair_score_count"]),
            "measurement upload must return capture_id, measurement_count, pair_score_count"
        )

        let judgmentResponse = try self.object(schemas["JudgmentUploadResponse"], "JudgmentUploadResponse")
        XCTAssertTrue(
            Set(try self.stringArray(judgmentResponse["required"], "JudgmentUploadResponse.required"))
                .isSuperset(of: ["capture_id", "judgment_count"]),
            "judgment upload must return capture_id, judgment_count"
        )

        // The prose contract implied fire-and-forget uploads (the hand-written client
        // tolerated 204). The published spec returns 200 with a counting body.
        for path in ["/api/v1/captures/{capture_id}/measurements", "/api/v1/captures/{capture_id}/judgments"] {
            let operation = try self.object(try self.object(paths[path], "path \(path)")["post"], "post \(path)")
            let responses = try self.object(operation["responses"], "\(path) responses")
            XCTAssertNotNil(responses["200"], "\(path) must document a 200 response")
            XCTAssertNil(responses["204"], "\(path) must not document a 204 response")
        }
    }

    func testMeasurementUploadScoresCarryAlgorithmVersionPerScore() throws {
        let schemas = try self.schemas()
        let upload = try self.object(schemas["MeasurementUploadRequest"], "MeasurementUploadRequest")
        let properties = try self.object(upload["properties"], "MeasurementUploadRequest.properties")

        // Prose delta: the top-level scoring_algorithm_version is gone from the
        // published spec; every pair score carries its own algorithm_version.
        XCTAssertNil(properties["scoring_algorithm_version"], "spec must not carry top-level scoring_algorithm_version")
        XCTAssertNotNil(properties["pair_scores"], "spec must carry pair_scores")

        let pairScore = try self.object(schemas["PairScoreRequest"], "PairScoreRequest")
        XCTAssertTrue(
            Set(try self.stringArray(pairScore["required"], "PairScoreRequest.required"))
                .isSuperset(of: ["pair_id", "algorithm_version"]),
            "PairScoreRequest must require pair_id and algorithm_version"
        )
        let scoreProperties = try self.object(pairScore["properties"], "PairScoreRequest.properties")
        for field in ["score", "similarity", "distance"] {
            XCTAssertNotNil(scoreProperties[field], "PairScoreRequest lost the \(field) property")
        }
        XCTAssertEqual(try self.array(pairScore["anyOf"], "PairScoreRequest.anyOf").count, 3, "PairScoreRequest must accept score, similarity, or distance")

        let rgb = try self.object(schemas["RgbPayload"], "RgbPayload")
        XCTAssertEqual(try self.array(rgb["anyOf"], "RgbPayload.anyOf").count, 3, "RgbPayload must accept array, object, or string")
    }

    func testRecentSheetsItemsRequireNullableTitle() throws {
        let schemas = try self.schemas()
        let recent = try self.object(schemas["RecentSheetsResponse"], "RecentSheetsResponse")
        let sheets = try self.object(try self.object(recent["properties"], "RecentSheetsResponse.properties")["sheets"], "sheets")
        let items = try self.object(sheets["items"], "sheets.items")

        XCTAssertTrue(
            Set(try self.stringArray(items["required"], "sheets.items.required"))
                .isSuperset(of: ["sheet_id", "manifest_url", "title"]),
            "recent sheet items must require sheet_id, manifest_url, title"
        )

        let title = try self.object(try self.object(items["properties"], "sheets.items.properties")["title"], "title")
        XCTAssertTrue(
            Self.isNullable(title),
            "title must be nullable (the Phoenix app currently renders null titles): \(title)"
        )
    }

    // MARK: - Authentication

    func testOperationsRequireBearerAuth() throws {
        let spec = try Self.vendoredSpec()
        let schemes = try self.object(try self.object(spec["components"], "components")["securitySchemes"], "securitySchemes")
        let bearer = try self.object(schemes["bearerAuth"], "bearerAuth")
        XCTAssertEqual(try self.string(bearer["type"], "bearerAuth.type"), "http")
        XCTAssertEqual(try self.string(bearer["scheme"], "bearerAuth.scheme"), "bearer")

        let paths = try self.object(spec["paths"], "paths")
        let surfaces: [Surface] = [
            Surface(path: "/api/v1/test_sheets/recent", method: "get", operationID: "ColorMatchingWeb.TestSheetController.recent", status: "200", responseSchema: "RecentSheetsResponse"),
            Surface(path: "/api/v1/test_sheets/{sheet_id}/manifest", method: "get", operationID: "ColorMatchingWeb.TestSheetController.manifest", status: "200", responseSchema: "TestSheetManifest"),
            Surface(path: "/api/v1/test_sheets/{sheet_id}/ranked_results", method: "get", operationID: "ColorMatchingWeb.TestSheetController.ranked_results", status: "200", responseSchema: "RankedResults"),
            Surface(path: "/api/v1/test_sheets/{sheet_id}/captures", method: "post", operationID: "ColorMatchingWeb.CaptureController.create", status: "201", responseSchema: "CaptureCreatedResponse"),
            Surface(path: "/api/v1/captures/{capture_id}/measurements", method: "post", operationID: "ColorMatchingWeb.CaptureController.upload_measurements", status: "200", responseSchema: "MeasurementUploadResponse"),
            Surface(path: "/api/v1/captures/{capture_id}/judgments", method: "post", operationID: "ColorMatchingWeb.CaptureController.upload_judgments", status: "200", responseSchema: "JudgmentUploadResponse"),
        ]

        for surface in surfaces {
            let operation = try self.object(try self.object(paths[surface.path], "path \(surface.path)")[surface.method], "\(surface.method) \(surface.path)")
            let security = try self.array(operation["security"], "\(surface.path) security")
            let usesBearer = security.contains { entry in
                guard let dictionary = entry as? [String: Any] else { return false }
                return dictionary["bearerAuth"] != nil
            }
            XCTAssertTrue(usesBearer, "\(surface.path) must require bearerAuth")
        }
    }

    // MARK: - Endpoint gaps discovered while vendoring

    func testPreviouslyUndocumentedEndpointsArePartOfTheSpec() throws {
        let paths = try self.object(try Self.vendoredSpec()["paths"], "paths")
        // viamin/color_matching#110 folded two previously-undocumented surfaces
        // into the spec; they are not used by this app today (recorded in
        // docs/contract-deltas-prose-vs-openapi.md) but their presence keeps the
        // vendored document a faithful snapshot.
        XCTAssertNotNil(paths["/api/illuminant_measurements"])
        XCTAssertNotNil(paths["/api/multi_image_mapping"])
    }

    // MARK: - Vendoring location

    /// Canonical vendoring path: `iOS/Sources/ColorMatchingOpenAPI/openapi.json`
    /// (the module dir swift-openapi-generator reads by default). The fallbacks
    /// keep the failure message useful while the adoption is in flight.
    private static func vendoredDocumentURL(file: StaticString = #filePath, line: UInt = #line) throws -> URL {
        let testFile = URL(fileURLWithPath: #filePath, isDirectory: false)
        let packageRoot = testFile
            .deletingLastPathComponent() // OpenAPISpecCoverageTests.swift
            .deletingLastPathComponent() // ColorMatchingLPSAppTests/
            .deletingLastPathComponent() // Tests/
        let candidates = [
            packageRoot.appendingPathComponent("Sources/ColorMatchingOpenAPI/openapi.json"),
            packageRoot.appendingPathComponent("openapi.json"),
            packageRoot.appendingPathComponent("Sources/ColorMatchingLPSAppCore/openapi.json"),
        ]
        let existing = candidates.first { FileManager.default.fileExists(atPath: $0.path) }
        return try XCTUnwrap(
            existing,
            """
            No vendored OpenAPI document found. Looked in:
            \(candidates.map(\.path).joined(separator: "\n"))

            Vendor the document published by viamin/color_matching#110 \
            (served at GET /api/v1/openapi.json; reconstruction reference at \
            docs/openapi-vendoring-source.json) as JSON at the canonical path \
            Sources/ColorMatchingOpenAPI/openapi.json. \
            See docs/openapi-generated-client-plan.md.
            """,
            file: file,
            line: line
        )
    }

    private static func vendoredSpec() throws -> [String: Any] {
        let url = try vendoredDocumentURL()
        let data = try Data(contentsOf: url)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any], "vendored document is not a JSON object")
    }

    // MARK: - JSON walking helpers

    private struct Surface {
        let path: String
        let method: String
        let operationID: String
        let status: String
        let responseSchema: String
    }

    private func schemas() throws -> [String: Any] {
        let spec = try Self.vendoredSpec()
        return try self.object(try self.object(spec["components"], "components")["schemas"], "components.schemas")
    }

    private func responseSchemaRef(_ operation: [String: Any], status: String, label: String) throws -> String {
        let responses = try self.object(operation["responses"], "\(label) responses")
        let response = try self.object(responses[status], "\(label) \(status)")
        return try self.contentSchemaRef(response, label: "\(label) \(status)")
    }

    private func contentSchemaRef(_ container: [String: Any], label: String) throws -> String {
        let content = try self.object(container["content"], "\(label) content")
        let json = try self.object(content["application/json"], "\(label) application/json")
        let schema = try self.object(json["schema"], "\(label) schema")
        return try self.string(schema["$ref"], "\(label) schema.$ref")
    }

    private func pathParameter(_ paths: [String: Any], path: String, method: String, name: String) throws -> [String: Any] {
        let item = try self.object(paths[path], "path \(path)")
        let operation = try self.object(item[method], "\(method) \(path)")
        let parameters = try self.array(operation["parameters"], "\(path) parameters")
        let match = try XCTUnwrap(
            parameters.first { entry in
                (entry as? [String: Any])?["name"] as? String == name
            },
            "\(path) is missing path parameter \(name)"
        )
        return try self.object(match, "\(path) parameter \(name)")
    }

    private func object(_ value: Any?, _ label: String, file: StaticString = #filePath, line: UInt = #line) throws -> [String: Any] {
        try XCTUnwrap(value as? [String: Any], "expected \(label) to be a JSON object", file: file, line: line)
    }

    private func array(_ value: Any?, _ label: String, file: StaticString = #filePath, line: UInt = #line) throws -> [Any] {
        try XCTUnwrap(value as? [Any], "expected \(label) to be a JSON array", file: file, line: line)
    }

    private func string(_ value: Any?, _ label: String, file: StaticString = #filePath, line: UInt = #line) throws -> String {
        try XCTUnwrap(value as? String, "expected \(label) to be a string", file: file, line: line)
    }

    private func bool(_ value: Any?, _ label: String, file: StaticString = #filePath, line: UInt = #line) throws -> Bool {
        try XCTUnwrap(value as? Bool, "expected \(label) to be a boolean", file: file, line: line)
    }

    private func stringArray(_ value: Any?, _ label: String, file: StaticString = #filePath, line: UInt = #line) throws -> [String] {
        let array = try self.array(value, label, file: file, line: line)
        return try array.map { try self.string($0, "\(label) element", file: file, line: line) }
    }

    /// Tolerates both the 3.0 (`nullable: true`) and 3.1 (`type: ["string","null"]`,
    /// `anyOf: [{type: null}]`) encodings of optionality.
    private static func isNullable(_ property: [String: Any]) -> Bool {
        if property["nullable"] as? Bool == true { return true }
        for key in ["anyOf", "oneOf"] {
            guard let variants = property[key] as? [[String: Any]] else { continue }
            if variants.contains(where: { $0["type"] as? String == "null" }) { return true }
        }
        if let types = property["type"] as? [String], types.contains("null") { return true }
        return false
    }
}
