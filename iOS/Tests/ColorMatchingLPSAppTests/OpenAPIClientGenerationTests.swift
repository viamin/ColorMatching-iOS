import Foundation
import XCTest

final class OpenAPIClientGenerationTests: XCTestCase {
    private struct SpecRequirementError: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    private static var packageRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    func testVendoredOpenAPIDocumentIsCheckedInAsOpenAPI3JSON() throws {
        let spec = try Self.loadVendoredSpec()
        let version = try XCTUnwrap(spec["openapi"] as? String, "vendored document must declare an openapi version string")
        XCTAssertTrue(version.hasPrefix("3."), "vendored document must be OpenAPI 3.x, found \(version)")
    }

    func testPackageManifestDeclaresOpenAPIToolchain() throws {
        let manifest = try String(contentsOf: Self.packageRoot.appendingPathComponent("Package.swift"), encoding: .utf8)
        XCTAssertTrue(manifest.contains("swift-openapi-generator"), "Package.swift must declare the apple/swift-openapi-generator dependency for build-time client generation")
        XCTAssertTrue(manifest.contains("swift-openapi-runtime"), "Package.swift must declare the apple/swift-openapi-runtime dependency used by the generated client")
        XCTAssertTrue(manifest.contains("GenerateOpenAPIClient"), "Package.swift must apply the GenerateOpenAPIClient build plugin to the client target")
    }

    func testGeneratedClientSourcesExistUnderSources() throws {
        let sources = Self.packageRoot.appendingPathComponent("Sources").path
        let generatedSwiftFiles = ((try? FileManager.default.subpaths(atPath: sources)) ?? [])
            .filter { $0.contains("OpenAPIGenerated/") && $0.hasSuffix(".swift") }
        XCTAssertFalse(
            generatedSwiftFiles.isEmpty,
            "expected swift-openapi-generator output under Sources/**/OpenAPIGenerated/, found none"
        )
    }

    func testSpecCoversEverySurfaceTheAppUses() throws {
        let spec = try Self.loadVendoredSpec()
        let requiredSurfaces: [(method: String, path: String)] = [
            ("get", "/api/v1/test_sheets/recent"),
            ("get", "/api/v1/test_sheets/{}/manifest"),
            ("post", "/api/v1/test_sheets/{}/captures"),
            ("post", "/api/v1/captures/{}/measurements"),
            ("post", "/api/v1/captures/{}/judgments"),
            ("get", "/api/v1/test_sheets/{}/ranked_results"),
        ]
        for surface in requiredSurfaces {
            let operation = try Self.operation(surface.method, atNormalizedPath: surface.path, in: spec)
            let operationID = try XCTUnwrap(
                operation["operationId"] as? String,
                "\(surface.method.uppercased()) \(surface.path) must declare an operationId so generated client method names stay stable"
            )
            XCTAssertFalse(operationID.isEmpty, "\(surface.method.uppercased()) \(surface.path) declares an empty operationId")
        }
    }

    func testManifestResponseSchemaExposesFieldsTheAppDecodes() throws {
        let spec = try Self.loadVendoredSpec()
        let operation = try Self.operation("get", atNormalizedPath: "/api/v1/test_sheets/{}/manifest", in: spec)
        let schema = try XCTUnwrap(
            try Self.successResponseSchema(for: operation, in: spec),
            "manifest response must declare a 2xx application/json body"
        )
        try Self.requireProperties(
            ["schema_version", "sheet_version", "sheet_id", "manifest_url", "page", "registration_markers", "patches", "pairs"],
            in: schema,
            context: "manifest response"
        )
        try Self.requireProperties(
            ["units", "width", "height"],
            in: try Self.resolvedProperty("page", of: schema, in: spec, context: "manifest response"),
            context: "manifest page"
        )
        let marker = try Self.arrayItemSchema(ofProperty: "registration_markers", in: schema, spec: spec, context: "manifest registration_markers item")
        try Self.requireProperties(["role", "shape", "rect"], in: marker, context: "manifest registration_markers item")
        try Self.requireProperties(
            ["x", "y", "width", "height"],
            in: try Self.resolvedProperty("rect", of: marker, in: spec, context: "manifest registration_markers item"),
            context: "manifest marker rect"
        )
        let patch = try Self.arrayItemSchema(ofProperty: "patches", in: schema, spec: spec, context: "manifest patches item")
        try Self.requireProperties(
            ["id", "role", "pair_id", "pair_side", "reference_role", "source_color", "safe_inset_mm", "rect"],
            in: patch,
            context: "manifest patches item"
        )
        try Self.requireProperties(
            ["x", "y", "width", "height"],
            in: try Self.resolvedProperty("rect", of: patch, in: spec, context: "manifest patches item"),
            context: "manifest patch rect"
        )
        let pair = try Self.arrayItemSchema(ofProperty: "pairs", in: schema, spec: spec, context: "manifest pairs item")
        try Self.requireProperties(
            ["id", "first_patch_id", "second_patch_id", "source_colors", "grid_row", "grid_col"],
            in: pair,
            context: "manifest pairs item"
        )
    }

    func testRecentSheetsResponseSchemaExposesFieldsTheAppDecodes() throws {
        let spec = try Self.loadVendoredSpec()
        let operation = try Self.operation("get", atNormalizedPath: "/api/v1/test_sheets/recent", in: spec)
        let schema = try XCTUnwrap(
            try Self.successResponseSchema(for: operation, in: spec),
            "recent sheets response must declare a 2xx application/json body"
        )
        let sheet = try Self.arrayItemSchema(ofProperty: "sheets", in: schema, spec: spec, context: "recent sheets item")
        try Self.requireProperties(["sheet_id", "manifest_url", "title"], in: sheet, context: "recent sheets item")
    }

    func testCreateCaptureSchemaExposesFieldsTheAppSendsAndReads() throws {
        let spec = try Self.loadVendoredSpec()
        let operation = try Self.operation("post", atNormalizedPath: "/api/v1/test_sheets/{}/captures", in: spec)
        let request = try Self.requestBodySchema(for: operation, in: spec)
        try Self.requireProperties(["metadata", "quality"], in: request, context: "create capture request")
        try Self.requireProperties(
            [
                "device_model", "lens", "exposure_duration_seconds", "iso", "focus_lens_position",
                "white_balance_gains", "image_width", "image_height", "app_version", "timestamp",
            ],
            in: try Self.resolvedProperty("metadata", of: request, in: spec, context: "create capture request"),
            context: "create capture metadata"
        )
        try Self.requireProperties(
            ["detected_marker_count", "blur_score", "rejections"],
            in: try Self.resolvedProperty("quality", of: request, in: spec, context: "create capture request"),
            context: "create capture quality"
        )
        let response = try XCTUnwrap(
            try Self.successResponseSchema(for: operation, in: spec),
            "create capture response must declare a 2xx application/json body"
        )
        try Self.requireProperties(["capture_id"], in: response, context: "create capture response")
    }

    func testMeasurementUploadRequestSchemaExposesFieldsTheAppSends() throws {
        let spec = try Self.loadVendoredSpec()
        let operation = try Self.operation("post", atNormalizedPath: "/api/v1/captures/{}/measurements", in: spec)
        let request = try Self.requestBodySchema(for: operation, in: spec)
        try Self.requireProperties(
            ["scoring_algorithm_version", "measurements", "pair_scores"],
            in: request,
            context: "measurement upload request"
        )
        let measurement = try Self.arrayItemSchema(ofProperty: "measurements", in: request, spec: spec, context: "measurement upload item")
        try Self.requireProperties(
            ["patch_id", "linear_rgb_median", "normalized_linear_rgb_median", "stats"],
            in: measurement,
            context: "measurement upload item"
        )
        try Self.requireProperties(
            ["sample_count", "clipping_fraction", "mean", "standard_deviation"],
            in: try Self.resolvedProperty("stats", of: measurement, in: spec, context: "measurement upload item"),
            context: "measurement upload stats"
        )
        let score = try Self.arrayItemSchema(ofProperty: "pair_scores", in: request, spec: spec, context: "pair score item")
        try Self.requireProperties(["pair_id", "distance", "similarity", "algorithm_version"], in: score, context: "pair score item")
    }

    func testJudgmentUploadRequestSchemaExposesFieldsTheAppSends() throws {
        let spec = try Self.loadVendoredSpec()
        let operation = try Self.operation("post", atNormalizedPath: "/api/v1/captures/{}/judgments", in: spec)
        let request = try Self.requestBodySchema(for: operation, in: spec)
        let judgment = try Self.arrayItemSchema(ofProperty: "judgments", in: request, spec: spec, context: "judgment upload item")
        try Self.requireProperties(["pair_id", "judgment"], in: judgment, context: "judgment upload item")
    }

    func testRankedResultsResponseContainsPairScores() throws {
        let spec = try Self.loadVendoredSpec()
        let operation = try Self.operation("get", atNormalizedPath: "/api/v1/test_sheets/{}/ranked_results", in: spec)
        let schema = try XCTUnwrap(
            try Self.successResponseSchema(for: operation, in: spec),
            "ranked results must declare a 2xx application/json response body"
        )
        XCTAssertTrue(
            try Self.containsPairScoreItems(schema, in: spec),
            "ranked results response must include an array of pair scores (pair_id plus distance, similarity, or algorithm_version)"
        )
    }

    private static func loadVendoredSpec() throws -> [String: Any] {
        let url = packageRoot.appendingPathComponent("OpenAPI/color-matching-api.json")
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw SpecRequirementError(
                message: "missing vendored OpenAPI document at \(url.path); vendor the published spec from viamin/color_matching#110 as JSON"
            )
        }
        let data = try Data(contentsOf: url)
        return try XCTUnwrap(
            try JSONSerialization.jsonObject(with: data) as? [String: Any],
            "vendored OpenAPI document must be a JSON object"
        )
    }

    private static func normalizedPath(_ path: String) -> String {
        path.split(separator: "/").map { $0.hasPrefix("{") ? "{}" : String($0) }.joined(separator: "/")
    }

    private static func operation(_ method: String, atNormalizedPath target: String, in spec: [String: Any]) throws -> [String: Any] {
        let paths = try XCTUnwrap(spec["paths"] as? [String: Any], "vendored spec must declare a paths object")
        for (path, value) in paths {
            guard normalizedPath(path) == target, let operations = value as? [String: Any] else { continue }
            if let operation = operations[method] as? [String: Any] {
                return operation
            }
            throw SpecRequirementError(message: "path \(path) in the vendored spec does not support \(method.uppercased())")
        }
        throw SpecRequirementError(message: "vendored spec declares no \(method.uppercased()) operation for normalized path \(target)")
    }

    private static func resolved(_ node: Any, in spec: [String: Any]) throws -> [String: Any] {
        guard let schema = node as? [String: Any] else {
            throw SpecRequirementError(message: "expected an object schema node, found \(String(describing: type(of: node)))")
        }
        guard let reference = schema["$ref"] as? String else { return schema }
        guard reference.hasPrefix("#/") else {
            throw SpecRequirementError(message: "unsupported external $ref \(reference); vendor a spec that only references local components")
        }
        var current: Any = spec
        for segment in reference.dropFirst(2).split(separator: "/") {
            guard let container = current as? [String: Any], let next = container[String(segment)] else {
                throw SpecRequirementError(message: "unresolvable $ref \(reference) in the vendored spec")
            }
            current = next
        }
        return try resolved(current, in: spec)
    }

    private static func requireProperties(_ names: [String], in schema: [String: Any], context: String) throws {
        let properties = try XCTUnwrap(schema["properties"] as? [String: Any], "\(context) schema must declare properties")
        for name in names {
            XCTAssertNotNil(properties[name], "\(context) is missing property \(name) required by docs/color-matching-api-contract.md")
        }
    }

    private static func resolvedProperty(_ name: String, of schema: [String: Any], in spec: [String: Any], context: String) throws -> [String: Any] {
        let properties = try XCTUnwrap(schema["properties"] as? [String: Any], "\(context) schema must declare properties")
        return try resolved(
            try XCTUnwrap(properties[name], "\(context) is missing property \(name) required by docs/color-matching-api-contract.md"),
            in: spec
        )
    }

    private static func arrayItemSchema(ofProperty name: String, in schema: [String: Any], spec: [String: Any], context: String) throws -> [String: Any] {
        let arraySchema = try resolvedProperty(name, of: schema, in: spec, context: context)
        let items = try XCTUnwrap(arraySchema["items"], "\(context) must be an array declaring items")
        return try resolved(items, in: spec)
    }

    private static func requestBodySchema(for operation: [String: Any], in spec: [String: Any]) throws -> [String: Any] {
        let body = try XCTUnwrap(operation["requestBody"] as? [String: Any], "operation must declare a requestBody")
        let content = try XCTUnwrap(body["content"] as? [String: Any], "requestBody must declare content")
        let json = try XCTUnwrap(content["application/json"] as? [String: Any], "requestBody must declare application/json content")
        return try resolved(
            try XCTUnwrap(json["schema"], "application/json requestBody must declare a schema"),
            in: spec
        )
    }

    private static func successResponseSchema(for operation: [String: Any], in spec: [String: Any]) throws -> [String: Any]? {
        let responses = try XCTUnwrap(operation["responses"] as? [String: Any], "operation must declare responses")
        let successCodes = responses.keys
            .compactMap { Int($0) }
            .filter { (200..<300).contains($0) }
            .sorted()
        for code in successCodes {
            guard let response = responses[String(code)] as? [String: Any],
                  let content = response["content"] as? [String: Any],
                  let json = content["application/json"] as? [String: Any],
                  let schemaNode = json["schema"] else { continue }
            return try resolved(schemaNode, in: spec)
        }
        return nil
    }

    private static func containsPairScoreItems(_ schema: [String: Any], in spec: [String: Any]) throws -> Bool {
        let properties = (schema["properties"] as? [String: Any]) ?? [:]
        for (_, node) in properties {
            guard let propertySchema = try? resolved(node, in: spec),
                  let items = propertySchema["items"] else { continue }
            guard let itemSchema = try? resolved(items, in: spec),
                  let itemProperties = itemSchema["properties"] as? [String: Any] else { continue }
            let keys = Set(itemProperties.keys)
            if keys.contains("pair_id"), !keys.isDisjoint(with: ["distance", "similarity", "algorithm_version"]) {
                return true
            }
        }
        return false
    }
}
