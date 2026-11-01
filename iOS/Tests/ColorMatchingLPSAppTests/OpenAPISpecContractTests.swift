import Foundation
import XCTest

/// Contract tests for the vendored OpenAPI document that drives the generated
/// Swift client (issue #5).
///
/// The document lives at `iOS/Sources/OpenAPIClient/openapi.json`. It is
/// derived from the spec served by viamin/color_matching at
/// `GET /api/v1/openapi.json` (published in viamin/color_matching#110), then
/// extended where the served spec under-documents payloads the app actually
/// consumes — see `docs/openapi-generated-client-plan.md` for the full delta
/// list and the reference document (`docs/openapi-vendored-reference.json`).
///
/// These tests pin:
///   - the six operations the app uses, with stable `operationId`s (which
///     become the generated Swift method names),
///   - bearer auth on every operation,
///   - request/response schemas named so the generated types are
///     deterministic (`Components.Schemas.*`), and
///   - the required fields the app reads or writes.
///
/// They FAIL until the vendored document exists (expected in the red,
/// tests-first phase of issue #5).
final class OpenAPISpecContractTests: XCTestCase {
    private func loadDocument(file: StaticString = #filePath, line: UInt = #line) throws -> [String: Any] {
        let documentURL = packageRoot().appendingPathComponent("Sources/OpenAPIClient/openapi.json")
        let data: Data
        do {
            data = try Data(contentsOf: documentURL)
        } catch {
            XCTFail(
                "Vendored OpenAPI document is missing at iOS/Sources/OpenAPIClient/openapi.json — vendor it per docs/openapi-generated-client-plan.md: \(error)",
                file: file,
                line: line
            )
            throw error
        }
        return try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any],
            file: file,
            line: line
        )
    }

    // MARK: - Document shape

    func testDocumentIsOpenAPI3WithTheSixAppOperations() throws {
        let document = try loadDocument()

        let version = try XCTUnwrap(document["openapi"] as? String)
        XCTAssertTrue(version.hasPrefix("3."), "Expected an OpenAPI 3 document, got \(version)")

        let cases: [(path: String, method: String, operationID: String)] = [
            ("/api/v1/test_sheets/recent", "get", "listRecentTestSheets"),
            ("/api/v1/test_sheets/{sheet_id}/manifest", "get", "getTestSheetManifest"),
            ("/api/v1/test_sheets/{sheet_id}/ranked_results", "get", "getTestSheetRankedResults"),
            ("/api/v1/test_sheets/{sheet_id}/captures", "post", "createCaptureSession"),
            ("/api/v1/captures/{capture_id}/measurements", "post", "uploadMeasurements"),
            ("/api/v1/captures/{capture_id}/judgments", "post", "uploadJudgments")
        ]

        for testCase in cases {
            let operation = try operation(document, path: testCase.path, method: testCase.method)
            let operationID = try XCTUnwrap(operation["operationId"] as? String)
            XCTAssertEqual(operationID, testCase.operationID, "for \(testCase.method.uppercased()) \(testCase.path)")
        }
    }

    func testOperationsDeclarePathParameters() throws {
        let document = try loadDocument()

        let cases: [(path: String, method: String, parameter: String)] = [
            ("/api/v1/test_sheets/{sheet_id}/manifest", "get", "sheet_id"),
            ("/api/v1/test_sheets/{sheet_id}/ranked_results", "get", "sheet_id"),
            ("/api/v1/test_sheets/{sheet_id}/captures", "post", "sheet_id"),
            ("/api/v1/captures/{capture_id}/measurements", "post", "capture_id"),
            ("/api/v1/captures/{capture_id}/judgments", "post", "capture_id")
        ]

        for testCase in cases {
            let pathItem = try pathItem(document, path: testCase.path)
            let operation = try operation(document, path: testCase.path, method: testCase.method)
            let pathParameters = ((pathItem["parameters"] as? [[String: Any]]) ?? [])
                + ((operation["parameters"] as? [[String: Any]]) ?? [])
            let parameter = pathParameters.first { ($0["name"] as? String) == testCase.parameter }
            XCTAssertNotNil(
                parameter,
                "Expected path parameter \(testCase.parameter) on \(testCase.path)"
            )
            XCTAssertEqual(parameter?["in"] as? String, "path")
            XCTAssertEqual(parameter?["required"] as? Bool, true)
        }
    }

    func testOperationsUseBearerSecurityScheme() throws {
        let document = try loadDocument()

        let components = try XCTUnwrap(document["components"] as? [String: Any])
        let schemes = try XCTUnwrap(components["securitySchemes"] as? [String: Any])
        let bearer = try XCTUnwrap(schemes["bearerAuth"] as? [String: Any])
        XCTAssertEqual(bearer["type"] as? String, "http")
        XCTAssertEqual(bearer["scheme"] as? String, "bearer")

        let secured: [(String, String)] = [
            ("/api/v1/test_sheets/recent", "get"),
            ("/api/v1/test_sheets/{sheet_id}/manifest", "get"),
            ("/api/v1/test_sheets/{sheet_id}/ranked_results", "get"),
            ("/api/v1/test_sheets/{sheet_id}/captures", "post"),
            ("/api/v1/captures/{capture_id}/measurements", "post"),
            ("/api/v1/captures/{capture_id}/judgments", "post")
        ]
        for (path, method) in secured {
            let operation = try operation(document, path: path, method: method)
            let security = try XCTUnwrap(
                operation["security"] as? [[String: Any]],
                "\(method.uppercased()) \(path) must declare security"
            )
            XCTAssertTrue(
                security.contains { $0["bearerAuth"] != nil },
                "\(method.uppercased()) \(path) must require bearerAuth"
            )
        }
    }

    // MARK: - Manifest

    func testManifestSchemaCoversRenderedManifestPayload() throws {
        let document = try loadDocument()
        let operation = try operation(document, path: "/api/v1/test_sheets/{sheet_id}/manifest", method: "get")
        let manifest = try referencedSchema(
            try responseSchema(operation, status: "200"),
            document: document,
            expectedName: "TestSheetManifest"
        )

        assertRequired(manifest, contains: [
            "schema_version", "sheet_version", "sheet_id", "manifest_url", "created_at",
            "page", "registration_markers", "printer_profile", "capture_profile", "patches", "pairs"
        ])
        assertEnumValues(try property(manifest, "schema_version"), ["lps-sheet-manifest/v1"])

        let page = try referencedProperty(manifest, "page", document: document, expectedName: "Page")
        assertRequired(page, contains: ["units", "width", "height"])

        let markers = try referencedItems(
            try property(manifest, "registration_markers"),
            document: document,
            expectedName: "RegistrationMarker"
        )
        assertRequired(markers, contains: ["role", "shape", "rect"])
        let rect = try referencedProperty(markers, "rect", document: document, expectedName: "Rect")
        assertRequired(rect, contains: ["x", "y", "width", "height"])

        // The Phoenix app renders printer_make_model/paper_type/ink_type — the
        // prose contract's {id, name, paper, ink, settings} never existed.
        let printerProfile = try referencedProperty(
            manifest, "printer_profile", document: document, expectedName: "PrinterProfile"
        )
        assertRequired(printerProfile, contains: ["printer_make_model", "paper_type", "ink_type"])

        let captureProfile = try referencedProperty(
            manifest, "capture_profile", document: document, expectedName: "CaptureProfile"
        )
        assertRequired(captureProfile, contains: [
            "expected_illuminant", "preferred_camera", "scoring_algorithm_version"
        ])
        assertEnumValues(try property(captureProfile, "scoring_algorithm_version"), ["lps-distance-v1"])

        let patches = try referencedItems(
            try property(manifest, "patches"), document: document, expectedName: "Patch"
        )
        assertRequired(patches, contains: [
            "id", "role", "pair_id", "pair_side", "reference_role", "source_color", "safe_inset_mm", "rect"
        ])
        assertAllowsNull(try property(patches, "reference_role"))

        let pairs = try referencedItems(
            try property(manifest, "pairs"), document: document, expectedName: "PairManifest"
        )
        assertRequired(pairs, contains: [
            "id", "first_patch_id", "second_patch_id", "source_colors", "grid_row", "grid_col"
        ])
    }

    // MARK: - Recent sheets

    func testRecentSheetsSchemaCoversDiscoveryPayload() throws {
        let document = try loadDocument()
        let operation = try operation(document, path: "/api/v1/test_sheets/recent", method: "get")
        let response = try referencedSchema(
            try responseSchema(operation, status: "200"),
            document: document,
            expectedName: "RecentSheetsResponse"
        )

        assertRequired(response, contains: ["sheets"])
        let sheet = try referencedItems(
            try property(response, "sheets"), document: document, expectedName: "RecentSheet"
        )
        assertRequired(sheet, contains: ["sheet_id", "manifest_url", "title"])
        // The Phoenix app currently always renders title: null.
        assertAllowsNull(try property(sheet, "title"))
    }

    // MARK: - Capture session creation

    func testCaptureCreationSchemasMatchAppPayload() throws {
        let document = try loadDocument()
        let operation = try operation(document, path: "/api/v1/test_sheets/{sheet_id}/captures", method: "post")

        let request = try referencedSchema(
            try requestBodySchema(operation), document: document, expectedName: "CaptureRequest"
        )
        assertRequired(request, contains: ["metadata", "quality"])

        let metadata = try referencedProperty(
            request, "metadata", document: document, expectedName: "CaptureMetadata"
        )
        assertRequired(metadata, contains: [
            "device_model", "lens", "image_width", "image_height", "app_version", "timestamp"
        ])
        for optionalProperty in [
            "exposure_duration_seconds", "iso", "focus_lens_position", "white_balance_gains"
        ] {
            XCTAssertNotNil(
                (metadata["properties"] as? [String: Any])?[optionalProperty],
                "CaptureMetadata should declare optional \(optionalProperty)"
            )
        }
        let gains = try referencedProperty(
            metadata, "white_balance_gains", document: document, expectedName: "WhiteBalanceGains"
        )
        assertRequired(gains, contains: ["red", "green", "blue"])

        let quality = try referencedProperty(
            request, "quality", document: document, expectedName: "CaptureQuality"
        )
        assertRequired(quality, contains: ["detected_marker_count", "blur_score", "rejections"])
        assertEnumValues(try items(try property(quality, "rejections")), [
            "missingRegistrationMarks", "incompleteSheetCoverage", "clipping",
            "excessiveBlur", "glare", "poorReferencePatch"
        ])

        let created = try referencedSchema(
            try responseSchema(operation, status: "201"),
            document: document,
            expectedName: "CaptureCreatedResponse"
        )
        assertRequired(created, contains: ["capture_id"])
    }

    // MARK: - Measurement upload

    func testMeasurementUploadSchemasMatchAppPayload() throws {
        let document = try loadDocument()
        let operation = try operation(
            document, path: "/api/v1/captures/{capture_id}/measurements", method: "post"
        )

        let request = try referencedSchema(
            try requestBodySchema(operation), document: document, expectedName: "MeasurementUploadRequest"
        )
        assertRequired(request, contains: ["scoring_algorithm_version", "measurements", "pair_scores"])

        let measurement = try referencedItems(
            try property(request, "measurements"),
            document: document,
            expectedName: "PatchMeasurementUpload"
        )
        assertRequired(measurement, contains: [
            "patch_id", "linear_rgb_median", "normalized_linear_rgb_median", "stats"
        ])
        let rgb = try referencedProperty(
            measurement, "linear_rgb_median", document: document, expectedName: "Rgb"
        )
        assertRequired(rgb, contains: ["r", "g", "b"])

        let stats = try referencedProperty(
            measurement, "stats", document: document, expectedName: "MeasurementStats"
        )
        assertRequired(stats, contains: ["sample_count", "clipping_fraction", "mean", "standard_deviation"])

        let score = try referencedItems(
            try property(request, "pair_scores"), document: document, expectedName: "PairScoreUpload"
        )
        assertRequired(score, contains: ["pair_id", "algorithm_version", "distance", "similarity"])

        let accepted = try referencedSchema(
            try responseSchema(operation, status: "200"),
            document: document,
            expectedName: "MeasurementUploadResponse"
        )
        assertRequired(accepted, contains: ["capture_id", "measurement_count", "pair_score_count"])
    }

    // MARK: - Judgment upload

    func testJudgmentUploadSchemasMatchAppPayload() throws {
        let document = try loadDocument()
        let operation = try operation(
            document, path: "/api/v1/captures/{capture_id}/judgments", method: "post"
        )

        let request = try referencedSchema(
            try requestBodySchema(operation), document: document, expectedName: "JudgmentUploadRequest"
        )
        assertRequired(request, contains: ["judgments"])
        let judgment = try referencedItems(
            try property(request, "judgments"), document: document, expectedName: "PairJudgmentPayload"
        )
        assertRequired(judgment, contains: ["pair_id", "judgment"])

        let accepted = try referencedSchema(
            try responseSchema(operation, status: "200"),
            document: document,
            expectedName: "JudgmentUploadResponse"
        )
        assertRequired(accepted, contains: ["capture_id", "judgment_count"])
    }

    // MARK: - Ranked results

    func testRankedResultsSchemaCoversRenderedPayload() throws {
        let document = try loadDocument()
        let operation = try operation(
            document, path: "/api/v1/test_sheets/{sheet_id}/ranked_results", method: "get"
        )
        let ranked = try referencedSchema(
            try responseSchema(operation, status: "200"),
            document: document,
            expectedName: "RankedResults"
        )

        assertRequired(ranked, contains: [
            "schema_version", "sheet_id", "capture_count", "scoring_algorithm_versions", "results",
            "printer_profile"
        ])
        assertEnumValues(try property(ranked, "schema_version"), ["lps-ranked-results/v1"])

        let result = try referencedItems(
            try property(ranked, "results"), document: document, expectedName: "RankedPairResult"
        )
        assertRequired(result, contains: [
            "rank", "pair_id", "scoring_algorithm_version", "row", "col", "source_colors",
            "score", "current_judgment", "observation_count", "capture_count"
        ])
        assertAllowsNull(try property(result, "current_judgment"))

        let sourceColors = try referencedProperty(
            result, "source_colors", document: document, expectedName: "RankedSourceColors"
        )
        assertRequired(sourceColors, contains: ["color_a_hex", "color_b_hex"])

        let score = try referencedProperty(
            result, "score", document: document, expectedName: "RankedScore"
        )
        assertRequired(score, contains: [
            "average", "latest", "minimum", "maximum", "capture_count", "sample_count", "algorithm_versions"
        ])
    }

    // MARK: - JSON navigation helpers

    private func pathItem(
        _ document: [String: Any],
        path: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws -> [String: Any] {
        let paths = try XCTUnwrap(document["paths"] as? [String: Any], file: file, line: line)
        return try XCTUnwrap(
            paths[path] as? [String: Any],
            "Vendored spec is missing the path \(path)",
            file: file,
            line: line
        )
    }

    private func operation(
        _ document: [String: Any],
        path: String,
        method: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws -> [String: Any] {
        let item = try pathItem(document, path: path, file: file, line: line)
        return try XCTUnwrap(
            item[method] as? [String: Any],
            "Vendored spec is missing \(method.uppercased()) \(path)",
            file: file,
            line: line
        )
    }

    private func responseSchema(
        _ operation: [String: Any],
        status: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws -> [String: Any] {
        let responses = try XCTUnwrap(operation["responses"] as? [String: Any], file: file, line: line)
        let response = try XCTUnwrap(
            responses[status] as? [String: Any],
            "Operation is missing a \(status) response",
            file: file,
            line: line
        )
        let content = try XCTUnwrap(response["content"] as? [String: Any], file: file, line: line)
        let json = try XCTUnwrap(
            content["application/json"] as? [String: Any],
            "\(status) response must declare application/json content",
            file: file,
            line: line
        )
        return try XCTUnwrap(json["schema"] as? [String: Any], file: file, line: line)
    }

    private func requestBodySchema(
        _ operation: [String: Any],
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws -> [String: Any] {
        let body = try XCTUnwrap(operation["requestBody"] as? [String: Any], file: file, line: line)
        let content = try XCTUnwrap(body["content"] as? [String: Any], file: file, line: line)
        let json = try XCTUnwrap(
            content["application/json"] as? [String: Any],
            "Request body must declare application/json content",
            file: file,
            line: line
        )
        return try XCTUnwrap(json["schema"] as? [String: Any], file: file, line: line)
    }

    private func referencedSchema(
        _ schema: [String: Any],
        document: [String: Any],
        expectedName: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws -> [String: Any] {
        let name = try XCTUnwrap(
            schema["$ref"] as? String,
            "Expected a $ref to #/components/schemas/\(expectedName), got keys \(schema.keys.sorted())",
            file: file,
            line: line
        )
        XCTAssertTrue(
            name.hasSuffix("/\(expectedName)"),
            "Expected $ref to \(expectedName), got \(name)",
            file: file,
            line: line
        )
        return try resolveReference(name, document: document, file: file, line: line)
    }

    private func resolveReference(
        _ reference: String,
        document: [String: Any],
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws -> [String: Any] {
        XCTAssertTrue(reference.hasPrefix("#/"), "Only local $refs are supported, got \(reference)")
        let segments = reference.dropFirst(2).split(separator: "/").map(String.init)
        var node: Any = document
        for segment in segments {
            let dictionary = try XCTUnwrap(
                node as? [String: Any],
                "Cannot descend into \(reference) at \(segment)",
                file: file,
                line: line
            )
            node = try XCTUnwrap(
                dictionary[segment],
                "Reference \(reference) is missing segment \(segment)",
                file: file,
                line: line
            )
        }
        return try XCTUnwrap(node as? [String: Any], file: file, line: line)
    }

    private func property(
        _ schema: [String: Any],
        _ name: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws -> [String: Any] {
        let properties = try XCTUnwrap(schema["properties"] as? [String: Any], file: file, line: line)
        return try XCTUnwrap(
            properties[name] as? [String: Any],
            "Schema is missing property \(name) (properties: \(properties.keys.sorted()))",
            file: file,
            line: line
        )
    }

    private func referencedProperty(
        _ schema: [String: Any],
        _ name: String,
        document: [String: Any],
        expectedName: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws -> [String: Any] {
        let property = try property(schema, name, file: file, line: line)
        guard (property["$ref"] as? String) != nil else {
            return property
        }
        return try referencedSchema(property, document: document, expectedName: expectedName, file: file, line: line)
    }

    private func items(
        _ schema: [String: Any],
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws -> [String: Any] {
        try XCTUnwrap(schema["items"] as? [String: Any], file: file, line: line)
    }

    private func referencedItems(
        _ schema: [String: Any],
        document: [String: Any],
        expectedName: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws -> [String: Any] {
        try referencedSchema(
            try items(schema, file: file, line: line),
            document: document,
            expectedName: expectedName,
            file: file,
            line: line
        )
    }

    // MARK: - Assertion helpers

    private func assertRequired(
        _ schema: [String: Any],
        contains names: [String],
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let required = (schema["required"] as? [String]) ?? []
        for name in names {
            XCTAssertTrue(
                required.contains(name),
                "Expected \(name) in required (required: \(required))",
                file: file,
                line: line
            )
        }
    }

    private func assertEnumValues(
        _ schema: [String: Any],
        _ values: [String],
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(
            (schema["enum"] as? [String]) ?? [],
            values,
            file: file,
            line: line
        )
    }

    private func assertAllowsNull(
        _ schema: [String: Any],
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(
            allowsNull(schema),
            "Expected schema to allow null (nullable: true or type: [\"string\", \"null\"])",
            file: file,
            line: line
        )
    }

    private func allowsNull(_ schema: [String: Any]) -> Bool {
        if schema["nullable"] as? Bool == true {
            return true
        }
        if let types = schema["type"] as? [Any] {
            return types.contains { ($0 as? String) == "null" }
        }
        return false
    }

    private func packageRoot() -> URL {
        var directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        for _ in 0..<8 {
            if FileManager.default.fileExists(atPath: directory.appendingPathComponent("Package.swift").path) {
                return directory
            }
            directory.deleteLastPathComponent()
        }
        return directory
    }
}
