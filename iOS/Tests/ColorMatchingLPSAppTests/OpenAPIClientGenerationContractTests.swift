import XCTest

// Intentionally exceeds the ~100-line class guidance: this suite is the
// machine-checked contract for the vendored OpenAPI document and generated
// client wiring required by issue #5. Each test pins one contract fact so a
// regeneration diff points at the exact drift.
final class OpenAPIClientGenerationContractTests: XCTestCase {
    private lazy var packageRoot: URL = {
        var url = URL(fileURLWithPath: #filePath)
        url.deleteLastPathComponent()
        url.deleteLastPathComponent()
        url.deleteLastPathComponent()
        return url
    }()

    func testVendoredOpenAPIDocumentExistsAndParses() throws {
        let specURL = packageRoot.appending(path: "Sources/ColorMatchingOpenAPI/openapi.json")
        let exists = FileManager.default.fileExists(atPath: specURL.path)
        XCTAssertTrue(exists, "Vendored OpenAPI document missing at Sources/ColorMatchingOpenAPI/openapi.json (issue #5)")
        let spec = try loadSpec()
        let version = try XCTUnwrap(spec["openapi"] as? String, "openapi field must be a string")
        XCTAssertTrue(version.hasPrefix("3."), "expected OpenAPI 3.x, got \(version)")
        let info = try XCTUnwrap(spec["info"] as? [String: Any], "spec must declare info")
        XCTAssertFalse((info["title"] as? String ?? "").isEmpty, "info.title must be non-empty")
        let servers = try XCTUnwrap(spec["servers"] as? [Any], "spec must declare servers")
        XCTAssertFalse(servers.isEmpty, "spec must declare at least one server entry")
    }

    func testPackageManifestDeclaresOpenAPIGeneratorToolchain() throws {
        let text = try packageManifestText()
        XCTAssertTrue(text.contains("swift-openapi-generator"), "Package.swift must depend on swift-openapi-generator")
        XCTAssertTrue(text.contains("swift-openapi-runtime"), "Package.swift must depend on swift-openapi-runtime")
        XCTAssertTrue(text.contains("OpenAPIGeneratorPlugin"), "Package.swift must apply the OpenAPIGeneratorPlugin to the generated target")
        XCTAssertTrue(text.contains("ColorMatchingOpenAPI"), "Package.swift must declare the ColorMatchingOpenAPI target and wire it into dependents")
    }

    func testGeneratorConfigGeneratesTypesAndClient() throws {
        let configURL = packageRoot.appending(path: "Sources/ColorMatchingOpenAPI/openapi-generator.yml")
        XCTAssertTrue(FileManager.default.fileExists(atPath: configURL.path), "openapi-generator.yml missing next to the vendored spec")
        let text = try String(contentsOf: configURL, encoding: .utf8)
        XCTAssertTrue(text.contains("types"), "generator config must generate types")
        XCTAssertTrue(text.contains("client"), "generator config must generate the client")
    }

    func testSpecDeclaresGetSheetManifestSurface() throws {
        let spec = try loadSpec()
        let operation = try operation("get", path: "/api/v1/test_sheets/{sheet_id}/manifest", in: spec)
        XCTAssertEqual(operation["operationId"] as? String, "getSheetManifest")
        try assertDeclaresPathParameter("sheet_id", in: operation)
        _ = try responseSchema("200", of: operation, in: spec)
    }

    func testSpecDeclaresListRecentSheetsSurface() throws {
        let spec = try loadSpec()
        let operation = try operation("get", path: "/api/v1/test_sheets/recent", in: spec)
        XCTAssertEqual(operation["operationId"] as? String, "listRecentSheets")
        _ = try responseSchema("200", of: operation, in: spec)
    }

    func testSpecDeclaresCreateCaptureSessionSurface() throws {
        let spec = try loadSpec()
        let operation = try operation("post", path: "/api/v1/test_sheets/{sheet_id}/captures", in: spec)
        XCTAssertEqual(operation["operationId"] as? String, "createCaptureSession")
        try assertDeclaresPathParameter("sheet_id", in: operation)
        _ = try requestSchema(of: operation, in: spec)
        let schema = try responseSchema("201", of: operation, in: spec)
        try assertHasProperties(schema, ["capture_id"])
    }

    func testSpecDeclaresUploadMeasurementsSurface() throws {
        let spec = try loadSpec()
        let operation = try operation("post", path: "/api/v1/captures/{capture_id}/measurements", in: spec)
        XCTAssertEqual(operation["operationId"] as? String, "uploadMeasurements")
        try assertDeclaresPathParameter("capture_id", in: operation)
        _ = try requestSchema(of: operation, in: spec)
        let responses = try XCTUnwrap(operation["responses"] as? [String: Any])
        XCTAssertNotNil(responses["204"], "measurement upload must declare a 204 response (app treats uploads as no-content success)")
    }

    func testSpecDeclaresUploadJudgmentsSurface() throws {
        let spec = try loadSpec()
        let operation = try operation("post", path: "/api/v1/captures/{capture_id}/judgments", in: spec)
        XCTAssertEqual(operation["operationId"] as? String, "uploadJudgments")
        try assertDeclaresPathParameter("capture_id", in: operation)
        _ = try requestSchema(of: operation, in: spec)
        let responses = try XCTUnwrap(operation["responses"] as? [String: Any])
        XCTAssertNotNil(responses["204"], "judgment upload must declare a 204 response")
    }

    func testSpecDeclaresGetRankedResultsSurface() throws {
        let spec = try loadSpec()
        let operation = try operation("get", path: "/api/v1/test_sheets/{sheet_id}/ranked_results", in: spec)
        XCTAssertEqual(operation["operationId"] as? String, "getRankedResults")
        try assertDeclaresPathParameter("sheet_id", in: operation)
        _ = try responseSchema("200", of: operation, in: spec)
    }

    func testSpecDeclaresBearerAuthSecurityScheme() throws {
        let spec = try loadSpec()
        let components = try XCTUnwrap(spec["components"] as? [String: Any], "spec must declare components")
        let schemes = try XCTUnwrap(components["securitySchemes"] as? [String: Any], "spec must declare securitySchemes")
        let bearerSchemes = schemes.values
            .compactMap { $0 as? [String: Any] }
            .filter { ($0["type"] as? String) == "http" && ($0["scheme"] as? String) == "bearer" }
        XCTAssertFalse(bearerSchemes.isEmpty, "spec must declare an http bearer security scheme per the prose contract")
    }

    func testManifestResponseSchemaCoversAppConsumedFields() throws {
        let spec = try loadSpec()
        let operation = try operation("get", path: "/api/v1/test_sheets/{sheet_id}/manifest", in: spec)
        let schema = try responseSchema("200", of: operation, in: spec)
        try assertHasProperties(schema, [
            "schema_version", "sheet_version", "sheet_id", "manifest_url",
            "registration_markers", "patches", "pairs", "page",
        ])
        let patches = try property("patches", of: schema, in: spec)
        let patch = try items(of: patches, in: spec)
        try assertHasProperties(patch, [
            "id", "role", "pair_id", "pair_side", "reference_role",
            "source_color", "safe_inset_mm", "rect",
        ])
        let pairs = try property("pairs", of: schema, in: spec)
        let pair = try items(of: pairs, in: spec)
        try assertHasProperties(pair, [
            "id", "first_patch_id", "second_patch_id", "source_colors", "grid_row", "grid_col",
        ])
        let page = try property("page", of: schema, in: spec)
        try assertHasProperties(page, ["units", "width", "height"])
    }

    func testCreateCaptureRequestSchemaCoversProseContract() throws {
        let spec = try loadSpec()
        let operation = try operation("post", path: "/api/v1/test_sheets/{sheet_id}/captures", in: spec)
        let schema = try requestSchema(of: operation, in: spec)
        try assertHasProperties(schema, ["metadata", "quality"])
        let metadata = try property("metadata", of: schema, in: spec)
        try assertHasProperties(metadata, [
            "device_model", "lens", "exposure_duration_seconds", "iso", "focus_lens_position",
            "white_balance_gains", "image_width", "image_height", "app_version", "timestamp",
        ])
        let timestamp = try property("timestamp", of: metadata, in: spec)
        XCTAssertEqual(timestamp["format"] as? String, "date-time", "capture timestamp must be an RFC 3339 date-time")
        let gains = try property("white_balance_gains", of: metadata, in: spec)
        try assertHasProperties(gains, ["red", "green", "blue"])
        let quality = try property("quality", of: schema, in: spec)
        try assertHasProperties(quality, ["detected_marker_count", "blur_score", "rejections"])
    }

    func testMeasurementUploadRequestSchemaCoversProseContract() throws {
        let spec = try loadSpec()
        let operation = try operation("post", path: "/api/v1/captures/{capture_id}/measurements", in: spec)
        let schema = try requestSchema(of: operation, in: spec)
        try assertHasProperties(schema, ["scoring_algorithm_version", "measurements", "pair_scores"])
        let measurements = try property("measurements", of: schema, in: spec)
        let measurement = try items(of: measurements, in: spec)
        try assertHasProperties(measurement, ["patch_id", "linear_rgb_median", "normalized_linear_rgb_median", "stats"])
        let stats = try property("stats", of: measurement, in: spec)
        try assertHasProperties(stats, ["sample_count", "clipping_fraction", "mean", "standard_deviation"])
        let rgb = try property("linear_rgb_median", of: measurement, in: spec)
        try assertHasProperties(rgb, ["r", "g", "b"])
        let pairScores = try property("pair_scores", of: schema, in: spec)
        let pairScore = try items(of: pairScores, in: spec)
        try assertHasProperties(pairScore, ["pair_id", "distance", "similarity", "algorithm_version"])
    }

    func testJudgmentUploadRequestSchemaMatchesProseContract() throws {
        let spec = try loadSpec()
        let operation = try operation("post", path: "/api/v1/captures/{capture_id}/judgments", in: spec)
        let schema = try requestSchema(of: operation, in: spec)
        try assertHasProperties(schema, ["judgments"])
        let judgments = try property("judgments", of: schema, in: spec)
        let judgment = try items(of: judgments, in: spec)
        try assertHasProperties(judgment, ["pair_id", "judgment"])
        let value = try property("judgment", of: judgment, in: spec)
        let allowed = try XCTUnwrap(value["enum"] as? [String], "judgment must be an enum so the generated client types it")
        XCTAssertEqual(Set(allowed), ["match", "near_match", "no_match"])
    }

    func testRecentSheetsResponseSchemaCoversProseContract() throws {
        let spec = try loadSpec()
        let operation = try operation("get", path: "/api/v1/test_sheets/recent", in: spec)
        let schema = try responseSchema("200", of: operation, in: spec)
        try assertHasProperties(schema, ["sheets"])
        let sheets = try property("sheets", of: schema, in: spec)
        let sheet = try items(of: sheets, in: spec)
        try assertHasProperties(sheet, ["sheet_id", "manifest_url", "title"])
        let title = try property("title", of: sheet, in: spec)
        let explicitlyNullable = (title["nullable"] as? Bool) == true
        let openAPI31Nullable = (title["type"] as? [Any])?.contains { ($0 as? String) == "null" } == true
        XCTAssertTrue(explicitlyNullable || openAPI31Nullable || title["type"] == nil, "recent-sheet title must allow null per the prose contract")
    }

    private func loadSpec(file: StaticString = #filePath, line: UInt = #line) throws -> [String: Any] {
        let url = packageRoot.appending(path: "Sources/ColorMatchingOpenAPI/openapi.json")
        let data = try Data(contentsOf: url)
        let object = try JSONSerialization.jsonObject(with: data)
        return try XCTUnwrap(object as? [String: Any], "vendored spec must be a JSON object", file: file, line: line)
    }

    private func packageManifestText() throws -> String {
        try String(contentsOf: packageRoot.appending(path: "Package.swift"), encoding: .utf8)
    }

    private func pathItem(_ path: String, in spec: [String: Any], file: StaticString = #filePath, line: UInt = #line) throws -> [String: Any] {
        let paths = try XCTUnwrap(spec["paths"] as? [String: Any], "spec has no paths object", file: file, line: line)
        return try XCTUnwrap(paths[path] as? [String: Any], "spec is missing path \(path)", file: file, line: line)
    }

    private func operation(_ method: String, path: String, in spec: [String: Any], file: StaticString = #filePath, line: UInt = #line) throws -> [String: Any] {
        let item = try pathItem(path, in: spec, file: file, line: line)
        return try XCTUnwrap(item[method] as? [String: Any], "path \(path) has no \(method) operation", file: file, line: line)
    }

    private func resolved(_ schema: [String: Any], in spec: [String: Any], file: StaticString = #filePath, line: UInt = #line) throws -> [String: Any] {
        guard let ref = schema["$ref"] as? String else { return schema }
        let keys = ref.replacingOccurrences(of: "#/", with: "").components(separatedBy: "/")
        var node: Any = spec
        for key in keys {
            let dictionary = try XCTUnwrap(node as? [String: Any], "cannot resolve \(ref) at '\(key)'", file: file, line: line)
            node = try XCTUnwrap(dictionary[key], "cannot resolve \(ref) at '\(key)'", file: file, line: line)
        }
        return try XCTUnwrap(node as? [String: Any], "resolved ref \(ref) is not a schema object", file: file, line: line)
    }

    private func responseSchema(_ status: String, of operation: [String: Any], in spec: [String: Any], file: StaticString = #filePath, line: UInt = #line) throws -> [String: Any] {
        let responses = try XCTUnwrap(operation["responses"] as? [String: Any], "operation declares no responses", file: file, line: line)
        let response = try XCTUnwrap(responses[status] as? [String: Any], "operation is missing a \(status) response", file: file, line: line)
        let content = try XCTUnwrap(try resolved(response, in: spec)["content"] as? [String: Any], "response \(status) has no content map", file: file, line: line)
        let json = try XCTUnwrap(content["application/json"] as? [String: Any], "response \(status) has no application/json content", file: file, line: line)
        let schema = try XCTUnwrap(json["schema"] as? [String: Any], "response \(status) has no schema", file: file, line: line)
        return try resolved(schema, in: spec, file: file, line: line)
    }

    private func requestSchema(of operation: [String: Any], in spec: [String: Any], file: StaticString = #filePath, line: UInt = #line) throws -> [String: Any] {
        let body = try XCTUnwrap(operation["requestBody"] as? [String: Any], "operation declares no requestBody", file: file, line: line)
        let content = try XCTUnwrap(try resolved(body, in: spec)["content"] as? [String: Any], "request body has no content map", file: file, line: line)
        let json = try XCTUnwrap(content["application/json"] as? [String: Any], "request body has no application/json content", file: file, line: line)
        let schema = try XCTUnwrap(json["schema"] as? [String: Any], "request body has no schema", file: file, line: line)
        return try resolved(schema, in: spec, file: file, line: line)
    }

    private func property(_ name: String, of schema: [String: Any], in spec: [String: Any], file: StaticString = #filePath, line: UInt = #line) throws -> [String: Any] {
        let properties = try XCTUnwrap(schema["properties"] as? [String: Any], "schema has no properties", file: file, line: line)
        let raw = try XCTUnwrap(properties[name] as? [String: Any], "schema is missing property '\(name)'", file: file, line: line)
        return try resolved(raw, in: spec, file: file, line: line)
    }

    private func items(of schema: [String: Any], in spec: [String: Any], file: StaticString = #filePath, line: UInt = #line) throws -> [String: Any] {
        let raw = try XCTUnwrap(schema["items"] as? [String: Any], "schema is not an array (no items)", file: file, line: line)
        return try resolved(raw, in: spec, file: file, line: line)
    }

    private func assertHasProperties(_ schema: [String: Any], _ names: [String], file: StaticString = #filePath, line: UInt = #line) throws {
        let properties = try XCTUnwrap(schema["properties"] as? [String: Any], "schema has no properties", file: file, line: line)
        for name in names {
            XCTAssertNotNil(properties[name], "schema is missing property '\(name)'", file: file, line: line)
        }
    }

    private func assertDeclaresPathParameter(_ name: String, in operation: [String: Any], file: StaticString = #filePath, line: UInt = #line) throws {
        let parameters = try XCTUnwrap(operation["parameters"] as? [[String: Any]], "operation declares no parameters", file: file, line: line)
        let match = parameters.first { ($0["name"] as? String) == name }
        let parameter = try XCTUnwrap(match, "operation is missing path parameter '\(name)'", file: file, line: line)
        XCTAssertEqual(parameter["in"] as? String, "path", file: file, line: line)
        XCTAssertEqual(parameter["required"] as? Bool, true, file: file, line: line)
    }
}
