import Foundation
import XCTest

// Structural contract tests for the generated OpenAPI client (issue #5).
// Intentionally larger than the ~100-line class target: one assertion cluster per test.
//
// These tests are RED until the implementation lands:
//   - the published spec (viamin/color_matching#110, served at GET /api/v1/openapi.json)
//     is vendored as JSON at iOS/Sources/ColorMatchingOpenAPI/OpenAPI/openapi.json
//   - iOS/Package.swift wires swift-openapi-generator + swift-openapi-runtime
//
// Pinned decisions and the prose-contract deltas these assertions encode are
// documented in docs/ios-openapi-client-plan.md.
final class OpenAPIContractTests: XCTestCase {
    private static let manifestPath = "/api/v1/test_sheets/{sheet_id}/manifest"
    private static let recentPath = "/api/v1/test_sheets/recent"
    private static let rankedResultsPath = "/api/v1/test_sheets/{sheet_id}/ranked_results"
    private static let capturesPath = "/api/v1/test_sheets/{sheet_id}/captures"
    private static let measurementsPath = "/api/v1/captures/{capture_id}/measurements"
    private static let judgmentsPath = "/api/v1/captures/{capture_id}/judgments"

    private static let surfaces: [(path: String, method: String, status: String)] = [
        (path: manifestPath, method: "get", status: "200"),
        (path: recentPath, method: "get", status: "200"),
        (path: rankedResultsPath, method: "get", status: "200"),
        (path: capturesPath, method: "post", status: "201"),
        (path: measurementsPath, method: "post", status: "200"),
        (path: judgmentsPath, method: "post", status: "200")
    ]

    private static let manifestKeys = [
        "schema_version", "sheet_version", "sheet_id", "manifest_url",
        "page", "registration_markers", "patches", "pairs"
    ]
    private static let patchKeys = [
        "id", "role", "pair_id", "pair_side", "reference_role",
        "source_color", "safe_inset_mm", "rect"
    ]
    private static let pairKeys = [
        "id", "first_patch_id", "second_patch_id", "source_colors", "grid_row", "grid_col"
    ]
    private static let pageKeys = ["units", "width", "height"]
    private static let markerKeys = ["role", "shape", "rect"]
    private static let rectKeys = ["x", "y", "width", "height"]
    private static let metadataKeys = [
        "device_model", "lens", "exposure_duration_seconds", "iso", "focus_lens_position",
        "white_balance_gains", "image_width", "image_height", "app_version", "timestamp"
    ]
    private static let qualityKeys = ["detected_marker_count", "blur_score", "rejections"]
    private static let measurementKeys = [
        "patch_id", "linear_rgb_median", "normalized_linear_rgb_median", "stats"
    ]
    private static let statsKeys = ["sample_count", "clipping_fraction", "mean", "standard_deviation"]
    private static let scoreKeys = ["pair_id", "distance", "similarity", "algorithm_version"]
    private static let rankedResultKeys = ["rank", "pair_id", "source_colors", "score"]

    private static var packageRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private static var vendoredSpecURL: URL {
        packageRoot.appendingPathComponent("Sources/ColorMatchingOpenAPI/OpenAPI/openapi.json")
    }

    private static var packageManifestURL: URL {
        packageRoot.appendingPathComponent("Package.swift")
    }

    func testVendoredOpenAPIDocumentExistsAndIsOpenAPI30() throws {
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: Self.vendoredSpecURL.path),
            "Missing vendored OpenAPI document at \(Self.vendoredSpecURL.path). Vendor the JSON spec published at GET /api/v1/openapi.json (viamin/color_matching#110); see docs/ios-openapi-client-plan.md."
        )
        let spec = try Self.loadedSpec()
        XCTAssertTrue(
            (spec["openapi"] as? String)?.hasPrefix("3.0.") == true,
            "swift-openapi-generator only supports OpenAPI 3.0.x; vendored document must declare an \"openapi\" version of 3.0.x."
        )
    }

    func testPackageManifestWiresGeneratedOpenAPIClient() throws {
        let manifest = try String(contentsOf: Self.packageManifestURL, encoding: .utf8)
        let required = [
            "swift-openapi-generator", "swift-openapi-runtime",
            "OpenAPIGenerator", "OpenAPIRuntime", "ColorMatchingOpenAPI"
        ]
        for needle in required {
            XCTAssertTrue(
                manifest.contains(needle),
                "iOS/Package.swift must reference \"\(needle)\" so the typed client is generated at build time; see docs/ios-openapi-client-plan.md."
            )
        }
    }

    func testVendoredSpecCoversEverySurfaceTheAppUses() throws {
        let spec = try Self.loadedSpec()
        for surface in Self.surfaces {
            let operation = try Self.operation(surface.method, surface.path, in: spec)
            XCTAssertFalse(
                (operation["operationId"] as? String)?.isEmpty ?? true,
                "\(surface.method) \(surface.path) must declare a non-empty operationId so the generated client exposes a stable, named method."
            )
            let responses = try object("responses", in: operation, "\(surface.method) \(surface.path)")
            let response = try object(surface.status, in: responses, "responses of \(surface.method) \(surface.path)")
            let content = try object("content", in: response, "\(surface.status) response of \(surface.method) \(surface.path)")
            XCTAssertNotNil(
                content["application/json"],
                "\(surface.method) \(surface.path) must declare a JSON response for status \(surface.status)."
            )
        }
    }

    func testVendoredSpecRequiresBearerAuthOnEveryAppSurface() throws {
        let spec = try Self.loadedSpec()
        let components = try object("components", in: spec, "spec")
        let schemes = try object("securitySchemes", in: components, "components")
        let bearerSchemes = schemes.filter { entry in
            guard let scheme = entry.value as? [String: Any] else { return false }
            return (scheme["type"] as? String) == "http" && (scheme["scheme"] as? String) == "bearer"
        }
        XCTAssertFalse(
            bearerSchemes.isEmpty,
            "Vendored spec must declare an http/bearer security scheme (the app authenticates with a bearer token)."
        )
        for surface in Self.surfaces {
            let operation = try Self.operation(surface.method, surface.path, in: spec)
            let effective = (operation["security"] as? [[String: Any]]) ?? (spec["security"] as? [[String: Any]])
            let referenced = try XCTUnwrap(effective, "\(surface.method) \(surface.path) must declare a security requirement (operation-level or document-level).")
            let names = referenced.flatMap { $0.keys }
            XCTAssertFalse(
                names.allSatisfy { schemes[$0] == nil },
                "\(surface.method) \(surface.path) security requirement \(names) must reference a declared security scheme."
            )
        }
    }

    func testVendoredManifestSchemaDeclaresFieldsTheAppDecodes() throws {
        let schema = try responseSchema(path: Self.manifestPath, method: "get", status: "200")
        let spec = try Self.loadedSpec()
        requireKeys(Self.manifestKeys, in: try properties(of: schema, in: spec, "manifest response"), "manifest response")
        requireKeys(Self.patchKeys, in: try itemProperties("patches", of: schema, in: spec), "manifest patches items")
        requireKeys(Self.pairKeys, in: try itemProperties("pairs", of: schema, in: spec), "manifest pairs items")
        requireKeys(Self.markerKeys, in: try itemProperties("registration_markers", of: schema, in: spec), "manifest registration_markers items")
        let page = try property("page", of: schema, in: spec, "manifest response")
        requireKeys(Self.pageKeys, in: try properties(of: page, in: spec, "manifest page"), "manifest page")
        requireKeys(
            Self.rectKeys,
            in: try properties(of: rectSchema(of: schema, in: spec), in: spec, "manifest rect"),
            "manifest rect"
        )
    }

    func testVendoredRecentSheetsSchemaDeclaresNullableTitle() throws {
        let schema = try responseSchema(path: Self.recentPath, method: "get", status: "200")
        let spec = try Self.loadedSpec()
        let sheetItems = try itemsSchema("sheets", of: schema, in: spec)
        requireKeys(["sheet_id", "manifest_url", "title"], in: try properties(of: sheetItems, in: spec, "recent sheets items"), "recent sheets items")
        let title = try property("title", of: sheetItems, in: spec, "recent sheets items")
        XCTAssertEqual(
            title["nullable"] as? Bool,
            true,
            "Recent sheet \"title\" must be declared nullable so it maps to the app's String? instead of failing decode on null."
        )
    }

    func testVendoredCaptureRequestSchemaAcceptsAppPayload() throws {
        let schema = try requestSchema(path: Self.capturesPath, method: "post")
        let spec = try Self.loadedSpec()
        requireKeys(["metadata", "quality"], in: try properties(of: schema, in: spec, "capture request"), "capture request")
        let metadata = try property("metadata", of: schema, in: spec, "capture request")
        requireKeys(Self.metadataKeys, in: try properties(of: metadata, in: spec, "capture metadata"), "capture metadata")
        let quality = try property("quality", of: schema, in: spec, "capture request")
        requireKeys(Self.qualityKeys, in: try properties(of: quality, in: spec, "capture quality"), "capture quality")
    }

    func testVendoredMeasurementUploadSchemaMatchesAppPayload() throws {
        let schema = try requestSchema(path: Self.measurementsPath, method: "post")
        let spec = try Self.loadedSpec()
        requireKeys(
            ["scoring_algorithm_version", "measurements", "pair_scores"],
            in: try properties(of: schema, in: spec, "measurement upload request"),
            "measurement upload request"
        )
        let measurementItems = try itemsSchema("measurements", of: schema, in: spec)
        requireKeys(Self.measurementKeys, in: try properties(of: measurementItems, in: spec, "measurement items"), "measurement items")
        let stats = try property("stats", of: measurementItems, in: spec, "measurement items")
        requireKeys(Self.statsKeys, in: try properties(of: stats, in: spec, "measurement stats"), "measurement stats")
        let scoreItems = try itemsSchema("pair_scores", of: schema, in: spec)
        requireKeys(Self.scoreKeys, in: try properties(of: scoreItems, in: spec, "pair score items"), "pair score items")
    }

    func testVendoredJudgmentUploadSchemaMatchesAppPayload() throws {
        let schema = try requestSchema(path: Self.judgmentsPath, method: "post")
        let spec = try Self.loadedSpec()
        requireKeys(["judgments"], in: try properties(of: schema, in: spec, "judgment upload request"), "judgment upload request")
        requireKeys(["pair_id", "judgment"], in: try itemProperties("judgments", of: schema, in: spec), "judgment items")
    }

    func testVendoredRankedResultsSchemaDeclaresRankedList() throws {
        let schema = try responseSchema(path: Self.rankedResultsPath, method: "get", status: "200")
        let spec = try Self.loadedSpec()
        requireKeys(
            ["schema_version", "sheet_id", "results"],
            in: try properties(of: schema, in: spec, "ranked results response"),
            "ranked results response"
        )
        requireKeys(Self.rankedResultKeys, in: try itemProperties("results", of: schema, in: spec), "ranked result items")
    }

    private static func loadedSpec() throws -> [String: Any] {
        let data = try Data(contentsOf: vendoredSpecURL)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private static func operation(_ method: String, _ path: String, in spec: [String: Any]) throws -> [String: Any] {
        let paths = try XCTUnwrap(spec["paths"] as? [String: Any], "Vendored spec has no paths object.")
        let item = try XCTUnwrap(paths[path] as? [String: Any], "Vendored spec does not declare path \(path).")
        return try XCTUnwrap(item[method] as? [String: Any], "Path \(path) does not declare a \(method) operation.")
    }

    private func object(_ key: String, in parent: [String: Any], _ context: String) throws -> [String: Any] {
        try XCTUnwrap(parent[key] as? [String: Any], "Missing object \"\(key)\" in \(context).")
    }

    private func responseSchema(path: String, method: String, status: String) throws -> [String: Any] {
        let spec = try Self.loadedSpec()
        let operation = try Self.operation(method, path, in: spec)
        let responses = try object("responses", in: operation, "\(method) \(path)")
        let response = try object(status, in: responses, "responses of \(method) \(path)")
        let content = try object("content", in: response, "\(status) response of \(method) \(path)")
        return try object("schema", in: try object("application/json", in: content, "content"), "application/json schema")
    }

    private func requestSchema(path: String, method: String) throws -> [String: Any] {
        let spec = try Self.loadedSpec()
        let operation = try Self.operation(method, path, in: spec)
        let body = try object("requestBody", in: operation, "\(method) \(path)")
        let content = try object("content", in: body, "request body of \(method) \(path)")
        return try object("schema", in: try object("application/json", in: content, "content"), "application/json schema")
    }

    private func resolved(_ schema: [String: Any], in spec: [String: Any]) throws -> [String: Any] {
        guard let ref = schema["$ref"] as? String else { return schema }
        let prefix = "#/components/schemas/"
        XCTAssertTrue(ref.hasPrefix(prefix), "Unsupported $ref \"\(ref)\"; vendored spec must reference component schemas.")
        let components = try object("components", in: spec, "spec")
        let schemas = try object("schemas", in: components, "components")
        return try object(String(ref.dropFirst(prefix.count)), in: schemas, "components.schemas")
    }

    private func properties(of schema: [String: Any], in spec: [String: Any], _ context: String) throws -> [String: Any] {
        try XCTUnwrap(try resolved(schema, in: spec)["properties"] as? [String: Any], "Missing properties on \(context).")
    }

    private func property(_ name: String, of schema: [String: Any], in spec: [String: Any], _ context: String) throws -> [String: Any] {
        try XCTUnwrap(try properties(of: schema, in: spec, context)[name] as? [String: Any], "Missing property \"\(name)\" on \(context).")
    }

    private func itemsSchema(_ arrayName: String, of schema: [String: Any], in spec: [String: Any]) throws -> [String: Any] {
        let array = try property(arrayName, of: schema, in: spec, "schema")
        return try object("items", in: array, "\(arrayName) items")
    }

    private func itemProperties(_ arrayName: String, of schema: [String: Any], in spec: [String: Any]) throws -> [String: Any] {
        try properties(of: try itemsSchema(arrayName, of: schema, in: spec), in: spec, "\(arrayName) items")
    }

    private func rectSchema(of schema: [String: Any], in spec: [String: Any]) throws -> [String: Any] {
        let patchItems = try itemsSchema("patches", of: schema, in: spec)
        return try property("rect", of: patchItems, in: spec, "manifest patches items")
    }

    private func requireKeys(_ keys: [String], in properties: [String: Any], _ context: String) {
        for key in keys {
            XCTAssertNotNil(properties[key], "Vendored spec must declare \"\(key)\" in \(context); see docs/ios-openapi-client-plan.md.")
        }
    }
}
