import Foundation
import XCTest

final class VendoredOpenAPISpecTests: XCTestCase {
    private static var vendoredSpecURL: URL {
        let testFile = URL(fileURLWithPath: #filePath)
        return testFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "Sources/GeneratedAPIClient/openapi.json")
    }

    private func loadSpec() throws -> [String: Any] {
        let data = try XCTUnwrap(
            FileManager.default.contents(atPath: Self.vendoredSpecURL.path),
            "Vendored OpenAPI document is missing at iOS/Sources/GeneratedAPIClient/openapi.json. "
                + "Vendor it from GET /api/v1/openapi.json (viamin/color_matching#110) with the "
                + "normalizations recorded in docs/openapi-generated-client.md."
        )
        return try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    func testVendoredSpecDescribesColorMatchingApiV1() throws {
        let spec = try loadSpec()

        let version = try string(in: spec, "openapi")
        XCTAssertTrue(version.hasPrefix("3.0."), "Expected OpenAPI 3.0.x, got \(version)")

        let info = try dictionary(in: spec, "info")
        XCTAssertEqual(try string(in: info, "title"), "Color Matching API")

        let servers = try XCTUnwrap(spec["servers"] as? [[String: Any]])
        XCTAssertFalse(servers.isEmpty)
    }

    func testVendoredSpecDeclaresBearerAuthScheme() throws {
        let spec = try loadSpec()

        let components = try dictionary(in: spec, "components")
        let securitySchemes = try dictionary(in: components, "securitySchemes")
        let bearerAuth = try dictionary(in: securitySchemes, "bearerAuth")
        XCTAssertEqual(try string(in: bearerAuth, "type"), "http")
        XCTAssertEqual(try string(in: bearerAuth, "scheme"), "bearer")
    }

    func testManifestOperationCoversSheetManifestFetch() throws {
        let manifestOperation = try operation(path: "/api/v1/test_sheets/{sheet_id}/manifest", method: "get")

        XCTAssertEqual(try string(in: manifestOperation, "operationId"), "getTestSheetManifest")
        XCTAssertTrue(operationDeclaresResponse(manifestOperation, status: "200"))
        XCTAssertTrue(operationHasPathParameter(manifestOperation, name: "sheet_id"))
        XCTAssertTrue(operationRequiresBearerAuth(manifestOperation))
    }

    func testRecentSheetsOperationCoversDiscovery() throws {
        let recentOperation = try operation(path: "/api/v1/test_sheets/recent", method: "get")

        XCTAssertEqual(try string(in: recentOperation, "operationId"), "listRecentTestSheets")
        XCTAssertTrue(operationDeclaresResponse(recentOperation, status: "200"))
    }

    func testCaptureOperationCoversCaptureCreation() throws {
        let createOperation = try operation(path: "/api/v1/test_sheets/{sheet_id}/captures", method: "post")

        XCTAssertEqual(try string(in: createOperation, "operationId"), "createCapture")
        XCTAssertTrue(operationDeclaresResponse(createOperation, status: "201"))
        XCTAssertTrue(operationHasPathParameter(createOperation, name: "sheet_id"))
        XCTAssertTrue(
            requestBodyReferencesSchema(createOperation, fragment: "CaptureRequest"),
            "createCapture should accept the CaptureRequest JSON body"
        )
    }

    func testMeasurementUploadOperationCoversUpload() throws {
        let measurementOperation = try operation(path: "/api/v1/captures/{capture_id}/measurements", method: "post")

        XCTAssertEqual(try string(in: measurementOperation, "operationId"), "uploadMeasurements")
        XCTAssertTrue(operationDeclaresResponse(measurementOperation, status: "200"))
        XCTAssertTrue(operationHasPathParameter(measurementOperation, name: "capture_id"))
        XCTAssertTrue(
            requestBodyReferencesSchema(measurementOperation, fragment: "MeasurementUploadRequest"),
            "uploadMeasurements should accept the MeasurementUploadRequest JSON body"
        )
    }

    func testJudgmentUploadOperationCoversUpload() throws {
        let judgmentOperation = try operation(path: "/api/v1/captures/{capture_id}/judgments", method: "post")

        XCTAssertEqual(try string(in: judgmentOperation, "operationId"), "uploadJudgments")
        XCTAssertTrue(operationDeclaresResponse(judgmentOperation, status: "200"))
        XCTAssertTrue(operationHasPathParameter(judgmentOperation, name: "capture_id"))
        XCTAssertTrue(
            requestBodyReferencesSchema(judgmentOperation, fragment: "JudgmentUploadRequest"),
            "uploadJudgments should accept the JudgmentUploadRequest JSON body"
        )
    }

    func testRankedResultsOperationCoversResults() throws {
        let rankedOperation = try operation(path: "/api/v1/test_sheets/{sheet_id}/ranked_results", method: "get")

        XCTAssertEqual(try string(in: rankedOperation, "operationId"), "getRankedResults")
        XCTAssertTrue(operationDeclaresResponse(rankedOperation, status: "200"))
        XCTAssertTrue(operationHasPathParameter(rankedOperation, name: "sheet_id"))
    }

    func testManifestSchemaDocumentsOnlyTheVersionedEnvelope() throws {
        let schema = try componentSchema("TestSheetManifest")

        let properties = try dictionary(in: schema, "properties")
        XCTAssertEqual(
            properties.keys.sorted(),
            ["capture_profile", "schema_version", "sheet_id"],
            "Upstream gap (see docs/openapi-generated-client.md): the published spec documents only "
                + "the manifest envelope, so the generated client cannot see sheet_version, "
                + "manifest_url, created_at, page, registration_markers, printer_profile, patches, "
                + "or pairs. Update this pin when upstream documents them."
        )
        XCTAssertEqual((schema["required"] as? [String])?.sorted(), ["capture_profile", "schema_version", "sheet_id"])

        let schemaVersion = try dictionary(in: properties, "schema_version")
        XCTAssertEqual(schemaVersion["enum"] as? [String], ["lps-sheet-manifest/v1"])

        let captureProfile = try dictionary(in: properties, "capture_profile")
        let captureProfileProperties = try dictionary(in: captureProfile, "properties")
        let scoringAlgorithmVersion = try dictionary(in: captureProfileProperties, "scoring_algorithm_version")
        XCTAssertEqual(scoringAlgorithmVersion["enum"] as? [String], ["lps-distance-v1"])
    }

    func testRankedResultsSchemaDocumentsOnlyTheVersionedEnvelope() throws {
        let schema = try componentSchema("RankedResults")

        let properties = try dictionary(in: schema, "properties")
        XCTAssertEqual(
            properties.keys.sorted(),
            ["schema_version", "sheet_id"],
            "Upstream gap (see docs/openapi-generated-client.md): the published spec documents only "
                + "the ranked-results envelope, not the results array, scores, judgments, capture "
                + "provenance, or printer profile. Update this pin when upstream documents them."
        )
        let schemaVersion = try dictionary(in: properties, "schema_version")
        XCTAssertEqual(schemaVersion["enum"] as? [String], ["lps-ranked-results/v1"])
    }

    func testMeasurementUploadSchemaOmitsStatsAndTopLevelAlgorithmVersion() throws {
        let schema = try componentSchema("MeasurementUploadRequest")

        let properties = try dictionary(in: schema, "properties")
        XCTAssertEqual(properties.keys.sorted(), ["measurements", "pair_scores"])
        XCTAssertNil(
            properties["scoring_algorithm_version"],
            "Upstream gap: the published spec moved scoring_algorithm_version into each pair score; "
                + "the app must send it per score."
        )

        let measurements = try dictionary(in: properties, "measurements")
        let items = try dictionary(in: measurements, "items")
        let itemProperties = try dictionary(in: items, "properties")
        XCTAssertEqual(
            itemProperties.keys.sorted(),
            ["linear_rgb_median", "normalized_linear_rgb_median", "patch_id"],
            "Upstream gap (see docs/openapi-generated-client.md): the published spec does not "
                + "document measurement stats (sample_count, clipping_fraction, mean, "
                + "standard_deviation), so the generated client cannot upload them. Update this pin "
                + "when upstream documents stats."
        )
    }

    func testCaptureRequestSchemaIsNormalizedToNestedForm() throws {
        let schema = try componentSchema("CaptureRequest")

        XCTAssertNil(
            schema["anyOf"],
            "Vendor normalization: sibling anyOf+properties is not consumable by swift-openapi-generator "
                + "(properties are dropped), so the vendored spec keeps only the nested form."
        )
        let properties = try dictionary(in: schema, "properties")
        XCTAssertEqual(properties.keys.sorted(), ["metadata", "quality"])

        let metadata = try dictionary(in: properties, "metadata")
        let metadataRef = try string(in: metadata, "$ref")
        XCTAssertTrue(metadataRef.contains("CaptureMetadata"))

        let quality = try dictionary(in: properties, "quality")
        let qualityProperties = try dictionary(in: quality, "properties")
        XCTAssertEqual(qualityProperties.keys.sorted(), ["blur_score", "detected_marker_count", "rejections"])
    }

    func testPairScoreSchemaIsNormalizedToFlatObject() throws {
        let schema = try componentSchema("PairScoreRequest")

        XCTAssertNil(
            schema["anyOf"],
            "Vendor normalization: the score|similarity|distance anyOf is flattened to optional "
                + "properties so the generated client can send pair_id and algorithm_version."
        )
        let properties = try dictionary(in: schema, "properties")
        XCTAssertEqual(
            properties.keys.sorted(),
            ["algorithm_version", "distance", "pair_id", "score", "similarity"]
        )
        XCTAssertEqual(
            (schema["required"] as? [String])?.sorted(),
            ["algorithm_version", "pair_id"]
        )
    }

    private func dictionary(
        in container: [String: Any],
        _ key: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws -> [String: Any] {
        let value = try XCTUnwrap(container[key] as? [String: Any], "Missing object at key '\(key)'", file: file, line: line)
        return value
    }

    private func string(
        in container: [String: Any],
        _ key: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws -> String {
        try XCTUnwrap(container[key] as? String, "Missing string at key '\(key)'", file: file, line: line)
    }

    private func operation(
        path: String,
        method: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws -> [String: Any] {
        let spec = try loadSpec()
        let paths = try XCTUnwrap(spec["paths"] as? [String: Any], "Missing paths", file: file, line: line)
        let pathItem = try XCTUnwrap(paths[path] as? [String: Any], "Missing path '\(path)'", file: file, line: line)
        return try XCTUnwrap(
            pathItem[method] as? [String: Any],
            "Missing \(method.uppercased()) on path '\(path)'",
            file: file,
            line: line
        )
    }

    private func componentSchema(
        _ name: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws -> [String: Any] {
        let components = try dictionary(in: try loadSpec(), "components", file: file, line: line)
        let schemas = try dictionary(in: components, "schemas", file: file, line: line)
        return try dictionary(in: schemas, name, file: file, line: line)
    }

    private func operationDeclaresResponse(_ operation: [String: Any], status: String) -> Bool {
        guard let responses = operation["responses"] as? [String: Any] else { return false }
        return responses[status] != nil
    }

    private func operationHasPathParameter(_ operation: [String: Any], name: String) -> Bool {
        guard let parameters = operation["parameters"] as? [[String: Any]] else { return false }
        return parameters.contains { ($0["name"] as? String) == name && ($0["in"] as? String) == "path" }
    }

    private func operationRequiresBearerAuth(_ operation: [String: Any]) -> Bool {
        guard let security = operation["security"] as? [[String: Any]] else { return false }
        return security.contains { $0["bearerAuth"] != nil }
    }

    private func requestBodyReferencesSchema(_ operation: [String: Any], fragment: String) -> Bool {
        guard let requestBody = operation["requestBody"] as? [String: Any],
            let content = requestBody["content"] as? [String: Any],
            let json = content["application/json"] as? [String: Any],
            let schema = json["schema"] as? [String: Any]
        else { return false }
        return (schema["$ref"] as? String)?.contains(fragment) ?? false
    }
}
