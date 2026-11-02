import Foundation
import XCTest

final class OpenAPISpecCoverageTests: XCTestCase {
    private let appSurfaces: [(path: String, method: String)] = [
        ("/api/v1/test_sheets/{sheet_id}/manifest", "get"),
        ("/api/v1/test_sheets/recent", "get"),
        ("/api/v1/test_sheets/{sheet_id}/captures", "post"),
        ("/api/v1/captures/{capture_id}/measurements", "post"),
        ("/api/v1/captures/{capture_id}/judgments", "post"),
        ("/api/v1/test_sheets/{sheet_id}/ranked_results", "get")
    ]

    func testVendoredSpecExistsAndDeclaresOpenAPI3() throws {
        let spec = try Self.loadSpec()
        let version = try XCTUnwrap(spec["openapi"] as? String)
        XCTAssertTrue(version.hasPrefix("3."), "expected OpenAPI 3.x, found \(version)")
    }

    func testSpecDocumentsEverySurfaceTheAppUses() throws {
        let spec = try Self.loadSpec()
        let paths = try XCTUnwrap(spec["paths"] as? [String: Any])

        for surface in appSurfaces {
            let operation = try Self.operation(path: surface.path, method: surface.method, in: paths)
            XCTAssertFalse(
                (operation["operationId"] as? String ?? "").isEmpty,
                "\(surface.method) \(surface.path) is missing an operationId"
            )
            let responses = try XCTUnwrap(operation["responses"] as? [String: Any])
            XCTAssertTrue(
                responses.keys.contains { Int($0).map { (200..<300).contains($0) } == true },
                "\(surface.method) \(surface.path) documents no 2xx response"
            )
        }
    }

    func testSpecDeclaresBearerAuth() throws {
        let spec = try Self.loadSpec()
        let components = try XCTUnwrap(spec["components"] as? [String: Any])
        let schemes = try XCTUnwrap(components["securitySchemes"] as? [String: Any])
        let bearer = try XCTUnwrap(schemes["bearerAuth"] as? [String: Any])
        XCTAssertEqual(bearer["type"] as? String, "http")
        XCTAssertEqual(bearer["scheme"] as? String, "bearer")
    }

    func testManifestSchemaDocumentsTheFieldsTheAppUses() throws {
        let manifest = try Self.schema("TestSheetManifest")
        try Self.assertSchema(
            manifest,
            requires: [
                "schema_version", "sheet_id", "sheet_version", "manifest_url", "created_at",
                "page", "registration_markers", "printer_profile", "capture_profile",
                "patches", "pairs"
            ],
            declares: [
                "schema_version", "sheet_id", "sheet_version", "manifest_url", "created_at",
                "page", "registration_markers", "printer_profile", "capture_profile",
                "patches", "pairs"
            ],
            label: "TestSheetManifest"
        )

        let patch = try Self.itemsSchema(of: "patches", in: manifest, label: "TestSheetManifest.patches")
        try Self.assertSchema(
            patch,
            requires: ["id", "role", "pair_id", "pair_side", "reference_role", "source_color", "safe_inset_mm", "rect"],
            declares: ["id", "role", "pair_id", "pair_side", "reference_role", "source_color", "safe_inset_mm", "rect"],
            label: "TestSheetManifest.patches items"
        )

        let rect = try Self.nestedSchema("rect", in: patch, label: "TestSheetManifest patch rect")
        try Self.assertSchema(rect, requires: ["x", "y", "width", "height"], declares: ["x", "y", "width", "height"], label: "patch rect")

        let page = try Self.nestedSchema("page", in: manifest, label: "TestSheetManifest.page")
        try Self.assertSchema(page, requires: ["units", "width", "height"], declares: ["units", "width", "height"], label: "page")

        let pair = try Self.itemsSchema(of: "pairs", in: manifest, label: "TestSheetManifest.pairs")
        try Self.assertSchema(
            pair,
            requires: ["id", "first_patch_id", "second_patch_id", "source_colors", "grid_row", "grid_col"],
            declares: ["id", "first_patch_id", "second_patch_id", "source_colors", "grid_row", "grid_col"],
            label: "TestSheetManifest.pairs items"
        )
    }

    func testMeasurementUploadSchemaMatchesServerBehavior() throws {
        let upload = try Self.schema("MeasurementUploadRequest")
        let declared = try Self.requiredKeys(of: upload)
        XCTAssertFalse(
            declared.contains("scoring_algorithm_version"),
            "server accepts no top-level scoring_algorithm_version; per-score algorithm_version only"
        )

        let measurement = try Self.itemsSchema(of: "measurements", in: upload, label: "MeasurementUploadRequest.measurements")
        try Self.assertSchema(
            measurement,
            requires: ["patch_id", "linear_rgb_median"],
            declares: ["patch_id", "linear_rgb_median", "normalized_linear_rgb_median", "stats"],
            label: "measurement items"
        )
        XCTAssertFalse(
            try Self.requiredKeys(of: measurement).contains("normalized_linear_rgb_median"),
            "server stores nil for absent normalized medians; the vendored spec must keep it optional"
        )

        let stats = try Self.nestedSchema("stats", in: measurement, label: "measurement stats")
        try Self.assertSchema(
            stats,
            requires: ["sample_count", "clipping_fraction", "mean", "standard_deviation"],
            declares: ["sample_count", "clipping_fraction", "mean", "standard_deviation"],
            label: "measurement stats"
        )

        let rgb = try Self.resolve(Self.nestedSchema("linear_rgb_median", in: measurement, label: "linear_rgb_median"))
        let variants = try XCTUnwrap(rgb["anyOf"] as? [[String: Any]], "RgbPayload must stay an anyOf")
        XCTAssertTrue(
            variants.contains { variant in
                Set((try? Self.requiredKeys(of: variant)) ?? []) == ["r", "g", "b"]
            },
            "RgbPayload must accept the {r, g, b} object form the app sends"
        )

        let score = try Self.scoreRequestSchema(in: upload)
        try Self.assertSchema(
            score,
            requires: ["pair_id", "algorithm_version"],
            declares: ["pair_id", "algorithm_version", "score", "similarity", "distance"],
            label: "pair score items"
        )
    }

    func testJudgmentSchemaConstrainsJudgmentValues() throws {
        let upload = try Self.schema("JudgmentUploadRequest")
        let judgment = try Self.itemsSchema(of: "judgments", in: upload, label: "JudgmentUploadRequest.judgments")
        let value = try Self.nestedSchema("judgment", in: judgment, label: "judgment value")
        let allowed = try XCTUnwrap(value["enum"] as? [String])
        XCTAssertEqual(Set(allowed), ["match", "near_match", "no_match"])
    }

    func testRankedResultsSchemaDocumentsResultsArray() throws {
        let results = try Self.schema("RankedResults")
        try Self.assertSchema(
            results,
            requires: ["schema_version", "sheet_id", "results"],
            declares: ["schema_version", "sheet_id", "results"],
            label: "RankedResults"
        )
        let envelopeVersion = try Self.nestedSchema("schema_version", in: results, label: "RankedResults.schema_version")
        let versions = try XCTUnwrap(envelopeVersion["enum"] as? [String])
        XCTAssertTrue(versions.contains("lps-ranked-results/v1"))

        let entry = try Self.itemsSchema(of: "results", in: results, label: "RankedResults.results")
        try Self.assertSchema(
            entry,
            requires: ["rank", "pair_id", "source_colors", "score", "current_judgment", "observation_count"],
            declares: ["rank", "pair_id", "source_colors", "score", "current_judgment", "observation_count"],
            label: "RankedResults.results items"
        )
    }

    func testUploadResponseSchemasMatchServerBodies() throws {
        let created = try Self.schema("CaptureCreatedResponse")
        try Self.assertSchema(created, requires: ["capture_id"], declares: ["capture_id"], label: "CaptureCreatedResponse")

        let measurements = try Self.schema("MeasurementUploadResponse")
        try Self.assertSchema(
            measurements,
            requires: ["capture_id", "measurement_count", "pair_score_count"],
            declares: ["capture_id", "measurement_count", "pair_score_count"],
            label: "MeasurementUploadResponse"
        )

        let judgments = try Self.schema("JudgmentUploadResponse")
        try Self.assertSchema(
            judgments,
            requires: ["capture_id", "judgment_count"],
            declares: ["capture_id", "judgment_count"],
            label: "JudgmentUploadResponse"
        )

        let recent = try Self.schema("RecentSheetsResponse")
        try Self.assertSchema(recent, requires: ["sheets"], declares: ["sheets"], label: "RecentSheetsResponse")
        let sheet = try Self.itemsSchema(of: "sheets", in: recent, label: "RecentSheetsResponse.sheets")
        try Self.assertSchema(sheet, requires: ["sheet_id", "manifest_url"], declares: ["sheet_id", "manifest_url", "title"], label: "recent sheet items")
        let title = try Self.nestedSchema("title", in: sheet, label: "recent sheet title")
        XCTAssertEqual(title["nullable"] as? Bool, true)
    }
}

private extension OpenAPISpecCoverageTests {
    static var vendoredSpecURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("OpenAPI/color-matching-api-v1.json")
    }

    static func loadSpec() throws -> [String: Any] {
        let url = vendoredSpecURL
        guard FileManager.default.fileExists(atPath: url.path) else {
            XCTFail("vendored OpenAPI document is missing at \(url.path)")
            throw NSError(domain: "OpenAPISpecCoverage", code: 1)
        }
        let data = try Data(contentsOf: url)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    static func operation(path: String, method: String, in paths: [String: Any]) throws -> [String: Any] {
        let pathItem = try XCTUnwrap(paths[path] as? [String: Any], "spec is missing path \(path)")
        return try XCTUnwrap(pathItem[method] as? [String: Any], "path \(path) is missing \(method)")
    }

    static func schema(_ name: String) throws -> [String: Any] {
        let spec = try loadSpec()
        let components = try XCTUnwrap(spec["components"] as? [String: Any])
        let schemas = try XCTUnwrap(components["schemas"] as? [String: Any])
        return try XCTUnwrap(schemas[name] as? [String: Any], "spec is missing schema \(name)")
    }

    static func resolve(_ schema: [String: Any]) throws -> [String: Any] {
        guard let reference = schema["$ref"] as? String else { return schema }
        let name = reference.replacingOccurrences(of: "#/components/schemas/", with: "")
        return try self.schema(name)
    }

    static func requiredKeys(of schema: [String: Any]) throws -> [String] {
        (schema["required"] as? [String]) ?? []
    }

    static func properties(of schema: [String: Any]) throws -> [String: Any] {
        try XCTUnwrap(resolve(schema)["properties"] as? [String: Any])
    }

    static func assertSchema(_ schema: [String: Any], requires: [String], declares: [String], label: String) throws {
        let propertyNames = Set(try properties(of: schema).keys)
        let missingProperties = Set(declares).subtracting(propertyNames)
        XCTAssertTrue(missingProperties.isEmpty, "\(label) is missing properties: \(missingProperties.sorted())")

        let required = Set(try requiredKeys(of: schema))
        let missingRequired = Set(requires).subtracting(required)
        XCTAssertTrue(missingRequired.isEmpty, "\(label) does not require: \(missingRequired.sorted())")
    }

    static func nestedSchema(_ name: String, in schema: [String: Any], label: String) throws -> [String: Any] {
        let properties = try self.properties(of: schema)
        return try XCTUnwrap(properties[name] as? [String: Any], "\(label) is missing property \(name)")
    }

    static func itemsSchema(of property: String, in schema: [String: Any], label: String) throws -> [String: Any] {
        let nested = try nestedSchema(property, in: schema, label: label)
        let resolved = try resolve(nested)
        let items = try XCTUnwrap(resolved["items"] as? [String: Any], "\(label) property \(property) is not an array")
        return items
    }

    static func scoreRequestSchema(in upload: [String: Any]) throws -> [String: Any] {
        let scores = try nestedSchema("pair_scores", in: upload, label: "MeasurementUploadRequest")
        let items = try XCTUnwrap(try resolve(scores)["items"] as? [String: Any])
        return try resolve(items)
    }
}
