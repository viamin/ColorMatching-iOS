import Foundation
import XCTest

/// Pins the vendored OpenAPI document that feeds the generated Swift client (#5).
///
/// The app's six API surfaces must be described by a spec vendored at
/// `Sources/ColorMatchingOpenAPI/openapi.json` (the file name and location the
/// OpenAPIGenerator build plugin discovers), derived from the spec published by
/// viamin/color_matching (`GET /api/v1/openapi.json`, issue #110) with the
/// normalizations recorded in `docs/openapi-generated-client-test-plan.md`:
///
/// - friendly `operationId`s (`fetchManifest`, `createCapture`, ...), replacing
///   the upstream `ColorMatchingWeb.TestSheetController.manifest`-style ids;
/// - the manifest schema re-expanded to the full prose contract shape
///   (`docs/color-matching-api-contract.md`), which the published spec omits;
/// - `CaptureRequest`/`PairScoreRequest` anyOf branches flattened back into
///   plain object properties so generated types round-trip every field;
/// - version marker strings (`schema_version`, `scoring_algorithm_version`)
///   kept as plain strings, not enums.
///
/// These tests fail until the spec is vendored: that is the red phase of #5.
final class OpenAPISpecContractTests: XCTestCase {
    private static let manifestPath = "/api/v1/test_sheets/{sheet_id}/manifest"
    private static let recentPath = "/api/v1/test_sheets/recent"
    private static let rankedResultsPath = "/api/v1/test_sheets/{sheet_id}/ranked_results"
    private static let createCapturePath = "/api/v1/test_sheets/{sheet_id}/captures"
    private static let uploadMeasurementsPath = "/api/v1/captures/{capture_id}/measurements"
    private static let uploadJudgmentsPath = "/api/v1/captures/{capture_id}/judgments"

    private static let vendoredSpecPath = "Sources/ColorMatchingOpenAPI/openapi.json"

    // MARK: - Document

    func testVendoredSpecExistsAndParsesAsOpenAPI3() throws {
        let specURL = packageRoot.appendingPathComponent(Self.vendoredSpecPath)
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: specURL.path),
            "Missing \(specURL.path). Vendor the published OpenAPI document (viamin/color_matching#110, served at GET /api/v1/openapi.json) as Sources/ColorMatchingOpenAPI/openapi.json — the file name the OpenAPIGenerator plugin discovers — with the normalizations described in docs/openapi-generated-client-test-plan.md."
        )
        let document = try specDocument()
        let version = try XCTUnwrap(document["openapi"] as? String, "The vendored document must declare its OpenAPI version.")
        XCTAssertTrue(version.hasPrefix("3."), "Expected an OpenAPI 3.x document, got \(version).")
    }

    func testSpecDeclaresBearerAuth() throws {
        let document = try specDocument()
        let schemes = try XCTUnwrap(
            (document["components"] as? [String: Any])?["securitySchemes"] as? [String: Any],
            "The spec must declare its security schemes."
        )
        let bearer = try XCTUnwrap(schemes["bearerAuth"] as? [String: Any], "The spec must declare the bearerAuth scheme used by /api/v1.")
        XCTAssertEqual(bearer["type"] as? String, "http")
        XCTAssertEqual(bearer["scheme"] as? String, "bearer")
    }

    // MARK: - Operations

    func testManifestOperation() throws {
        let operation = try operation(path: Self.manifestPath, method: "get")
        XCTAssertEqual(operation["operationId"] as? String, "fetchManifest")
        XCTAssertNotNil(
            try jsonResponseSchema(of: operation, status: "200", schemaName: "TestSheetManifest"),
            "GET manifest must return TestSheetManifest as application/json on 200."
        )
    }

    func testRecentSheetsOperation() throws {
        let operation = try operation(path: Self.recentPath, method: "get")
        XCTAssertEqual(operation["operationId"] as? String, "fetchRecentSheets")
        XCTAssertNotNil(try jsonResponseSchema(of: operation, status: "200", schemaName: "RecentSheetsResponse"))
    }

    func testRankedResultsOperation() throws {
        let operation = try operation(path: Self.rankedResultsPath, method: "get")
        XCTAssertEqual(operation["operationId"] as? String, "fetchRankedResults")
        XCTAssertNotNil(try jsonResponseSchema(of: operation, status: "200", schemaName: "RankedResults"))
    }

    func testCreateCaptureOperation() throws {
        let operation = try operation(path: Self.createCapturePath, method: "post")
        XCTAssertEqual(operation["operationId"] as? String, "createCapture")
        XCTAssertEqual(
            try requestBodySchemaName(of: operation), "CaptureRequest",
            "POST captures must accept the app's nested {metadata, quality} body."
        )
        XCTAssertNotNil(try jsonResponseSchema(of: operation, status: "201", schemaName: "CaptureCreatedResponse"))
    }

    func testUploadMeasurementsOperation() throws {
        let operation = try operation(path: Self.uploadMeasurementsPath, method: "post")
        XCTAssertEqual(operation["operationId"] as? String, "uploadMeasurements")
        XCTAssertEqual(try requestBodySchemaName(of: operation), "MeasurementUploadRequest")
        XCTAssertNotNil(try jsonResponseSchema(of: operation, status: "200", schemaName: "MeasurementUploadResponse"))
    }

    func testUploadJudgmentsOperation() throws {
        let operation = try operation(path: Self.uploadJudgmentsPath, method: "post")
        XCTAssertEqual(operation["operationId"] as? String, "uploadJudgments")
        XCTAssertEqual(try requestBodySchemaName(of: operation), "JudgmentUploadRequest")
        XCTAssertNotNil(try jsonResponseSchema(of: operation, status: "200", schemaName: "JudgmentUploadResponse"))
    }

    // MARK: - Schemas

    func testManifestSchemaCoversProseContract() throws {
        let schema = try componentSchema("TestSheetManifest")
        let properties = try self.properties(of: schema)

        for name in [
            "schema_version", "sheet_version", "sheet_id", "manifest_url", "created_at",
            "page", "registration_markers", "printer_profile", "capture_profile",
            "patches", "pairs",
        ] {
            XCTAssertNotNil(properties[name], "TestSheetManifest must declare \(name) (prose contract).")
        }
        XCTAssertTrue(try required(of: schema).contains("schema_version"))
        XCTAssertTrue(try required(of: schema).contains("sheet_id"))

        for name in ["schema_version"] {
            let property = try XCTUnwrap(properties[name] as? [String: Any])
            XCTAssertEqual(property["type"] as? String, "string")
            XCTAssertNil(property["enum"], "Keep \(name) a plain string so the generated surface stays String-typed.")
        }

        let captureProfile = try XCTUnwrap(properties["capture_profile"] as? [String: Any])
        let scoring = try XCTUnwrap(try self.properties(of: captureProfile)["scoring_algorithm_version"] as? [String: Any])
        XCTAssertEqual(scoring["type"] as? String, "string")
        XCTAssertNil(scoring["enum"], "Keep scoring_algorithm_version a plain string so the generated surface stays String-typed.")
    }

    func testManifestPatchAndPairSchemasMatchProseFields() throws {
        let schema = try componentSchema("TestSheetManifest")
        let properties = try self.properties(of: schema)

        let patch = try XCTUnwrap(properties["patches"] as? [String: Any])
        let patchItem = try XCTUnwrap(patch["items"] as? [String: Any])
        let patchProperties = try self.properties(of: patchItem)
        for name in ["id", "role", "pair_id", "pair_side", "reference_role", "source_color", "safe_inset_mm", "rect"] {
            XCTAssertNotNil(patchProperties[name], "Manifest patches must declare \(name) (prose contract).")
        }
        let referenceRole = try XCTUnwrap(patchProperties["reference_role"] as? [String: Any])
        XCTAssertTrue(
            referenceRole["nullable"] as? Bool == true,
            "reference_role must be nullable: the app decodes manifests with null reference patches."
        )

        let pair = try XCTUnwrap(properties["pairs"] as? [String: Any])
        let pairItem = try XCTUnwrap(pair["items"] as? [String: Any])
        let pairProperties = try self.properties(of: pairItem)
        for name in ["id", "first_patch_id", "second_patch_id", "source_colors", "grid_row", "grid_col"] {
            XCTAssertNotNil(pairProperties[name], "Manifest pairs must declare \(name) (prose contract).")
        }
    }

    func testRecentSheetsSchemaAllowsNullTitle() throws {
        let schema = try componentSchema("RecentSheetsResponse")
        let sheets = try XCTUnwrap(try properties(of: schema)["sheets"] as? [String: Any])
        let item = try XCTUnwrap(sheets["items"] as? [String: Any])
        let itemProperties = try self.properties(of: item)

        for name in ["sheet_id", "manifest_url", "title"] {
            XCTAssertNotNil(itemProperties[name], "Recent sheet entries must declare \(name).")
        }
        let title = try XCTUnwrap(itemProperties["title"] as? [String: Any])
        XCTAssertTrue(title["nullable"] as? Bool == true, "title must be nullable (prose: title may be null).")
    }

    func testCaptureRequestKeepsNestedMetadataAndQualityShape() throws {
        let schema = try componentSchema("CaptureRequest")
        let properties = try self.properties(of: schema)
        let requiredFields = try self.required(of: schema)

        XCTAssertNil(schema["anyOf"], "CaptureRequest must be a plain object; the upstream anyOf branches drop all fields in generated Swift clients.")
        XCTAssertTrue(requiredFields.contains("metadata"), "metadata must be required (that is the shape the app sends).")
        XCTAssertNotNil(properties["quality"], "CaptureRequest must declare the nested quality object.")

        let metadataRef = try XCTUnwrap(properties["metadata"] as? [String: Any])
        XCTAssertEqual(
            metadataRef["$ref"] as? String, "#/components/schemas/CaptureMetadata",
            "metadata must reference the CaptureMetadata component so generated types share the wire shape."
        )

        let quality = try XCTUnwrap(properties["quality"] as? [String: Any])
        let qualityProperties = try self.properties(of: try resolve(quality))
        for name in ["detected_marker_count", "blur_score", "rejections"] {
            XCTAssertNotNil(qualityProperties[name], "Capture quality must declare \(name).")
        }
    }

    func testCaptureMetadataSchemaMatchesProseFields() throws {
        let schema = try componentSchema("CaptureMetadata")
        let properties = try self.properties(of: schema)
        for name in [
            "device_model", "lens", "exposure_duration_seconds", "iso", "focus_lens_position",
            "white_balance_gains", "image_width", "image_height", "app_version", "timestamp",
        ] {
            XCTAssertNotNil(properties[name], "CaptureMetadata must declare \(name) (prose contract).")
        }
        for name in ["device_model", "lens", "image_width", "image_height", "app_version", "timestamp"] {
            XCTAssertTrue(try required(of: schema).contains(name), "CaptureMetadata must require \(name).")
        }
    }

    func testMeasurementUploadSchemaKeepsStatsScoresAndAlgorithmVersion() throws {
        let schema = try componentSchema("MeasurementUploadRequest")
        let properties = try self.properties(of: schema)

        XCTAssertNotNil(
            properties["scoring_algorithm_version"],
            "Measurements upload must keep the top-level scoring_algorithm_version field the app sends today."
        )

        let measurements = try XCTUnwrap(properties["measurements"] as? [String: Any])
        let measurement = try XCTUnwrap(measurements["items"] as? [String: Any])
        let measurementProperties = try self.properties(of: measurement)
        for name in ["patch_id", "linear_rgb_median", "normalized_linear_rgb_median", "stats"] {
            XCTAssertNotNil(measurementProperties[name], "Measurement entries must declare \(name).")
        }

        let stats = try XCTUnwrap(measurementProperties["stats"] as? [String: Any])
        let statsProperties = try self.properties(of: stats)
        for name in ["sample_count", "clipping_fraction", "mean", "standard_deviation"] {
            XCTAssertNotNil(statsProperties[name], "Measurement stats must declare \(name).")
        }

        let pairScores = try XCTUnwrap(properties["pair_scores"] as? [String: Any])
        let pairScore = try XCTUnwrap(pairScores["items"] as? [String: Any])
        let pairScoreProperties = try self.properties(of: pairScore)
        for name in ["pair_id", "distance", "similarity", "algorithm_version"] {
            XCTAssertNotNil(pairScoreProperties[name], "Pair scores must declare \(name).")
        }
        XCTAssertNil(pairScore["anyOf"], "Pair scores must be plain objects; anyOf score variants drop fields in generated clients.")
    }

    func testMeasurementUploadResponseCountsUploads() throws {
        let schema = try componentSchema("MeasurementUploadResponse")
        let properties = try self.properties(of: schema)
        for name in ["capture_id", "measurement_count", "pair_score_count"] {
            XCTAssertNotNil(properties[name], "MeasurementUploadResponse must declare \(name) (published spec response body).")
        }
    }

    func testJudgmentUploadSchemaKeepsPairIDAndJudgment() throws {
        let schema = try componentSchema("JudgmentUploadRequest")
        let properties = try self.properties(of: schema)
        let judgments = try XCTUnwrap(properties["judgments"] as? [String: Any])
        let judgment = try XCTUnwrap(judgments["items"] as? [String: Any])
        let judgmentProperties = try self.properties(of: judgment)
        for name in ["pair_id", "judgment"] {
            XCTAssertNotNil(judgmentProperties[name], "Judgment entries must declare \(name).")
        }
    }

    func testJudgmentUploadResponseCountsJudgments() throws {
        let schema = try componentSchema("JudgmentUploadResponse")
        let properties = try self.properties(of: schema)
        for name in ["capture_id", "judgment_count"] {
            XCTAssertNotNil(properties[name], "JudgmentUploadResponse must declare \(name) (published spec response body).")
        }
    }

    func testRankedResultsSchemaDeclaresVersionedEnvelope() throws {
        let schema = try componentSchema("RankedResults")
        let properties = try self.properties(of: schema)
        let schemaVersion = try XCTUnwrap(properties["schema_version"] as? [String: Any])
        XCTAssertEqual(schemaVersion["type"] as? String, "string")
        XCTAssertNil(schemaVersion["enum"], "Keep schema_version a plain string so the generated surface stays String-typed.")
        XCTAssertNotNil(properties["sheet_id"], "RankedResults must declare sheet_id.")
    }

    func testCaptureCreatedResponseDeclaresCaptureID() throws {
        let schema = try componentSchema("CaptureCreatedResponse")
        let properties = try self.properties(of: schema)
        XCTAssertNotNil(properties["capture_id"], "CaptureCreatedResponse must declare capture_id.")
    }

    // MARK: - Document access helpers

    private static var cachedDocument: [String: Any]?

    private func specDocument(file: StaticString = #filePath, line: UInt = #line) throws -> [String: Any] {
        if let cached = Self.cachedDocument { return cached }
        let specURL = packageRoot.appendingPathComponent(Self.vendoredSpecPath)
        let data = try Data(contentsOf: specURL)
        let document = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: data) as? [String: Any],
            "The vendored spec must be a JSON object.",
            file: file, line: line
        )
        Self.cachedDocument = document
        return document
    }

    private func operation(path template: String, method: String, file: StaticString = #filePath, line: UInt = #line) throws -> [String: Any] {
        let paths = try XCTUnwrap(try specDocument()["paths"] as? [String: Any], "The spec must declare paths.", file: file, line: line)
        let pathItem = try XCTUnwrap(paths[template] as? [String: Any], "The spec must describe \(template).", file: file, line: line)
        return try XCTUnwrap(pathItem[method] as? [String: Any], "The spec must describe \(method.uppercased()) \(template).", file: file, line: line)
    }

    private func componentSchema(_ name: String, file: StaticString = #filePath, line: UInt = #line) throws -> [String: Any] {
        let components = try XCTUnwrap(try specDocument()["components"] as? [String: Any], file: file, line: line)
        let schemas = try XCTUnwrap(components["schemas"] as? [String: Any], file: file, line: line)
        return try XCTUnwrap(schemas[name] as? [String: Any], "The spec must declare the \(name) component schema.", file: file, line: line)
    }

    private func resolve(_ schema: [String: Any], file: StaticString = #filePath, line: UInt = #line) throws -> [String: Any] {
        guard let reference = schema["$ref"] as? String else { return schema }
        let name = reference.replacingOccurrences(of: "#/components/schemas/", with: "")
        return try componentSchema(name, file: file, line: line)
    }

    private func properties(of schema: [String: Any], file: StaticString = #filePath, line: UInt = #line) throws -> [String: Any] {
        try XCTUnwrap(schema["properties"] as? [String: Any], "Expected an object schema with properties.", file: file, line: line)
    }

    private func required(of schema: [String: Any], file: StaticString = #filePath, line: UInt = #line) throws -> [String] {
        try XCTUnwrap(schema["required"] as? [String], "Expected required to be an array of property names.", file: file, line: line)
    }

    private func requestBodySchemaName(of operation: [String: Any], file: StaticString = #filePath, line: UInt = #line) throws -> String {
        let requestBody = try XCTUnwrap(operation["requestBody"] as? [String: Any], file: file, line: line)
        let content = try XCTUnwrap(requestBody["content"] as? [String: Any], file: file, line: line)
        let json = try XCTUnwrap(content["application/json"] as? [String: Any], file: file, line: line)
        let reference = try XCTUnwrap(json["schema"] as? [String: Any], file: file, line: line)
        let name = try XCTUnwrap(reference["$ref"] as? String, "Request body schema must be a named component reference.", file: file, line: line)
        return name.replacingOccurrences(of: "#/components/schemas/", with: "")
    }

    private func jsonResponseSchema(of operation: [String: Any], status: String, schemaName expected: String, file: StaticString = #filePath, line: UInt = #line) throws -> [String: Any] {
        let responses = try XCTUnwrap(operation["responses"] as? [String: Any], file: file, line: line)
        let response = try XCTUnwrap(responses[status] as? [String: Any], "Operation must declare a \(status) response.", file: file, line: line)
        let content = try XCTUnwrap(response["content"] as? [String: Any], file: file, line: line)
        let json = try XCTUnwrap(content["application/json"] as? [String: Any], "The \(status) response must be application/json.", file: file, line: line)
        let reference = try XCTUnwrap(json["schema"] as? [String: Any], file: file, line: line)
        let name = try XCTUnwrap(reference["$ref"] as? String, "The \(status) response schema must be a named component reference.", file: file, line: line)
            .replacingOccurrences(of: "#/components/schemas/", with: "")
        XCTAssertEqual(name, expected, "The \(status) response must use \(expected).", file: file, line: line)
        return try componentSchema(name, file: file, line: line)
    }

    /// Walks up from this test file to the enclosing Swift package root.
    private var packageRoot: URL {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<6 {
            url.deleteLastPathComponent()
            if FileManager.default.fileExists(atPath: url.appendingPathComponent("Package.swift").path) {
                return url
            }
        }
        fatalError("Could not locate the Swift package root above \(#filePath)")
    }
}
