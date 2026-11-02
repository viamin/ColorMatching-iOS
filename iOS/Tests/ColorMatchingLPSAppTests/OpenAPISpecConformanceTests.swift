import Foundation
import XCTest

/// Guards the vendored OpenAPI document against drift with the API surfaces
/// this app depends on.
///
/// The document is vendored at `iOS/Sources/ColorMatchingOpenAPI/openapi.json`
/// and is fetched from the Phoenix app's `GET /api/v1/openapi.json` endpoint
/// (published by viamin/color_matching#110). These tests read the vendored
/// document from disk — without importing the generated client module — so
/// they run in the existing test target and fail loudly the moment the
/// document is missing or stops covering a surface the app uses.
final class OpenAPISpecConformanceTests: XCTestCase {
    private static let appOperations: [(path: String, method: String, operationID: String)] = [
        ("/api/v1/test_sheets/recent", "get", "ColorMatchingWeb.TestSheetController.recent"),
        ("/api/v1/test_sheets/{sheet_id}/manifest", "get", "ColorMatchingWeb.TestSheetController.manifest"),
        ("/api/v1/test_sheets/{sheet_id}/ranked_results", "get", "ColorMatchingWeb.TestSheetController.ranked_results"),
        ("/api/v1/test_sheets/{sheet_id}/captures", "post", "ColorMatchingWeb.CaptureController.create"),
        ("/api/v1/captures/{capture_id}/measurements", "post", "ColorMatchingWeb.CaptureController.upload_measurements"),
        ("/api/v1/captures/{capture_id}/judgments", "post", "ColorMatchingWeb.CaptureController.upload_judgments"),
    ]

    func testVendoredSpecExistsAndParsesAsOpenAPI3() throws {
        let spec = try Self.loadSpec()
        let openAPIVersion = try XCTUnwrap(spec["openapi"] as? String, "openapi version missing")
        XCTAssertTrue(openAPIVersion.hasPrefix("3."), "expected OpenAPI 3.x, got \(openAPIVersion)")
        let info = try XCTUnwrap(spec["info"] as? [String: Any])
        XCTAssertEqual(info["title"] as? String, "Color Matching API")
    }

    func testSpecDeclaresEveryOperationTheAppUses() throws {
        let spec = try Self.loadSpec()
        for (path, method, operationID) in Self.appOperations {
            let operation = try Self.operation(spec, path: path, method: method)
            XCTAssertEqual(
                operation["operationId"] as? String,
                operationID,
                "\(method.uppercased()) \(path) must keep its operationId — the generated Swift method name derives from it"
            )
        }
    }

    func testManifestSchemaPinsCompatibilityEnums() throws {
        let spec = try Self.loadSpec()
        let manifest = try Self.componentSchema(spec, "TestSheetManifest")
        XCTAssertEqual(
            Set(try Self.required(manifest)),
            ["schema_version", "sheet_id", "capture_profile"],
            "the published manifest schema only types these three fields — everything else in docs/color-matching-api-contract.md rides on undeclared additional properties"
        )
        let properties = try Self.properties(manifest)
        let schemaVersion = try XCTUnwrap(properties["schema_version"] as? [String: Any])
        XCTAssertEqual(schemaVersion["enum"] as? [String], ["lps-sheet-manifest/v1"])
        let captureProfile = try XCTUnwrap(properties["capture_profile"] as? [String: Any])
        let scoringVersion = try XCTUnwrap(try Self.properties(captureProfile)["scoring_algorithm_version"] as? [String: Any])
        XCTAssertEqual(scoringVersion["enum"] as? [String], ["lps-distance-v1"])
        XCTAssertTrue(try Self.required(captureProfile).contains("scoring_algorithm_version"))
    }

    func testRecentSheetsSchemaMatchesContractShape() throws {
        let spec = try Self.loadSpec()
        let response = try Self.componentSchema(spec, "RecentSheetsResponse")
        XCTAssertEqual(try Self.required(response), ["sheets"])
        let sheets = try XCTUnwrap(try Self.properties(response)["sheets"] as? [String: Any])
        let items = try XCTUnwrap(sheets["items"] as? [String: Any])
        XCTAssertEqual(
            Set(try Self.required(items)),
            ["sheet_id", "manifest_url", "title"],
            "title is required-but-nullable: the Phoenix app always renders it, sometimes as null"
        )
        let title = try XCTUnwrap(try Self.properties(items)["title"] as? [String: Any])
        XCTAssertEqual(title["nullable"] as? Bool, true)
    }

    func testCaptureRequestAcceptsNestedMetadataAndQualityForm() throws {
        let spec = try Self.loadSpec()
        let captureRequest = try Self.componentSchema(spec, "CaptureRequest")
        let properties = try Self.properties(captureRequest)
        let metadata = try XCTUnwrap(
            try Self.resolveRef(spec, properties["metadata"]),
            "CaptureRequest must expose the nested metadata form the app sends"
        )
        XCTAssertEqual(metadata["title"] as? String, "CaptureMetadata")
        let quality = try XCTUnwrap(properties["quality"] as? [String: Any])
        XCTAssertEqual(
            Set(try Self.properties(quality).keys),
            ["detected_marker_count", "blur_score", "rejections"],
            "quality uses 'rejections'; the flat anyOf variant uses 'rejection_reasons' — a contract delta"
        )
        let anyOfBranches = try XCTUnwrap(captureRequest["anyOf"] as? [[String: Any]])
        let branchRequireds = anyOfBranches.map { Set(Self.required($0)) }
        XCTAssertTrue(branchRequireds.contains(["metadata"]), "an anyOf branch must accept the nested metadata form alone")

        let captureMetadata = try Self.componentSchema(spec, "CaptureMetadata")
        XCTAssertEqual(
            Set(try Self.required(captureMetadata)),
            ["device_model", "lens", "image_width", "image_height", "app_version", "timestamp"],
            "exposure/iso/focus/white-balance remain optional"
        )
        let iso = try XCTUnwrap(try Self.properties(captureMetadata)["iso"] as? [String: Any])
        XCTAssertEqual(iso["type"] as? String, "integer", "iso is an integer in the published spec, not a float")
    }

    func testMeasurementUploadSchemaDropsStatsAndTopLevelAlgorithmVersion() throws {
        let spec = try Self.loadSpec()
        let upload = try Self.componentSchema(spec, "MeasurementUploadRequest")
        let properties = try Self.properties(upload)
        XCTAssertNil(
            properties["scoring_algorithm_version"],
            "the published spec has no top-level scoring_algorithm_version — the prose contract and hand-written client send one"
        )
        let measurements = try XCTUnwrap(properties["measurements"] as? [String: Any])
        let item = try XCTUnwrap(measurements["items"] as? [String: Any])
        XCTAssertEqual(
            Set(try Self.required(item)),
            ["patch_id", "linear_rgb_median", "normalized_linear_rgb_median"],
            "normalized_linear_rgb_median is required; the hand-written model treats it as optional"
        )
        XCTAssertNil(
            try Self.properties(item)["stats"],
            "the published spec drops the per-measurement stats object — a contract delta to record in the PR"
        )
        XCTAssertEqual(try Self.refName(properties["linear_rgb_median"]), "RgbPayload")
        XCTAssertEqual(try Self.refName(properties["pair_scores"]), "PairScoreRequest")
    }

    func testPairScoreSchemaRequiresAlgorithmVersionAndOneScoreForm() throws {
        let spec = try Self.loadSpec()
        let pairScore = try Self.componentSchema(spec, "PairScoreRequest")
        XCTAssertEqual(Set(try Self.required(pairScore)), ["pair_id", "algorithm_version"])
        let anyOfBranches = try XCTUnwrap(pairScore["anyOf"] as? [[String: Any]])
        let branchRequireds = Set(anyOfBranches.flatMap { Self.required($0) })
        XCTAssertEqual(branchRequireds, ["score", "similarity", "distance"])
    }

    func testUploadResponsesAreBodied() throws {
        let spec = try Self.loadSpec()
        let measurementsResponse = try Self.responseSchema(
            spec, path: "/api/v1/captures/{capture_id}/measurements", method: "post", status: "200"
        )
        XCTAssertEqual(measurementsResponse["title"] as? String, "MeasurementUploadResponse")
        XCTAssertEqual(
            Set(try Self.required(measurementsResponse)),
            ["capture_id", "measurement_count", "pair_score_count"],
            "measurement upload answers 200 with a body — not the bare 2xx the hand-written client tolerated"
        )
        let judgmentsResponse = try Self.responseSchema(
            spec, path: "/api/v1/captures/{capture_id}/judgments", method: "post", status: "200"
        )
        XCTAssertEqual(Set(try Self.required(judgmentsResponse)), ["capture_id", "judgment_count"])
        let captureResponse = try Self.responseSchema(
            spec, path: "/api/v1/test_sheets/{sheet_id}/captures", method: "post", status: "201"
        )
        XCTAssertEqual(Set(try Self.required(captureResponse)), ["capture_id"])
    }

    func testRankedResultsSchemaPinsVersionEnvelope() throws {
        let spec = try Self.loadSpec()
        let ranked = try Self.componentSchema(spec, "RankedResults")
        XCTAssertEqual(Set(try Self.required(ranked)), ["schema_version", "sheet_id"])
        let schemaVersion = try XCTUnwrap(try Self.properties(ranked)["schema_version"] as? [String: Any])
        XCTAssertEqual(schemaVersion["enum"] as? [String], ["lps-ranked-results/v1"])
    }

    func testJudgmentValuesAreFreeFormStrings() throws {
        let spec = try Self.loadSpec()
        let judgmentUpload = try Self.componentSchema(spec, "JudgmentUploadRequest")
        let judgments = try XCTUnwrap(try Self.properties(judgmentUpload)["judgments"] as? [String: Any])
        let item = try XCTUnwrap(judgments["items"] as? [String: Any])
        let judgment = try XCTUnwrap(try Self.properties(item)["judgment"] as? [String: Any])
        XCTAssertEqual(judgment["type"] as? String, "string")
        XCTAssertNil(judgment["enum"], "the prose contract's match/near_match/no_match enum is not enforced server-side")
    }

    func testBearerAuthSchemeIsDeclared() throws {
        let spec = try Self.loadSpec()
        let components = try XCTUnwrap(spec["components"] as? [String: Any])
        let schemes = try XCTUnwrap(components["securitySchemes"] as? [String: Any])
        let bearer = try XCTUnwrap(schemes["bearerAuth"] as? [String: Any])
        XCTAssertEqual(bearer["type"] as? String, "http")
        XCTAssertEqual(bearer["scheme"] as? String, "bearer")
    }

    func testSpecExposesEndpointsBeyondTheProseContract() throws {
        let spec = try Self.loadSpec()
        let extraSurfaces: [(path: String, method: String)] = [
            ("/api/v1/printer_profiles", "get"),
            ("/api/v1/palettes", "get"),
            ("/api/v1/colors", "get"),
            ("/api/illuminant_measurements", "post"),
            ("/api/multi_image_mapping", "post"),
        ]
        for (path, method) in extraSurfaces {
            _ = try Self.operation(spec, path: path, method: method)
        }
    }

    // MARK: - Spec loading and navigation

    private static func specFileURL() throws -> URL {
        let testFile = URL(fileURLWithPath: #filePath)
        let packageRoot = testFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return packageRoot
            .appendingPathComponent("Sources")
            .appendingPathComponent("ColorMatchingOpenAPI")
            .appendingPathComponent("openapi.json")
    }

    /// Loads the vendored OpenAPI document, failing with an actionable message
    /// when the implementation step that vendors it has not run yet.
    private static func loadSpec() throws -> [String: Any] {
        let url = try specFileURL()
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            XCTFail(
                "Vendored OpenAPI document is missing at \(url.path). "
                    + "Fetch it from the Phoenix app's GET /api/v1/openapi.json "
                    + "(published by viamin/color_matching#110) and commit it there."
            )
            throw error
        }
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        return object
    }

    private static func operation(_ spec: [String: Any], path: String, method: String) throws -> [String: Any] {
        let paths = try XCTUnwrap(spec["paths"] as? [String: Any], "paths missing")
        let pathItem = try XCTUnwrap(paths[path] as? [String: Any], "path \(path) missing from spec")
        return try XCTUnwrap(pathItem[method] as? [String: Any], "\(method.uppercased()) \(path) missing from spec")
    }

    private static func componentSchema(_ spec: [String: Any], _ name: String) throws -> [String: Any] {
        let components = try XCTUnwrap(spec["components"] as? [String: Any])
        let schemas = try XCTUnwrap(components["schemas"] as? [String: Any])
        return try XCTUnwrap(schemas[name] as? [String: Any], "component schema \(name) missing")
    }

    private static func responseSchema(_ spec: [String: Any], path: String, method: String, status: String) throws -> [String: Any] {
        let operation = try operation(spec, path: path, method: method)
        let responses = try XCTUnwrap(operation["responses"] as? [String: Any])
        let response = try XCTUnwrap(responses[status] as? [String: Any], "\(method.uppercased()) \(path) must declare \(status)")
        let content = try XCTUnwrap(response["content"] as? [String: Any])
        let json = try XCTUnwrap(content["application/json"] as? [String: Any])
        return try resolveRef(spec, json["schema"])
    }

    private static func resolveRef(_ spec: [String: Any], _ schema: Any?) throws -> [String: Any] {
        let object = try XCTUnwrap(schema as? [String: Any])
        let ref = try XCTUnwrap(object["$ref"] as? String, "expected a $ref, got \(object)")
        XCTAssertTrue(ref.hasPrefix("#/components/schemas/"))
        let name = String(ref.dropFirst("#/components/schemas/".count))
        return try componentSchema(spec, name)
    }

    private static func refName(_ schema: Any?) throws -> String {
        let object = try XCTUnwrap(schema as? [String: Any])
        let ref = try XCTUnwrap(object["$ref"] as? String, "expected a $ref, got \(object)")
        return String(ref.dropFirst("#/components/schemas/".count))
    }

    private static func properties(_ schema: [String: Any]) -> [String: Any] {
        schema["properties"] as? [String: Any] ?? [:]
    }

    private static func required(_ schema: [String: Any]) -> [String] {
        schema["required"] as? [String] ?? []
    }
}
