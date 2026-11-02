import Foundation
import XCTest

/// Guards the vendored OpenAPI document that drives client generation.
///
/// The Phoenix app (`viamin/color_matching`) publishes its machine-readable
/// OpenAPI 3 contract at `GET /api/v1/openapi.json` (viamin/color_matching#110,
/// landed via viamin/color_matching#113). The iOS package vendors a copy at
/// `iOS/Sources/OpenAPIGenerated/openapi.json` and generates a typed client
/// from it with `swift-openapi-generator`.
///
/// These tests pin the surfaces the app uses today so that server-side drift
/// or endpoint gaps surface as test failures (or regeneration diffs) instead
/// of runtime surprises. They run without a live server.
///
/// The expected document shape is specified in
/// `docs/openapi-generated-client-plan.md`, including the vendoring overlay
/// applied on top of the published spec.
final class OpenAPIDocumentCoverageTests: XCTestCase {
    private struct MissingDocumentError: Error {}

    private static var documentURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // iOS/Tests/ColorMatchingLPSAppTests
            .deletingLastPathComponent()  // iOS/Tests
            .deletingLastPathComponent()  // iOS
            .appendingPathComponent("Sources/OpenAPIGenerated/openapi.json")
    }

    private func loadDocument() throws -> [String: Any] {
        let url = Self.documentURL
        guard FileManager.default.fileExists(atPath: url.path) else {
            XCTFail(
                "Vendored OpenAPI document is missing at \(url.path). "
                    + "Fetch GET /api/v1/openapi.json from color_matching (viamin/color_matching#110), "
                    + "apply the vendoring overlay from docs/openapi-generated-client-plan.md, "
                    + "and vendor it there before generating the client."
            )
            throw MissingDocumentError()
        }
        let data = try Data(contentsOf: url)
        let object = try JSONSerialization.jsonObject(with: data)
        return try XCTUnwrap(object as? [String: Any], "Vendored OpenAPI document is not a JSON object")
    }

    private func operation(
        _ document: [String: Any],
        _ path: String,
        _ method: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws -> [String: Any] {
        let paths = try XCTUnwrap(document["paths"] as? [String: Any], file: file, line: line)
        let pathItem = try XCTUnwrap(
            paths[path] as? [String: Any],
            "Path \(path) is not documented in the vendored OpenAPI document",
            file: file,
            line: line
        )
        return try XCTUnwrap(
            pathItem[method] as? [String: Any],
            "\(method.uppercased()) \(path) is not documented in the vendored OpenAPI document",
            file: file,
            line: line
        )
    }

    private func schema(
        _ document: [String: Any],
        _ name: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws -> [String: Any] {
        let components = try XCTUnwrap(document["components"] as? [String: Any], file: file, line: line)
        let schemas = try XCTUnwrap(components["schemas"] as? [String: Any], file: file, line: line)
        return try XCTUnwrap(
            schemas[name] as? [String: Any],
            "Component schema \(name) is missing from the vendored OpenAPI document",
            file: file,
            line: line
        )
    }

    /// Resolves `#/components/schemas/<name>` references; inline schemas pass through.
    private func resolve(_ document: [String: Any], _ schema: [String: Any]) throws -> [String: Any] {
        guard let reference = schema["$ref"] as? String else { return schema }
        let parts = reference.split(separator: "/").map(String.init)
        guard parts.count == 4, parts[0] == "#", parts[1] == "components", parts[2] == "schemas" else {
            XCTFail("Unsupported schema reference \(reference)")
            throw MissingDocumentError()
        }
        return try self.schema(document, parts[3])
    }

    private func properties(_ objectSchema: [String: Any]) -> [String: Any] {
        objectSchema["properties"] as? [String: Any] ?? [:]
    }

    private func requiredFields(_ objectSchema: [String: Any]) -> Set<String> {
        Set(objectSchema["required"] as? [String] ?? [])
    }

    private func stringEnum(_ schema: [String: Any]) -> [String] {
        schema["enum"] as? [String] ?? []
    }

    private func assertProperties(
        _ objectSchema: [String: Any],
        _ fields: [String],
        context: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        for field in fields {
            XCTAssertNotNil(
                properties(objectSchema)[field],
                "\(context) is missing the \(field) property",
                file: file,
                line: line
            )
        }
    }

    // MARK: - Document presence

    func testVendoredDocumentExistsAndDeclaresOpenAPI3() throws {
        let document = try loadDocument()
        let version = try XCTUnwrap(document["openapi"] as? String, "openapi version field is missing")
        XCTAssertTrue(version.hasPrefix("3."), "Expected OpenAPI 3.x, got \(version)")
    }

    // MARK: - Operations used by the app

    func testAppUsedOperationsAreDocumentedWithStableOperationIDs() throws {
        let document = try loadDocument()
        let expected: [(path: String, method: String, operationID: String)] = [
            ("/api/v1/test_sheets/{sheet_id}/manifest", "get", "getTestSheetManifest"),
            ("/api/v1/test_sheets/recent", "get", "listRecentTestSheets"),
            ("/api/v1/test_sheets/{sheet_id}/ranked_results", "get", "getRankedResults"),
            ("/api/v1/test_sheets/{sheet_id}/captures", "post", "createCapture"),
            ("/api/v1/captures/{capture_id}/measurements", "post", "uploadMeasurements"),
            ("/api/v1/captures/{capture_id}/judgments", "post", "uploadJudgments")
        ]

        for expectation in expected {
            let operation = try operation(document, expectation.path, expectation.method)
            XCTAssertEqual(
                operation["operationId"] as? String,
                expectation.operationID,
                "\(expectation.method.uppercased()) \(expectation.path) must keep operationId \(expectation.operationID) "
                    + "so the generated Swift method name stays stable",
                file: #filePath,
                line: #line
            )
        }
    }

    func testPathParametersAreDocumented() throws {
        let document = try loadDocument()
        let expected: [(path: String, method: String, name: String)] = [
            ("/api/v1/test_sheets/{sheet_id}/manifest", "get", "sheet_id"),
            ("/api/v1/test_sheets/{sheet_id}/ranked_results", "get", "sheet_id"),
            ("/api/v1/test_sheets/{sheet_id}/captures", "post", "sheet_id"),
            ("/api/v1/captures/{capture_id}/measurements", "post", "capture_id"),
            ("/api/v1/captures/{capture_id}/judgments", "post", "capture_id")
        ]

        for expectation in expected {
            let operation = try operation(document, expectation.path, expectation.method)
            let parameters = try XCTUnwrap(
                operation["parameters"] as? [[String: Any]],
                "\(expectation.method.uppercased()) \(expectation.path) documents no parameters"
            )
            let parameter = try XCTUnwrap(
                parameters.first { ($0["name"] as? String) == expectation.name },
                "\(expectation.method.uppercased()) \(expectation.path) does not document the \(expectation.name) parameter"
            )
            XCTAssertEqual(parameter["in"] as? String, "path")
            XCTAssertEqual(parameter["required"] as? Bool, true)
        }
    }

    func testBearerAuthSecuritySchemeIsDeclared() throws {
        let document = try loadDocument()
        let components = try XCTUnwrap(document["components"] as? [String: Any])
        let schemes = try XCTUnwrap(components["securitySchemes"] as? [String: Any])
        let bearer = try XCTUnwrap(schemes["bearerAuth"] as? [String: Any])
        XCTAssertEqual(bearer["type"] as? String, "http")
        XCTAssertEqual(bearer["scheme"] as? String, "bearer")
    }

    // MARK: - Manifest schema

    func testManifestSchemaCoversSheetGeometrySurface() throws {
        let document = try loadDocument()
        let manifest = try schema(document, "TestSheetManifest")

        XCTAssertTrue(
            requiredFields(manifest).isSuperset(
                of: [
                    "schema_version", "sheet_id", "sheet_version", "manifest_url", "page",
                    "registration_markers", "printer_profile", "capture_profile", "patches", "pairs"
                ]
            ),
            "TestSheetManifest must require the geometry fields the app consumes"
        )

        XCTAssertTrue(
            stringEnum(properties(manifest)["schema_version"] as? [String: Any] ?? [:])
                .contains("lps-sheet-manifest/v1"),
            "schema_version must keep the lps-sheet-manifest/v1 compatibility enum"
        )

        let captureProfile = try XCTUnwrap(properties(manifest)["capture_profile"] as? [String: Any])
        let scoring = try XCTUnwrap(
            properties(captureProfile)["scoring_algorithm_version"] as? [String: Any]
        )
        XCTAssertTrue(
            stringEnum(scoring).contains("lps-distance-v1"),
            "capture_profile.scoring_algorithm_version must keep the lps-distance-v1 compatibility enum"
        )

        let page = try XCTUnwrap(properties(manifest)["page"] as? [String: Any])
        XCTAssertTrue(requiredFields(page).isSuperset(of: ["units", "width", "height"]))

        let markers = try XCTUnwrap(properties(manifest)["registration_markers"] as? [String: Any])
        let markerItem = try XCTUnwrap(markers["items"] as? [String: Any])
        assertProperties(markerItem, ["role", "shape", "rect"], context: "registration_markers item")

        let patches = try XCTUnwrap(properties(manifest)["patches"] as? [String: Any])
        let patchItem = try XCTUnwrap(patches["items"] as? [String: Any])
        assertProperties(
            patchItem,
            ["id", "role", "pair_id", "pair_side", "reference_role", "source_color", "safe_inset_mm", "rect"],
            context: "patches item"
        )
        XCTAssertTrue(requiredFields(patchItem).isSuperset(of: ["id", "role", "safe_inset_mm", "rect"]))

        let rect = try XCTUnwrap(properties(patchItem)["rect"] as? [String: Any])
        XCTAssertTrue(requiredFields(rect).isSuperset(of: ["x", "y", "width", "height"]))

        let pairs = try XCTUnwrap(properties(manifest)["pairs"] as? [String: Any])
        let pairItem = try XCTUnwrap(pairs["items"] as? [String: Any])
        assertProperties(
            pairItem,
            ["id", "first_patch_id", "second_patch_id", "source_colors", "grid_row", "grid_col"],
            context: "pairs item"
        )
        XCTAssertTrue(
            requiredFields(pairItem)
                .isSuperset(of: ["id", "first_patch_id", "second_patch_id", "source_colors", "grid_row", "grid_col"])
        )

        let printerProfile = try XCTUnwrap(properties(manifest)["printer_profile"] as? [String: Any])
        assertProperties(
            printerProfile,
            ["printer_make_model", "paper_type", "ink_type"],
            context: "printer_profile"
        )
        XCTAssertTrue(
            requiredFields(printerProfile).isSuperset(of: ["printer_make_model", "paper_type", "ink_type"]),
            "printer_profile must document the shape the server actually renders, not the stale prose-contract shape"
        )
    }

    // MARK: - Capture creation

    func testCaptureRequestDocumentsNestedMetadataAndQuality() throws {
        let document = try loadDocument()
        let request = try schema(document, "CaptureRequest")

        XCTAssertTrue(
            requiredFields(request).isSuperset(of: ["metadata", "quality"]),
            "The app posts the nested {metadata, quality} form; the vendored document must require it"
        )

        let metadata = try resolve(document, try XCTUnwrap(properties(request)["metadata"] as? [String: Any]))
        XCTAssertTrue(
            requiredFields(metadata).isSuperset(
                of: ["device_model", "lens", "image_width", "image_height", "app_version", "timestamp"]
            ),
            "CaptureMetadata must document the published spec's required fields"
        )
        assertProperties(
            metadata,
            [
                "device_model", "lens", "exposure_duration_seconds", "iso", "focus_lens_position",
                "white_balance_gains", "image_width", "image_height", "app_version", "timestamp"
            ],
            context: "CaptureMetadata"
        )

        let quality = try XCTUnwrap(properties(request)["quality"] as? [String: Any])
        assertProperties(
            quality,
            ["detected_marker_count", "blur_score", "rejections"],
            context: "CaptureRequest.quality"
        )
    }

    func testCaptureCreationResponseIsTypedJSON() throws {
        let document = try loadDocument()
        let create = try operation(document, "/api/v1/test_sheets/{sheet_id}/captures", "post")
        let responses = try XCTUnwrap(create["responses"] as? [String: Any])
        let created = try XCTUnwrap(responses["201"] as? [String: Any], "createCapture must document the 201 response")
        let createdSchema = try XCTUnwrap(
            (((created["content"] as? [String: Any])?["application/json"] as? [String: Any])?["schema"] as? [String: Any])
        )
        XCTAssertEqual(
            createdSchema["$ref"] as? String,
            "#/components/schemas/CaptureCreatedResponse",
            "201 response must reference the named CaptureCreatedResponse component"
        )
        XCTAssertTrue(requiredFields(try schema(document, "CaptureCreatedResponse")).isSuperset(of: ["capture_id"]))
    }

    // MARK: - Measurement upload

    func testMeasurementUploadSchemaMatchesAppPayload() throws {
        let document = try loadDocument()
        let request = try schema(document, "MeasurementUploadRequest")

        assertProperties(
            request,
            ["scoring_algorithm_version", "measurements", "pair_scores"],
            context: "MeasurementUploadRequest"
        )
        XCTAssertTrue(requiredFields(request).isSuperset(of: ["measurements", "pair_scores"]))

        let measurements = try XCTUnwrap(properties(request)["measurements"] as? [String: Any])
        let measurementItem = try XCTUnwrap(measurements["items"] as? [String: Any])
        assertProperties(
            measurementItem,
            ["patch_id", "linear_rgb_median", "normalized_linear_rgb_median", "stats"],
            context: "measurements item"
        )
        XCTAssertTrue(
            requiredFields(measurementItem).isSuperset(of: ["patch_id", "linear_rgb_median", "normalized_linear_rgb_median", "stats"]),
            "The published spec requires normalized_linear_rgb_median and the app always uploads stats; keep both required"
        )

        let median = try XCTUnwrap(properties(measurementItem)["linear_rgb_median"] as? [String: Any])
        XCTAssertTrue(
            requiredFields(median).isSuperset(of: ["r", "g", "b"]),
            "linear_rgb_median must be the object {r, g, b} shape the app sends"
        )

        let stats = try XCTUnwrap(properties(measurementItem)["stats"] as? [String: Any])
        XCTAssertTrue(
            requiredFields(stats).isSuperset(of: ["sample_count", "clipping_fraction", "mean", "standard_deviation"]),
            "The stats block the app uploads must be documented; the published spec omits it"
        )

        let pairScores = try XCTUnwrap(properties(request)["pair_scores"] as? [String: Any])
        let scoreItem = try XCTUnwrap(pairScores["items"] as? [String: Any])
        assertProperties(
            scoreItem,
            ["pair_id", "distance", "similarity", "algorithm_version"],
            context: "pair_scores item"
        )
        XCTAssertTrue(
            requiredFields(scoreItem).isSuperset(of: ["pair_id", "distance", "similarity", "algorithm_version"]),
            "pair_scores items must document the distance/similarity/algorithm_version shape the app uploads"
        )
    }

    func testMeasurementUploadResponseIsTypedJSONNotNoContent() throws {
        let document = try loadDocument()
        let upload = try operation(document, "/api/v1/captures/{capture_id}/measurements", "post")
        let responses = try XCTUnwrap(upload["responses"] as? [String: Any])
        let ok = try XCTUnwrap(
            responses["200"] as? [String: Any],
            "uploadMeasurements answers 200 with a JSON body on the real server, not the prose contract's 204"
        )
        XCTAssertNil(
            responses["204"],
            "The prose contract assumed 204 No Content; the published API returns 200 with a typed body"
        )
        let okSchema = try XCTUnwrap(
            (((ok["content"] as? [String: Any])?["application/json"] as? [String: Any])?["schema"] as? [String: Any])
        )
        XCTAssertEqual(okSchema["$ref"] as? String, "#/components/schemas/MeasurementUploadResponse")
        XCTAssertTrue(
            requiredFields(try schema(document, "MeasurementUploadResponse"))
                .isSuperset(of: ["capture_id", "measurement_count", "pair_score_count"])
        )
    }

    // MARK: - Judgment upload

    func testJudgmentUploadRequestAndResponseAreTyped() throws {
        let document = try loadDocument()
        let request = try schema(document, "JudgmentUploadRequest")
        let judgments = try XCTUnwrap(properties(request)["judgments"] as? [String: Any])
        let judgmentItem = try XCTUnwrap(judgments["items"] as? [String: Any])
        assertProperties(judgmentItem, ["pair_id", "judgment"], context: "judgments item")
        XCTAssertTrue(requiredFields(request).isSuperset(of: ["judgments"]))

        let upload = try operation(document, "/api/v1/captures/{capture_id}/judgments", "post")
        let responses = try XCTUnwrap(upload["responses"] as? [String: Any])
        let ok = try XCTUnwrap(
            responses["200"] as? [String: Any],
            "uploadJudgments answers 200 with a JSON body on the real server, not the prose contract's 204"
        )
        XCTAssertNil(responses["204"])
        let okSchema = try XCTUnwrap(
            (((ok["content"] as? [String: Any])?["application/json"] as? [String: Any])?["schema"] as? [String: Any])
        )
        XCTAssertEqual(okSchema["$ref"] as? String, "#/components/schemas/JudgmentUploadResponse")
        XCTAssertTrue(
            requiredFields(try schema(document, "JudgmentUploadResponse")).isSuperset(of: ["capture_id", "judgment_count"])
        )
    }

    // MARK: - Recent sheets and ranked results

    func testRecentSheetsSchemaSupportsNullTitle() throws {
        let document = try loadDocument()
        let response = try schema(document, "RecentSheetsResponse")
        let sheets = try XCTUnwrap(properties(response)["sheets"] as? [String: Any])
        let sheetItem = try XCTUnwrap(sheets["items"] as? [String: Any])
        assertProperties(sheetItem, ["sheet_id", "manifest_url", "title"], context: "sheets item")
        XCTAssertTrue(requiredFields(sheetItem).isSuperset(of: ["sheet_id", "manifest_url", "title"]))
        let title = try XCTUnwrap(properties(sheetItem)["title"] as? [String: Any])
        XCTAssertEqual(
            title["nullable"] as? Bool,
            true,
            "title is always present but may be null; it must be marked nullable for the generated client"
        )
    }

    func testRankedResultsSchemaDocumentsResultsArray() throws {
        let document = try loadDocument()
        let rankedResults = try schema(document, "RankedResults")

        XCTAssertTrue(
            stringEnum(properties(rankedResults)["schema_version"] as? [String: Any] ?? [:])
                .contains("lps-ranked-results/v1")
        )
        XCTAssertTrue(requiredFields(rankedResults).isSuperset(of: ["schema_version", "sheet_id"]))

        let results = try XCTUnwrap(
            properties(rankedResults)["results"] as? [String: Any],
            "The published spec only documents schema_version and sheet_id; the app consumes the ranked results array, so the vendored overlay must document it"
        )
        let resultItem = try XCTUnwrap(results["items"] as? [String: Any])
        assertProperties(
            resultItem,
            ["rank", "pair_id", "source_colors", "score", "current_judgment"],
            context: "ranked results item"
        )
        XCTAssertTrue(requiredFields(resultItem).isSuperset(of: ["rank", "pair_id", "source_colors", "score"]))

        let sourceColors = try XCTUnwrap(properties(resultItem)["source_colors"] as? [String: Any])
        XCTAssertTrue(requiredFields(sourceColors).isSuperset(of: ["color_a_hex", "color_b_hex"]))

        let score = try XCTUnwrap(properties(resultItem)["score"] as? [String: Any])
        assertProperties(score, ["average", "latest", "capture_count"], context: "ranked results score")
    }
}
