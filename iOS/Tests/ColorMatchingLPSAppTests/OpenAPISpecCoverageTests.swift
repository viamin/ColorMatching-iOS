import Foundation
import XCTest

/// Contract tests for the vendored OpenAPI document that backs the generated
/// API client (issue #5).
///
/// The document must live at `iOS/OpenAPI/color-matching-openapi.json` and is
/// produced by the vendoring pipeline described in
/// `docs/openapi-generated-client.md`: a copy of `GET /api/v1/openapi.json`
/// published by viamin/color_matching (issue #110, shipped in PR #113), with
/// only the documented normalizations applied (friendly operationIds and the
/// schema expansions needed by the app).
///
/// These tests intentionally run without the generated client target so they
/// can gate the vendored artifact itself: if the server-side spec drifts, the
/// re-vendored document fails these checks (or the generated-client tests in
/// `GeneratedClientStubbedResponseTests.swift`) instead of the app failing at
/// runtime.
final class OpenAPISpecCoverageTests: XCTestCase {
    private struct ExpectedOperation {
        let method: String
        let path: String
        let operationID: String
        let successStatus: String

        init(_ method: String, _ path: String, operationID: String, successStatus: String) {
            self.method = method
            self.path = path
            self.operationID = operationID
            self.successStatus = successStatus
        }
    }

    private static let appOperations: [ExpectedOperation] = [
        ExpectedOperation("get", "/api/v1/test_sheets/{sheet_id}/manifest", operationID: "fetchSheetManifest", successStatus: "200"),
        ExpectedOperation("get", "/api/v1/test_sheets/recent", operationID: "listRecentSheets", successStatus: "200"),
        ExpectedOperation("get", "/api/v1/test_sheets/{sheet_id}/ranked_results", operationID: "fetchRankedResults", successStatus: "200"),
        ExpectedOperation("post", "/api/v1/test_sheets/{sheet_id}/captures", operationID: "createCapture", successStatus: "201"),
        ExpectedOperation("post", "/api/v1/captures/{capture_id}/measurements", operationID: "uploadMeasurements", successStatus: "200"),
        ExpectedOperation("post", "/api/v1/captures/{capture_id}/judgments", operationID: "uploadJudgments", successStatus: "200")
    ]

    private static let requiredSchemas = [
        "TestSheetManifest",
        "RecentSheetsResponse",
        "CaptureMetadata",
        "CaptureRequest",
        "CaptureCreatedResponse",
        "MeasurementUploadRequest",
        "MeasurementUploadResponse",
        "JudgmentUploadRequest",
        "JudgmentUploadResponse",
        "RankedResults"
    ]

    func testVendoredSpecFileExists() throws {
        let path = Self.vendoredSpecPath
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: path.path),
            "Missing vendored OpenAPI document at \(path.path). Vendor the document published by viamin/color_matching (GET /api/v1/openapi.json, issue #110 / PR #113) per docs/openapi-generated-client.md."
        )
    }

    func testVendoredSpecIsValidOpenAPI3() throws {
        let document = try Self.loadSpec()
        let version = try XCTUnwrap(document["openapi"] as? String, "The vendored document must declare its OpenAPI version.")
        XCTAssertTrue(version.hasPrefix("3."), "Expected an OpenAPI 3.x document, found \(version).")
        let info = try Self.dictionary("info", in: document)
        let title = try XCTUnwrap(info["title"] as? String, "info.title must be a non-empty string.")
        XCTAssertFalse(title.isEmpty)
        let infoVersion = try XCTUnwrap(info["version"] as? String, "info.version must be a non-empty string.")
        XCTAssertFalse(infoVersion.isEmpty)
    }

    func testSpecCoversEverySurfaceTheAppUses() throws {
        let document = try Self.loadSpec()
        let paths = try Self.dictionary("paths", in: document)

        for operation in Self.appOperations {
            let pathItem = try Self.dictionary(operation.path, in: paths, context: "paths")
            let operationObject = try Self.dictionary(operation.method, in: pathItem, context: "paths.\(operation.path)")

            let operationID = try XCTUnwrap(
                operationObject["operationId"] as? String,
                "paths.\(operation.path).\(operation.method) must declare an operationId."
            )
            XCTAssertEqual(
                operationID, operation.operationID,
                "paths.\(operation.path).\(operation.method) must use the pinned operationId \(operation.operationID) (see docs/openapi-generated-client.md)."
            )

            let responses = try Self.dictionary("responses", in: operationObject, context: "paths.\(operation.path).\(operation.method)")
            let success = try Self.dictionary(
                operation.successStatus,
                in: responses,
                context: "paths.\(operation.path).\(operation.method).responses"
            )
            let content = try Self.dictionary("content", in: success, context: "paths.\(operation.path).\(operation.method).responses.\(operation.successStatus)")
            let json = try Self.dictionary("application/json", in: content, context: "paths.\(operation.path).\(operation.method).responses.\(operation.successStatus).content")
            XCTAssertNotNil(json["schema"], "The \(operation.successStatus) response of \(operation.operationID) must declare a JSON schema.")
        }
    }

    func testWriteOperationsDeclareJSONRequestBodies() throws {
        let document = try Self.loadSpec()
        let paths = try Self.dictionary("paths", in: document)

        for operation in Self.appOperations where operation.method == "post" {
            let pathItem = try Self.dictionary(operation.path, in: paths, context: "paths")
            let operationObject = try Self.dictionary("post", in: pathItem, context: "paths.\(operation.path)")
            let requestBody = try Self.dictionary(
                "requestBody",
                in: operationObject,
                context: "paths.\(operation.path).post"
            )
            let content = try Self.dictionary("content", in: requestBody, context: "paths.\(operation.path).post.requestBody")
            let json = try Self.dictionary("application/json", in: content, context: "paths.\(operation.path).post.requestBody.content")
            XCTAssertNotNil(json["schema"], "\(operation.operationID) must declare a JSON request body schema.")
        }
    }

    func testOperationsRequireBearerAuth() throws {
        let document = try Self.loadSpec()
        let paths = try Self.dictionary("paths", in: document)

        for operation in Self.appOperations {
            let pathItem = try Self.dictionary(operation.path, in: paths, context: "paths")
            let operationObject = try Self.dictionary(operation.method, in: pathItem, context: "paths.\(operation.path)")
            let security = try XCTUnwrap(
                operationObject["security"] as? [[String: Any]],
                "paths.\(operation.path).\(operation.method) must declare a security requirement."
            )
            let schemeNames = security.flatMap { $0.keys }
            XCTAssertTrue(
                schemeNames.contains("bearerAuth"),
                "paths.\(operation.path).\(operation.method) must require the bearerAuth scheme."
            )
        }

        let components = try Self.dictionary("components", in: document)
        let schemes = try Self.dictionary("securitySchemes", in: components, context: "components")
        let bearer = try Self.dictionary("bearerAuth", in: schemes, context: "components.securitySchemes")
        XCTAssertEqual(bearer["type"] as? String, "http")
        XCTAssertEqual(bearer["scheme"] as? String, "bearer")
    }

    func testRequiredSchemasAreDeclared() throws {
        let document = try Self.loadSpec()
        let components = try Self.dictionary("components", in: document)
        let schemas = try Self.dictionary("schemas", in: components, context: "components")

        for schemaName in Self.requiredSchemas {
            XCTAssertNotNil(
                schemas[schemaName],
                "components.schemas must declare \(schemaName); the generated client and the stubbed-response tests rely on it."
            )
        }
    }

    func testManifestSchemaDeclaresGeometrySurfacesTheAppConsumes() throws {
        let manifest = try Self.schema("TestSheetManifest")
        let properties = try Self.properties(of: manifest, schema: "TestSheetManifest")

        for propertyName in [
            "schema_version", "sheet_id", "sheet_version", "manifest_url", "created_at",
            "page", "registration_markers", "printer_profile", "capture_profile",
            "patches", "pairs"
        ] {
            XCTAssertNotNil(properties[propertyName], "TestSheetManifest must declare the \(propertyName) property; the sheet analyzer consumes it.")
        }

        let schemaVersion = try Self.dictionary("schema_version", in: properties, context: "TestSheetManifest.properties")
        XCTAssertEqual(
            (schemaVersion["enum"] as? [String])?.sorted(), ["lps-sheet-manifest/v1"],
            "schema_version must keep the lps-sheet-manifest/v1 compatibility promise machine-visible."
        )

        let captureProfile = try Self.dictionary("capture_profile", in: properties, context: "TestSheetManifest.properties")
        let captureProfileProperties = try Self.properties(of: captureProfile, schema: "TestSheetManifest.capture_profile")
        let scoring = try Self.dictionary("scoring_algorithm_version", in: captureProfileProperties, context: "TestSheetManifest.capture_profile.properties")
        XCTAssertEqual(
            (scoring["enum"] as? [String])?.sorted(), ["lps-distance-v1"],
            "capture_profile.scoring_algorithm_version must keep the lps-distance-v1 compatibility promise machine-visible."
        )

        let patches = try Self.dictionary("patches", in: properties, context: "TestSheetManifest.properties")
        let patchProperties = try Self.itemProperties(of: patches, schema: "TestSheetManifest.patches")
        for propertyName in ["id", "role", "pair_id", "pair_side", "source_color", "safe_inset_mm", "rect"] {
            XCTAssertNotNil(patchProperties[propertyName], "TestSheetManifest.patches items must declare \(propertyName).")
        }

        let pairs = try Self.dictionary("pairs", in: properties, context: "TestSheetManifest.properties")
        let pairProperties = try Self.itemProperties(of: pairs, schema: "TestSheetManifest.pairs")
        for propertyName in ["id", "first_patch_id", "second_patch_id", "source_colors", "grid_row", "grid_col"] {
            XCTAssertNotNil(pairProperties[propertyName], "TestSheetManifest.pairs items must declare \(propertyName).")
        }
    }

    func testMeasurementUploadSchemaMatchesWhatTheAppSends() throws {
        let upload = try Self.schema("MeasurementUploadRequest")
        let properties = try Self.properties(of: upload, schema: "MeasurementUploadRequest")

        for propertyName in ["scoring_algorithm_version", "measurements", "pair_scores"] {
            XCTAssertNotNil(properties[propertyName], "MeasurementUploadRequest must declare \(propertyName); the app sends it today (docs/color-matching-api-contract.md).")
        }

        let measurements = try Self.dictionary("measurements", in: properties, context: "MeasurementUploadRequest.properties")
        let measurementProperties = try Self.itemProperties(of: measurements, schema: "MeasurementUploadRequest.measurements")
        for propertyName in ["patch_id", "linear_rgb_median", "normalized_linear_rgb_median", "stats"] {
            XCTAssertNotNil(measurementProperties[propertyName], "MeasurementUploadRequest.measurements items must declare \(propertyName).")
        }

        let stats = try Self.dictionary("stats", in: measurementProperties, context: "MeasurementUploadRequest.measurements.items.properties")
        let statsProperties = try Self.properties(of: stats, schema: "MeasurementUploadRequest.measurements.items.stats")
        for propertyName in ["sample_count", "clipping_fraction", "mean", "standard_deviation"] {
            XCTAssertNotNil(statsProperties[propertyName], "Measurement stats must declare \(propertyName).")
        }

        let pairScores = try Self.dictionary("pair_scores", in: properties, context: "MeasurementUploadRequest.properties")
        let pairScoreProperties = try Self.itemProperties(of: pairScores, schema: "MeasurementUploadRequest.pair_scores")
        for propertyName in ["pair_id", "algorithm_version", "distance", "similarity"] {
            XCTAssertNotNil(pairScoreProperties[propertyName], "MeasurementUploadRequest.pair_scores items must declare \(propertyName).")
        }
    }

    func testRankedResultsSchemaDeclaresResultRows() throws {
        let ranked = try Self.schema("RankedResults")
        let properties = try Self.properties(of: ranked, schema: "RankedResults")

        let schemaVersion = try Self.dictionary("schema_version", in: properties, context: "RankedResults.properties")
        XCTAssertEqual(
            (schemaVersion["enum"] as? [String])?.sorted(), ["lps-ranked-results/v1"],
            "RankedResults.schema_version must keep the lps-ranked-results/v1 compatibility promise machine-visible."
        )
        XCTAssertNotNil(properties["sheet_id"], "RankedResults must declare sheet_id.")
        XCTAssertNotNil(properties["results"], "RankedResults must declare results.")

        let results = try Self.dictionary("results", in: properties, context: "RankedResults.properties")
        let resultProperties = try Self.itemProperties(of: results, schema: "RankedResults.results")
        for propertyName in ["rank", "pair_id", "scoring_algorithm_version", "source_colors", "current_judgment"] {
            XCTAssertNotNil(resultProperties[propertyName], "RankedResults.results items must declare \(propertyName).")
        }
    }

    func testRecentSheetsSchemaKeepsNullableTitle() throws {
        let recent = try Self.schema("RecentSheetsResponse")
        let properties = try Self.properties(of: recent, schema: "RecentSheetsResponse")
        let sheets = try Self.dictionary("sheets", in: properties, context: "RecentSheetsResponse.properties")
        let sheetProperties = try Self.itemProperties(of: sheets, schema: "RecentSheetsResponse.sheets")

        for propertyName in ["sheet_id", "manifest_url", "title"] {
            XCTAssertNotNil(sheetProperties[propertyName], "RecentSheetsResponse.sheets items must declare \(propertyName).")
        }
        let title = try Self.dictionary("title", in: sheetProperties, context: "RecentSheetsResponse.sheets.items.properties")
        let isNullable: Bool
        if let nullable = title["nullable"] as? Bool {
            isNullable = nullable
        } else if let types = title["type"] as? [String] {
            isNullable = types.contains("null")
        } else {
            isNullable = false
        }
        XCTAssertTrue(isNullable, "RecentSheetsResponse.sheets.items.title must be nullable; the Phoenix app currently always renders it as null.")
    }

    // MARK: - Helpers

    private static var vendoredSpecPath: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("OpenAPI/color-matching-openapi.json")
    }

    private static func loadSpec() throws -> [String: Any] {
        let path = vendoredSpecPath
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: path.path),
            "Vendored OpenAPI document not found at \(path.path); see docs/openapi-generated-client.md for the vendoring pipeline."
        )
        let data = try Data(contentsOf: path)
        return try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any],
            "The vendored OpenAPI document at \(path.path) must be a JSON object."
        )
    }

    private static func dictionary(
        _ key: String,
        in container: [String: Any],
        context: String = "",
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws -> [String: Any] {
        let location = context.isEmpty ? key : "\(context).\(key)"
        return try XCTUnwrap(
            container[key] as? [String: Any],
            "\(location) must be a JSON object in the vendored OpenAPI document.",
            file: file,
            line: line
        )
    }

    private static func schema(_ name: String) throws -> [String: Any] {
        let document = try loadSpec()
        let components = try dictionary("components", in: document)
        let schemas = try dictionary("schemas", in: components, context: "components")
        return try dictionary(name, in: schemas, context: "components.schemas")
    }

    private static func properties(of schema: [String: Any], schema name: String) throws -> [String: Any] {
        try dictionary("properties", in: schema, context: name)
    }

    private static func itemProperties(of arraySchema: [String: Any], schema name: String) throws -> [String: Any] {
        let items = try dictionary("items", in: arraySchema, context: name)
        return try properties(of: items, schema: "\(name).items")
    }
}
