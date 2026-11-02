import Foundation
import XCTest

final class OpenAPISpecCoverageTests: XCTestCase {
    private static let specURL: URL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("iOS/OpenAPI/openapi.json")

    private enum SpecError: Error { case unavailable }

    func testVendoredSpecDocumentExists() throws {
        _ = try loadedSpec()
    }

    func testSpecDeclaresOpenAPI3() throws {
        let spec = try loadedSpec()
        let version = try unwrap(spec["openapi"] as? String, "Document has no \"openapi\" version field")
        XCTAssertTrue(version.hasPrefix("3."), "Expected an OpenAPI 3 document, got \(version)")
    }

    func testSpecCoversAllOperationsTheAppUses() throws {
        let spec = try loadedSpec()
        let expected: [(method: String, path: String, operationID: String)] = [
            ("get", "/api/v1/test_sheets/{sheet_id}/manifest", "getTestSheetManifest"),
            ("get", "/api/v1/test_sheets/recent", "listRecentTestSheets"),
            ("get", "/api/v1/test_sheets/{sheet_id}/ranked_results", "getRankedResults"),
            ("post", "/api/v1/test_sheets/{sheet_id}/captures", "createCapture"),
            ("post", "/api/v1/captures/{capture_id}/measurements", "uploadMeasurements"),
            ("post", "/api/v1/captures/{capture_id}/judgments", "uploadJudgments")
        ]

        for expectation in expected {
            let operation = try self.operation(spec, expectation.method, expectation.path)
            XCTAssertEqual(operation["operationId"] as? String, expectation.operationID)
        }
    }

    func testManifestSchemaMatchesProseContract() throws {
        let spec = try loadedSpec()
        try assertJSONResponseSchema(spec, method: "get", path: "/api/v1/test_sheets/{sheet_id}/manifest", status: "200", component: "TestSheetManifest")

        let keys = try properties(ofComponent: "TestSheetManifest", in: spec)
        assertProperties([
            "schema_version", "sheet_id", "sheet_version", "manifest_url", "created_at",
            "page", "registration_markers", "printer_profile", "capture_profile", "patches", "pairs"
        ], in: keys, of: "TestSheetManifest")
        assertProperties([
            "units", "width", "height", "role", "shape", "rect",
            "printer_make_model", "paper_type", "ink_type", "print_settings",
            "expected_illuminant", "preferred_camera", "scoring_algorithm_version",
            "id", "pair_id", "pair_side", "reference_role", "source_color", "safe_inset_mm",
            "first_patch_id", "second_patch_id", "source_colors", "grid_row", "grid_col"
        ], in: keys, of: "TestSheetManifest")

        let manifestEnums = try enums(ofComponent: "TestSheetManifest", in: spec)
        assertEnumContains(manifestEnums, "lps-sheet-manifest/v1", in: "TestSheetManifest")
        assertEnumContains(manifestEnums, "lps-distance-v1", in: "TestSheetManifest")
    }

    func testRecentSheetsSchemaMatchesProseContract() throws {
        let spec = try loadedSpec()
        try assertJSONResponseSchema(spec, method: "get", path: "/api/v1/test_sheets/recent", status: "200", component: "RecentSheetsResponse")

        let keys = try properties(ofComponent: "RecentSheetsResponse", in: spec)
        assertProperties(["sheets", "sheet_id", "manifest_url", "title"], in: keys, of: "RecentSheetsResponse")
    }

    func testCaptureCreationSchemaMatchesProseContract() throws {
        let spec = try loadedSpec()
        try assertJSONRequestBody(spec, method: "post", path: "/api/v1/test_sheets/{sheet_id}/captures")
        try assertJSONResponseSchema(spec, method: "post", path: "/api/v1/test_sheets/{sheet_id}/captures", status: "201", component: "CaptureCreatedResponse")

        let requestKeys = try properties(ofComponent: "CaptureRequest", in: spec)
        assertProperties(["metadata", "quality", "detected_marker_count", "blur_score", "rejections"], in: requestKeys, of: "CaptureRequest")

        let metadataKeys = try properties(ofComponent: "CaptureMetadata", in: spec)
        assertProperties([
            "device_model", "lens", "exposure_duration_seconds", "iso", "focus_lens_position",
            "white_balance_gains", "red", "green", "blue", "image_width", "image_height",
            "app_version", "timestamp"
        ], in: metadataKeys, of: "CaptureMetadata")

        let qualityKeys = try properties(ofComponent: "CaptureQuality", in: spec)
        assertProperties(["detected_marker_count", "blur_score", "rejections"], in: qualityKeys, of: "CaptureQuality")

        let createdKeys = try properties(ofComponent: "CaptureCreatedResponse", in: spec)
        assertProperties(["capture_id"], in: createdKeys, of: "CaptureCreatedResponse")
    }

    func testMeasurementUploadSchemaMatchesProseContract() throws {
        let spec = try loadedSpec()
        try assertJSONRequestBody(spec, method: "post", path: "/api/v1/captures/{capture_id}/measurements")
        try assertJSONResponseSchema(spec, method: "post", path: "/api/v1/captures/{capture_id}/measurements", status: "200", component: "MeasurementUploadResponse")

        let requestKeys = try properties(ofComponent: "MeasurementUploadRequest", in: spec)
        assertProperties(["scoring_algorithm_version", "measurements", "pair_scores"], in: requestKeys, of: "MeasurementUploadRequest")

        let measurementKeys = try properties(ofComponent: "MeasurementUpload", in: spec)
        assertProperties([
            "patch_id", "linear_rgb_median", "normalized_linear_rgb_median", "stats", "r", "g", "b"
        ], in: measurementKeys, of: "MeasurementUpload")

        let statsKeys = try properties(ofComponent: "MeasurementStats", in: spec)
        assertProperties([
            "sample_count", "clipping_fraction", "mean", "standard_deviation"
        ], in: statsKeys, of: "MeasurementStats")

        let scoreKeys = try properties(ofComponent: "PairScoreUpload", in: spec)
        assertProperties(["pair_id", "distance", "similarity", "algorithm_version"], in: scoreKeys, of: "PairScoreUpload")

        let responseKeys = try properties(ofComponent: "MeasurementUploadResponse", in: spec)
        assertProperties(["capture_id", "measurement_count", "pair_score_count"], in: responseKeys, of: "MeasurementUploadResponse")
    }

    func testJudgmentUploadSchemaMatchesProseContract() throws {
        let spec = try loadedSpec()
        try assertJSONRequestBody(spec, method: "post", path: "/api/v1/captures/{capture_id}/judgments")
        try assertJSONResponseSchema(spec, method: "post", path: "/api/v1/captures/{capture_id}/judgments", status: "200", component: "JudgmentUploadResponse")

        let requestKeys = try properties(ofComponent: "JudgmentUploadRequest", in: spec)
        assertProperties(["judgments", "pair_id", "judgment"], in: requestKeys, of: "JudgmentUploadRequest")

        let responseKeys = try properties(ofComponent: "JudgmentUploadResponse", in: spec)
        assertProperties(["capture_id", "judgment_count"], in: responseKeys, of: "JudgmentUploadResponse")
    }

    func testRankedResultsSchemaMatchesProseContract() throws {
        let spec = try loadedSpec()
        try assertJSONResponseSchema(spec, method: "get", path: "/api/v1/test_sheets/{sheet_id}/ranked_results", status: "200", component: "RankedResults")

        let keys = try properties(ofComponent: "RankedResults", in: spec)
        assertProperties([
            "schema_version", "sheet_id", "capture_count", "latest_capture_at", "earliest_capture_at",
            "scoring_algorithm_versions", "results"
        ], in: keys, of: "RankedResults")

        let resultKeys = try properties(ofComponent: "RankedPairResult", in: spec)
        assertProperties([
            "rank", "pair_id", "scoring_algorithm_version", "row", "col", "source_colors",
            "color_a_hex", "color_b_hex", "score", "average", "latest", "minimum", "maximum",
            "sample_count", "algorithm_versions", "current_judgment", "current_judgment_observed_at",
            "observation_count", "latest_observation", "observed_at", "judgment"
        ], in: resultKeys, of: "RankedPairResult")

        let topEnums = try enums(ofComponent: "RankedResults", in: spec)
        assertEnumContains(topEnums, "lps-ranked-results/v1", in: "RankedResults")
    }

    private func loadedSpec(file: StaticString = #filePath, line: UInt = #line) throws -> [String: Any] {
        let path = Self.specURL.path
        guard FileManager.default.fileExists(atPath: path) else {
            XCTFail("Vendored OpenAPI document is missing at iOS/OpenAPI/openapi.json; vendor it from viamin/color_matching#110 (see docs/openapi-generated-client-tests.md)", file: file, line: line)
            throw SpecError.unavailable
        }
        let data = try Data(contentsOf: Self.specURL)
        return try unwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any], "Vendored document at \(path) is not a JSON object", file: file, line: line)
    }

    private func unwrap<T>(_ value: T?, _ message: @autoclosure () -> String, file: StaticString = #filePath, line: UInt = #line) throws -> T {
        guard let value else {
            XCTFail(message(), file: file, line: line)
            throw SpecError.unavailable
        }
        return value
    }

    private func operation(_ spec: [String: Any], _ method: String, _ path: String, file: StaticString = #filePath, line: UInt = #line) throws -> [String: Any] {
        let paths = try normalizedPaths(spec, file: file, line: line)
        let item = try unwrap(paths[path] as? [String: Any], "Path \(path) is not declared; declared paths: \(paths.keys.sorted())", file: file, line: line)
        return try unwrap(item[method] as? [String: Any], "Path \(path) has no \(method.uppercased()) operation", file: file, line: line)
    }

    private func normalizedPaths(_ spec: [String: Any], file: StaticString = #filePath, line: UInt = #line) throws -> [String: Any] {
        let paths = try unwrap(spec["paths"] as? [String: Any], "Document declares no paths", file: file, line: line)
        let servers = spec["servers"] as? [[String: Any]] ?? []
        let serverCarriesAPIv1 = servers.compactMap { $0["url"] as? String }.contains { $0.hasSuffix("/api/v1") }
        guard serverCarriesAPIv1 else { return paths }
        return Dictionary(paths.map { ("/api/v1" + $0.key, $0.value) }, uniquingKeysWith: { first, _ in first })
    }

    private func component(_ spec: [String: Any], _ name: String, file: StaticString = #filePath, line: UInt = #line) throws -> [String: Any] {
        let components = try unwrap(spec["components"] as? [String: Any], "Document declares no components", file: file, line: line)
        let schemas = try unwrap(components["schemas"] as? [String: Any], "Document declares no components.schemas", file: file, line: line)
        return try unwrap(schemas[name] as? [String: Any], "Schema components.schemas.\(name) is not declared", file: file, line: line)
    }

    private func properties(ofComponent name: String, in spec: [String: Any]) throws -> Set<String> {
        var keys = Set<String>()
        var visitedRefs = Set<String>()
        collectProperties(try component(spec, name), in: spec, into: &keys, visitedRefs: &visitedRefs)
        return keys
    }

    private func enums(ofComponent name: String, in spec: [String: Any]) throws -> [[String]] {
        var collected = [[String]]()
        var visitedRefs = Set<String>()
        collectEnums(try component(spec, name), in: spec, into: &collected, visitedRefs: &visitedRefs)
        return collected
    }

    private func collectProperties(_ schema: [String: Any], in spec: [String: Any], into keys: inout Set<String>, visitedRefs: inout Set<String>) {
        if let ref = schema["$ref"] as? String {
            guard visitedRefs.insert(ref).inserted, let resolved = resolveRef(ref, in: spec) else { return }
            collectProperties(resolved, in: spec, into: &keys, visitedRefs: &visitedRefs)
            return
        }
        for combiner in ["oneOf", "anyOf", "allOf"] {
            for subschema in schema[combiner] as? [[String: Any]] ?? [] {
                collectProperties(subschema, in: spec, into: &keys, visitedRefs: &visitedRefs)
            }
        }
        if let properties = schema["properties"] as? [String: Any] {
            keys.formUnion(properties.keys)
            for subschema in properties.values {
                collectProperties(subschema as? [String: Any] ?? [:], in: spec, into: &keys, visitedRefs: &visitedRefs)
            }
        }
        if let items = schema["items"] as? [String: Any] {
            collectProperties(items, in: spec, into: &keys, visitedRefs: &visitedRefs)
        }
    }

    private func collectEnums(_ schema: [String: Any], in spec: [String: Any], into collected: inout [[String]], visitedRefs: inout Set<String>) {
        if let ref = schema["$ref"] as? String {
            guard visitedRefs.insert(ref).inserted, let resolved = resolveRef(ref, in: spec) else { return }
            collectEnums(resolved, in: spec, into: &collected, visitedRefs: &visitedRefs)
            return
        }
        for combiner in ["oneOf", "anyOf", "allOf"] {
            for subschema in schema[combiner] as? [[String: Any]] ?? [] {
                collectEnums(subschema, in: spec, into: &collected, visitedRefs: &visitedRefs)
            }
        }
        if let values = schema["enum"] as? [Any] {
            collected.append(values.compactMap { $0 as? String })
        }
        for subschema in (schema["properties"] as? [String: Any] ?? []).values {
            collectEnums(subschema as? [String: Any] ?? [:], in: spec, into: &collected, visitedRefs: &visitedRefs)
        }
        if let items = schema["items"] as? [String: Any] {
            collectEnums(items, in: spec, into: &collected, visitedRefs: &visitedRefs)
        }
    }

    private func resolveRef(_ ref: String, in spec: [String: Any]) -> [String: Any]? {
        var current: Any = spec
        for segment in ref.split(separator: "/").dropFirst() {
            guard let dictionary = current as? [String: Any], let next = dictionary[String(segment)] else { return nil }
            current = next
        }
        return current as? [String: Any]
    }

    private func assertProperties(_ required: [String], in keys: Set<String>, of schemaName: String, file: StaticString = #filePath, line: UInt = #line) {
        let missing = required.filter { !keys.contains($0) }
        XCTAssertTrue(missing.isEmpty, "Schema \(schemaName) is missing properties \(missing.sorted()); the vendored spec must type the payload the app consumes", file: file, line: line)
    }

    private func assertEnumContains(_ enums: [[String]], _ value: String, in schemaName: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(enums.contains { $0.contains(value) }, "Schema \(schemaName) declares no enum containing \"\(value)\"", file: file, line: line)
    }

    private func assertJSONRequestBody(_ spec: [String: Any], method: String, path: String, file: StaticString = #filePath, line: UInt = #line) throws {
        let operation = try self.operation(spec, method, path, file: file, line: line)
        let body = try unwrap(operation["requestBody"] as? [String: Any], "Operation \(path) declares no requestBody", file: file, line: line)
        let content = try unwrap(body["content"] as? [String: Any], "Operation \(path) requestBody declares no content", file: file, line: line)
        XCTAssertNotNil(content["application/json"], "Operation \(path) requestBody must accept application/json", file: file, line: line)
    }

    private func assertJSONResponseSchema(_ spec: [String: Any], method: String, path: String, status: String, component name: String, file: StaticString = #filePath, line: UInt = #line) throws {
        let operation = try self.operation(spec, method, path, file: file, line: line)
        let responses = try unwrap(operation["responses"] as? [String: Any], "Operation \(path) declares no responses", file: file, line: line)
        let response = try unwrap(responses[status] as? [String: Any], "Operation \(path) declares no \(status) response", file: file, line: line)
        let content = try unwrap(response["content"] as? [String: Any], "Response \(status) of \(path) declares no content", file: file, line: line)
        let json = try unwrap(content["application/json"] as? [String: Any], "Response \(status) of \(path) must be application/json", file: file, line: line)
        let schema = try unwrap(json["schema"] as? [String: Any], "Response \(status) of \(path) declares no schema", file: file, line: line)
        let ref = try unwrap(schema["$ref"] as? String, "Response \(status) of \(path) must reference a component schema, got \(schema)", file: file, line: line)
        XCTAssertTrue(ref.hasSuffix("/\(name)"), "Response \(status) of \(path) references \(ref), expected \(name)", file: file, line: line)
    }
}
