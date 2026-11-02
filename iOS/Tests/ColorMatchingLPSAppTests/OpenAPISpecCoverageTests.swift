//
//  OpenAPISpecCoverageTests.swift
//
//  Red-phase tests for the vendored OpenAPI document required by
//  "Replace hand-written API layer with a generated OpenAPI Swift client" (#5).
//
//  These tests read `iOS/OpenAPI/color-matching-v1.json` from the checkout and
//  assert that it covers the surfaces the app uses today, with the pinned
//  operation IDs and schema shapes documented in `docs/openapi-client-generation.md`.
//  They fail until the implementation run vendors the document.
//

import Foundation
import XCTest

final class OpenAPISpecCoverageTests: XCTestCase {
    private var spec: [String: Any]!

    override func setUpWithError() throws {
        try super.setUpWithError()
        let specURL = try XCTUnwrap(
            Self.vendoredSpecURL(),
            "Vendored OpenAPI document is missing: expected iOS/OpenAPI/color-matching-v1.json. " +
                "Vendor the published spec from viamin/color_matching per docs/openapi-client-generation.md."
        )
        let data = try Data(contentsOf: specURL)
        spec = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    // MARK: Document

    func testDocumentIsOpenAPI3() throws {
        let version = try XCTUnwrap(spec["openapi"] as? String)
        XCTAssertTrue(version.hasPrefix("3."), "expected OpenAPI 3.x, got \(version)")
    }

    func testBearerSecuritySchemeMatchesProseContract() throws {
        let components = try XCTUnwrap(spec["components"] as? [String: Any])
        let schemes = try XCTUnwrap(components["securitySchemes"] as? [String: Any])
        let bearer = try XCTUnwrap(
            schemes["bearerAuth"] as? [String: Any],
            "expected the served bearerAuth security scheme"
        )
        XCTAssertEqual(bearer["type"] as? String, "http")
        XCTAssertEqual(bearer["scheme"] as? String, "bearer")
    }

    // MARK: Operations

    func testAppFacingOperationsExistWithPinnedOperationIDs() throws {
        let paths = try XCTUnwrap(spec["paths"] as? [String: Any])
        let expected: [(path: String, method: String, operationID: String)] = [
            ("/api/v1/test_sheets/recent", "get", "listRecentTestSheets"),
            ("/api/v1/test_sheets/{sheet_id}/manifest", "get", "getTestSheetManifest"),
            ("/api/v1/test_sheets/{sheet_id}/ranked_results", "get", "getRankedResults"),
            ("/api/v1/test_sheets/{sheet_id}/captures", "post", "createCapture"),
            ("/api/v1/captures/{capture_id}/measurements", "post", "uploadMeasurements"),
            ("/api/v1/captures/{capture_id}/judgments", "post", "uploadJudgments")
        ]

        for expectation in expected {
            let operation = try operation(paths, expectation.path, expectation.method)
            XCTAssertEqual(
                operation["operationId"] as? String,
                expectation.operationID,
                "\(expectation.method.uppercased()) \(expectation.path) must carry the pinned operation ID " +
                    "(docs/openapi-client-generation.md renames OpenApiSpex defaults like " +
                    "'ColorMatchingWeb.TestSheetController.manifest')"
            )
        }
    }

    func testOperationsDeclareBearerSecurity() throws {
        let paths = try XCTUnwrap(spec["paths"] as? [String: Any])
        let manifest = try operation(paths, "/api/v1/test_sheets/{sheet_id}/manifest", "get")
        let security = try XCTUnwrap(manifest["security"] as? [[String: Any]])
        XCTAssertTrue(
            security.contains { $0["bearerAuth"] != nil },
            "the manifest operation must declare bearerAuth security"
        )
    }

    // MARK: Manifest schema

    func testManifestSchemaDocumentsFieldsTheAppConsumes() throws {
        let manifest = try schema("TestSheetManifest")

        let required = Set(try stringArray(manifest, "required"))
        for field in [
            "schema_version", "sheet_id", "sheet_version", "manifest_url", "page",
            "registration_markers", "patches", "pairs", "capture_profile"
        ] {
            XCTAssertTrue(
                required.contains(field),
                "TestSheetManifest must require '\(field)'. The served spec under-documents the manifest " +
                    "(only schema_version/sheet_id/capture_profile); the vendored copy documents the fields " +
                    "the server emits — see docs/color-matching-api-contract-deltas.md delta 1."
            )
        }

        let properties = try object(manifest, "properties")
        XCTAssertNotNil(properties["page"] as? [String: Any])
        XCTAssertNotNil(properties["registration_markers"] as? [String: Any])
        XCTAssertNotNil(properties["patches"] as? [String: Any])
        XCTAssertNotNil(properties["pairs"] as? [String: Any])
        XCTAssertEqual(
            try reference(properties, "page"), "#/components/schemas/SheetPage",
            "structured manifest fields should be named components, not inline objects"
        )
        XCTAssertEqual(try reference(properties, "capture_profile"), "#/components/schemas/CaptureProfile")

        let enumValues = try stringArray(
            try object(try object(manifest, "properties"), "schema_version"),
            "enum"
        )
        XCTAssertEqual(enumValues, ["lps-sheet-manifest/v1"])
    }

    func testManifestComponentSchemasCoverPageMarkersPatchesAndPairs() throws {
        let page = try schema("SheetPage")
        XCTAssertEqual(Set(try stringArray(page, "required")), ["units", "width", "height"])

        let rect = try schema("SheetRect")
        XCTAssertEqual(Set(try stringArray(rect, "required")), ["x", "y", "width", "height"])

        let marker = try schema("RegistrationMarker")
        XCTAssertEqual(Set(try stringArray(marker, "required")), ["role", "shape", "rect"])
        XCTAssertEqual(
            try reference(try object(marker, "properties"), "rect"),
            "#/components/schemas/SheetRect"
        )

        let patch = try schema("ManifestPatch")
        let patchRequired = Set(try stringArray(patch, "required"))
        for field in ["id", "role", "safe_inset_mm", "rect"] {
            XCTAssertTrue(patchRequired.contains(field), "ManifestPatch must require '\(field)'")
        }
        for field in ["pair_id", "pair_side", "reference_role", "source_color"] {
            XCTAssertNotNil(
                try object(patch, "properties")[field],
                "ManifestPatch must document optional '\(field)'"
            )
        }

        let pair = try schema("PairManifest")
        XCTAssertEqual(
            Set(try stringArray(pair, "required")),
            ["id", "first_patch_id", "second_patch_id", "source_colors", "grid_row", "grid_col"]
        )

        let captureProfile = try schema("CaptureProfile")
        let scoring = try object(
            try object(captureProfile, "properties"), "scoring_algorithm_version"
        )
        XCTAssertEqual(Set(try stringArray(captureProfile, "required")), [
            "expected_illuminant", "preferred_camera", "scoring_algorithm_version"
        ])
        XCTAssertEqual(try stringArray(scoring, "enum"), ["lps-distance-v1"])
    }

    // MARK: Recent sheets

    func testRecentSheetsSchemaMatchesProseContract() throws {
        let response = try schema("RecentSheetsResponse")
        XCTAssertEqual(try stringArray(response, "required"), ["sheets"])
        let sheets = try object(try object(response, "properties"), "sheets")
        XCTAssertEqual(try reference(sheets, "items"), "#/components/schemas/RecentSheet")

        let recent = try schema("RecentSheet")
        XCTAssertEqual(Set(try stringArray(recent, "required")), ["sheet_id", "manifest_url", "title"])
        let title = try object(try object(recent, "properties"), "title")
        XCTAssertEqual(title["nullable"] as? Bool, true, "title may be null per the prose contract")
    }

    // MARK: Capture creation

    func testCaptureRequestIsGeneratorConsumableNestedForm() throws {
        let request = try schema("CaptureRequest")

        XCTAssertNil(
            request["anyOf"],
            "CaptureRequest must not mix sibling properties with a top-level anyOf: OpenAPIKit drops " +
                "sibling properties, so swift-openapi-generator would emit empty wrapper structs. " +
                "Normalize to the nested metadata+quality form (deltas doc, gap a)."
        )

        let properties = try object(request, "properties")
        XCTAssertEqual(
            try reference(properties, "metadata"), "#/components/schemas/CaptureMetadata",
            "the app sends the nested metadata form; it must be a named, ref-able component"
        )
        XCTAssertEqual(
            try reference(properties, "quality"), "#/components/schemas/CaptureQuality"
        )

        let metadata = try schema("CaptureMetadata")
        XCTAssertEqual(Set(try stringArray(metadata, "required")), [
            "device_model", "lens", "image_width", "image_height", "app_version", "timestamp"
        ])
        XCTAssertEqual(
            try reference(try object(metadata, "properties"), "white_balance_gains"),
            "#/components/schemas/WhiteBalanceGains"
        )

        let quality = try schema("CaptureQuality")
        XCTAssertEqual(
            Set(try stringArray(quality, "required")),
            ["detected_marker_count", "blur_score", "rejections"]
        )
    }

    func testCreateCaptureResponds201WithCaptureID() throws {
        let paths = try XCTUnwrap(spec["paths"] as? [String: Any])
        let create = try operation(paths, "/api/v1/test_sheets/{sheet_id}/captures", "post")
        let requestSchema = try XCTUnwrap(
            try reference(try object(create, "requestBody"), viaContentJSON: "schema")
        )
        XCTAssertEqual(requestSchema, "#/components/schemas/CaptureRequest")

        let responses = try object(create, "responses")
        let createdResponse = try response(responses, status: "201")
        XCTAssertEqual(
            try reference(createdResponse, viaContentJSON: "schema"),
            "#/components/schemas/CaptureCreatedResponse",
            "capture creation responds 201 (delta: the app already assumed 201)"
        )
        let created = try schema("CaptureCreatedResponse")
        XCTAssertEqual(try stringArray(created, "required"), ["capture_id"])
    }

    // MARK: Measurement upload

    func testMeasurementUploadSchemaCoversAppPayloadAndDocumentedStats() throws {
        let request = try schema("MeasurementUploadRequest")
        let properties = try object(request, "properties")
        let measurements = try object(properties, "measurements")
        XCTAssertEqual(
            try reference(measurements, "items"), "#/components/schemas/MeasurementUploadItem"
        )
        let pairScores = try object(properties, "pair_scores")
        XCTAssertEqual(try reference(pairScores, "items"), "#/components/schemas/PairScoreUpload")

        let item = try schema("MeasurementUploadItem")
        XCTAssertEqual(Set(try stringArray(item, "required")), [
            "patch_id", "linear_rgb_median", "normalized_linear_rgb_median"
        ], "the published spec requires the normalized median in every item (deltas doc, delta 6)")
        XCTAssertEqual(
            try reference(try object(item, "properties"), "linear_rgb_median"),
            "#/components/schemas/RgbPayload"
        )
        XCTAssertEqual(
            try reference(try object(item, "properties"), "stats"),
            "#/components/schemas/MeasurementStats",
            "the app uploads robustness stats today; the vendored copy documents them (delta 7)"
        )

        let stats = try schema("MeasurementStats")
        XCTAssertEqual(Set(try stringArray(stats, "required")), [
            "sample_count", "clipping_fraction", "mean", "standard_deviation"
        ])

        let score = try schema("PairScoreUpload")
        XCTAssertNil(
            score["anyOf"],
            "PairScoreUpload must be a plain object (sibling anyOf is not generator-consumable; gap a)"
        )
        XCTAssertEqual(Set(try stringArray(score, "required")), ["pair_id", "algorithm_version"])
        let scoreProperties = try object(score, "properties")
        for field in ["score", "similarity", "distance"] {
            XCTAssertNotNil(scoreProperties[field], "PairScoreUpload must document '\(field)'")
        }

        let rgb = try schema("RgbPayload")
        XCTAssertEqual((try anyArray(rgb, "anyOf")).count, 3, "RgbPayload keeps the served 3-variant anyOf")
    }

    func testMeasurementUploadResponds200WithCounts() throws {
        let paths = try XCTUnwrap(spec["paths"] as? [String: Any])
        let upload = try operation(paths, "/api/v1/captures/{capture_id}/measurements", "post")
        let responses = try object(upload, "responses")
        let ok = try response(responses, status: "200")
        XCTAssertEqual(
            try reference(ok, viaContentJSON: "schema"),
            "#/components/schemas/MeasurementUploadResponse",
            "measurement upload responds 200 with a JSON body, not 204 (deltas doc, delta 5)"
        )
        let response = try schema("MeasurementUploadResponse")
        XCTAssertEqual(Set(try stringArray(response, "required")), [
            "capture_id", "measurement_count", "pair_score_count"
        ])
    }

    // MARK: Judgment upload

    func testJudgmentUploadSchemaAndResponse() throws {
        let request = try schema("JudgmentUploadRequest")
        XCTAssertEqual(try stringArray(request, "required"), ["judgments"])
        let judgments = try object(try object(request, "properties"), "judgments")
        XCTAssertEqual(try reference(judgments, "items"), "#/components/schemas/JudgmentUploadItem")

        let item = try schema("JudgmentUploadItem")
        XCTAssertEqual(Set(try stringArray(item, "required")), ["pair_id", "judgment"])

        let paths = try XCTUnwrap(spec["paths"] as? [String: Any])
        let upload = try operation(paths, "/api/v1/captures/{capture_id}/judgments", "post")
        let responses = try object(upload, "responses")
        let ok = try response(responses, status: "200")
        XCTAssertEqual(
            try reference(ok, viaContentJSON: "schema"),
            "#/components/schemas/JudgmentUploadResponse",
            "judgment upload responds 200 with a JSON body, not 204 (deltas doc, delta 5)"
        )
        let response = try schema("JudgmentUploadResponse")
        XCTAssertEqual(Set(try stringArray(response, "required")), ["capture_id", "judgment_count"])
    }

    // MARK: Ranked results

    func testRankedResultsOperationAndGuaranteedFields() throws {
        let paths = try XCTUnwrap(spec["paths"] as? [String: Any])
        let ranked = try operation(paths, "/api/v1/test_sheets/{sheet_id}/ranked_results", "get")
        let responses = try object(ranked, "responses")
        let ok = try response(responses, status: "200")
        XCTAssertEqual(
            try reference(ok, viaContentJSON: "schema"),
            "#/components/schemas/RankedResults"
        )

        let results = try schema("RankedResults")
        XCTAssertEqual(Set(try stringArray(results, "required")), ["schema_version", "sheet_id"])
        let enumValues = try stringArray(
            try object(try object(results, "properties"), "schema_version"), "enum"
        )
        XCTAssertEqual(enumValues, ["lps-ranked-results/v1"])
    }
}

// MARK: - Helpers

private extension OpenAPISpecCoverageTests {
    static func vendoredSpecURL() -> URL? {
        let testFile = URL(fileURLWithPath: #filePath)
        let packageRoot = testFile
            .deletingLastPathComponent()  // ColorMatchingLPSAppTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // iOS
        let url = packageRoot
            .appendingPathComponent("OpenAPI")
            .appendingPathComponent("color-matching-v1.json")
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    func operation(_ paths: [String: Any], _ path: String, _ method: String) throws -> [String: Any] {
        let pathItem = try XCTUnwrap(
            paths[path] as? [String: Any],
            "vendored spec is missing path \(path)"
        )
        return try XCTUnwrap(
            pathItem[method] as? [String: Any],
            "vendored spec is missing \(method.uppercased()) \(path)"
        )
    }

    func schema(_ name: String) throws -> [String: Any] {
        let components = try XCTUnwrap(spec["components"] as? [String: Any])
        let schemas = try XCTUnwrap(components["schemas"] as? [String: Any])
        return try XCTUnwrap(
            schemas[name] as? [String: Any],
            "vendored spec is missing components.schemas.\(name)"
        )
    }

    func object(_ container: [String: Any], _ key: String) throws -> [String: Any] {
        try XCTUnwrap(container[key] as? [String: Any], "expected object at '\(key)'")
    }

    func anyArray(_ container: [String: Any], _ key: String) throws -> [Any] {
        try XCTUnwrap(container[key] as? [Any], "expected array at '\(key)'")
    }

    func stringArray(_ container: [String: Any], _ key: String) throws -> [String] {
        try anyArray(container, key).map { element in
            try XCTUnwrap(element as? String, "expected only strings at '\(key)'")
        }
    }

    func reference(_ container: [String: Any], _ key: String) throws -> String {
        let target = try object(container, key)
        return try XCTUnwrap(target["$ref"] as? String, "expected $ref at '\(key)'")
    }

    func response(_ responses: [String: Any], status: String) throws -> [String: Any] {
        try XCTUnwrap(responses[status] as? [String: Any], "expected a '\(status)' response")
    }

    func reference(_ container: [String: Any], viaContentJSON key: String) throws -> String {
        let content = try object(container, "content")
        let json = try object(content, "application/json")
        let schema = try object(json, "schema")
        return try XCTUnwrap(schema["$ref"] as? String, "expected content.application/json.schema.$ref")
    }
}
