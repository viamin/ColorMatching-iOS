import Foundation
import XCTest

/// Verifies the OpenAPI document vendored into the Swift package matches the
/// spec published by `viamin/color_matching` at `GET /api/v1/openapi.json`
/// (landed via viamin/color_matching#113, closing #110).
///
/// These tests are the drift gate for the migration tracked in issue #5: when
/// the Phoenix app changes `/api/v1`, regenerating the vendored document from
/// upstream makes the change show up here as an assertion failure instead of
/// as a runtime surprise in the app.
///
/// The vendored document lives at `Sources/ColorMatchingAPI/openapi.json`.
/// Facts asserted here were extracted from the upstream source of truth:
/// `ColorMatchingWeb.Router`, `ColorMatchingWeb.ApiSpec`,
/// `ColorMatchingWeb.ApiSchemas`, and the `OpenApiSpex.ControllerSpecs`
/// declarations in `TestSheetController` / `CaptureController`.
///
/// Four documented vendoring patches (P1-P4) intentionally deviate from the
/// published document so the shapes the app sends remain expressible in
/// generated Swift types; see `docs/color-matching-openapi-contract-deltas.md`
/// for the rationale of each patch and the full prose-contract delta table.
final class OpenAPISpecCoverageTests: XCTestCase {
    private var document: [String: Any]!

    override func setUpWithError() throws {
        document = try Self.loadVendoredSpec()
    }

    // MARK: - Document

    func testVendoredSpecExistsAndDeclaresOpenAPI3() throws {
        let version = try XCTUnwrap(document["openapi"] as? String, "vendored document must declare an openapi version")
        XCTAssertTrue(version.hasPrefix("3."), "expected OpenAPI 3.x, got \(version)")
    }

    func testServerEntryMatchesPublishedRootServer() throws {
        let servers = try XCTUnwrap(document["servers"] as? [[String: Any]], "spec must declare servers")
        XCTAssertTrue(
            servers.contains { ($0["url"] as? String) == "/" },
            "published spec serves from the root; /api/v1 lives in the path templates, got \(servers)"
        )
    }

    // MARK: - Operations the app uses

    func testAppUsedOperationsMatchPublishedOperationIDsAndStatusCodes() throws {
        let expectations: [(path: String, method: String, operationID: String, statuses: Set<String>)] = [
            ("/api/v1/test_sheets/recent", "get", "ColorMatchingWeb.TestSheetController.recent", ["200", "401"]),
            ("/api/v1/test_sheets/{sheet_id}/manifest", "get", "ColorMatchingWeb.TestSheetController.manifest", ["200", "401", "404"]),
            ("/api/v1/test_sheets/{sheet_id}/ranked_results", "get", "ColorMatchingWeb.TestSheetController.ranked_results", ["200", "401", "404"]),
            ("/api/v1/test_sheets/{sheet_id}/captures", "post", "ColorMatchingWeb.CaptureController.create", ["201", "401", "404", "422"]),
            ("/api/v1/captures/{capture_id}/measurements", "post", "ColorMatchingWeb.CaptureController.upload_measurements", ["200", "401", "404", "422"]),
            ("/api/v1/captures/{capture_id}/judgments", "post", "ColorMatchingWeb.CaptureController.upload_judgments", ["200", "401", "404", "422"]),
        ]

        for expectation in expectations {
            let operationSpec = try operation(expectation.path, expectation.method)
            XCTAssertEqual(
                operationSpec["operationId"] as? String,
                expectation.operationID,
                "\(expectation.method.uppercased()) \(expectation.path) must keep the published operationId"
            )
            let responses = try XCTUnwrap(operationSpec["responses"] as? [String: Any])
            XCTAssertEqual(
                Set(responses.keys),
                expectation.statuses,
                "\(expectation.method.uppercased()) \(expectation.path) response status codes drifted from the published spec"
            )
        }
    }

    func testAppUsedOperationsRequireBearerAuth() throws {
        let operations: [(path: String, method: String)] = [
            ("/api/v1/test_sheets/recent", "get"),
            ("/api/v1/test_sheets/{sheet_id}/manifest", "get"),
            ("/api/v1/test_sheets/{sheet_id}/ranked_results", "get"),
            ("/api/v1/test_sheets/{sheet_id}/captures", "post"),
            ("/api/v1/captures/{capture_id}/measurements", "post"),
            ("/api/v1/captures/{capture_id}/judgments", "post"),
        ]

        for entry in operations {
            let operationSpec = try operation(entry.path, entry.method)
            let security = try XCTUnwrap(operationSpec["security"] as? [[String: Any]])
            XCTAssertTrue(
                security.contains { $0["bearerAuth"] != nil },
                "\(entry.method.uppercased()) \(entry.path) must require bearerAuth"
            )
        }
    }

    func testBearerSecuritySchemeMatchesPublishedSpec() throws {
        let schemes = try XCTUnwrap(
            (document["components"] as? [String: Any])?["securitySchemes"] as? [String: Any],
            "spec must declare components.securitySchemes"
        )
        let bearer = try XCTUnwrap(schemes["bearerAuth"] as? [String: Any])
        XCTAssertEqual(bearer["type"] as? String, "http")
        XCTAssertEqual(bearer["scheme"] as? String, "bearer")
    }

    // MARK: - Schemas the app's generated client is built from

    func testPublishedSchemasAreVendored() throws {
        let required = [
            "TestSheetManifest",
            "RankedResults",
            "RecentSheetsResponse",
            "CaptureRequest",
            "CaptureMetadata",
            "CaptureCreatedResponse",
            "MeasurementUploadRequest",
            "PairScoreRequest",
            "RgbPayload",
            "MeasurementUploadResponse",
            "JudgmentUploadRequest",
            "JudgmentUploadResponse",
            "ApiErrorResponse",
        ]
        let schemas = try schemas()
        for name in required {
            XCTAssertNotNil(schemas[name], "vendored spec must declare components.schemas.\(name)")
        }
    }

    func testManifestSchemaPinsVersionedContract() throws {
        let manifest = try schema("TestSheetManifest")
        let properties = try XCTUnwrap(manifest["properties"] as? [String: Any])
        XCTAssertEqual(
            Set((manifest["required"] as? [String]) ?? []),
            ["schema_version", "sheet_id", "capture_profile"]
        )
        let schemaVersion = try XCTUnwrap(properties["schema_version"] as? [String: Any])
        XCTAssertEqual(schemaVersion["enum"] as? [String], ["lps-sheet-manifest/v1"])

        let captureProfile = try XCTUnwrap(properties["capture_profile"] as? [String: Any])
        XCTAssertEqual((captureProfile["required"] as? [String]) ?? [], ["scoring_algorithm_version"])
        let scoringVersion = try XCTUnwrap(
            ((captureProfile["properties"] as? [String: Any])?["scoring_algorithm_version"] as? [String: Any])
        )
        XCTAssertEqual(scoringVersion["enum"] as? [String], ["lps-distance-v1"])
    }

    func testRecentSheetsSchemaMatchesPublishedContract() throws {
        let recent = try schema("RecentSheetsResponse")
        XCTAssertEqual((recent["required"] as? [String]) ?? [], ["sheets"])
        let sheets = try XCTUnwrap(((recent["properties"] as? [String: Any])?["sheets"] as? [String: Any]))
        let items = try XCTUnwrap(sheets["items"] as? [String: Any])
        XCTAssertEqual(
            Set((items["required"] as? [String]) ?? []),
            ["sheet_id", "manifest_url", "title"]
        )
        let title = try XCTUnwrap((items["properties"] as? [String: Any])?["title"] as? [String: Any])
        XCTAssertTrue(Self.isNullable(title), "title must stay nullable (sheets without a display name)")
    }

    func testCaptureSchemasMatchPublishedContractWithDocumentedPatches() throws {
        let captureRequest = try schema("CaptureRequest")
        let requestProperties = try XCTUnwrap(captureRequest["properties"] as? [String: Any])
        XCTAssertEqual(
            Set(requestProperties.keys),
            ["metadata", "quality"],
            "vendoring patch P1 keeps only the nested metadata/quality form the app sends; the published flat-legacy anyOf variant is dropped"
        )
        XCTAssertEqual((captureRequest["required"] as? [String]) ?? [], ["metadata"])

        let quality = try XCTUnwrap(requestProperties["quality"] as? [String: Any])
        XCTAssertEqual(
            Set(((quality["properties"] as? [String: Any]) ?? [:]).keys),
            ["detected_marker_count", "blur_score", "rejections"]
        )

        let metadata = try schema("CaptureMetadata")
        let metadataProperties = try XCTUnwrap(metadata["properties"] as? [String: Any])
        XCTAssertEqual(
            Set((metadata["required"] as? [String]) ?? []),
            ["device_model", "lens", "image_width", "image_height", "app_version", "timestamp"]
        )
        XCTAssertEqual((metadataProperties["iso"] as? [String: Any])?["type"] as? String, "integer")
        XCTAssertEqual((metadataProperties["timestamp"] as? [String: Any])?["format"] as? String, "date-time")
        let gains = try XCTUnwrap(metadataProperties["white_balance_gains"] as? [String: Any])
        XCTAssertEqual(
            gains["additionalProperties"] as? Bool,
            true,
            "vendoring patch P4 types white_balance_gains as a free-form object so gains survive generation"
        )

        let created = try schema("CaptureCreatedResponse")
        XCTAssertEqual((created["required"] as? [String]) ?? [], ["capture_id"])
    }

    func testMeasurementSchemasMatchPublishedContractWithDocumentedPatches() throws {
        let upload = try schema("MeasurementUploadRequest")
        let properties = try XCTUnwrap(upload["properties"] as? [String: Any])
        XCTAssertEqual(
            Set(properties.keys),
            ["measurements", "pair_scores"],
            "the published spec has no top-level scoring_algorithm_version; per-pair algorithm_version replaces it"
        )

        let measurements = try XCTUnwrap(properties["measurements"] as? [String: Any])
        let items = try XCTUnwrap(measurements["items"] as? [String: Any])
        let itemProperties = try XCTUnwrap(items["properties"] as? [String: Any])
        XCTAssertEqual(
            Set((items["required"] as? [String]) ?? []),
            ["patch_id", "linear_rgb_median", "normalized_linear_rgb_median"],
            "the published spec requires normalized_linear_rgb_median on every measurement"
        )
        XCTAssertNil(
            itemProperties["stats"],
            "the published spec has no stats object (sample_count/clipping_fraction/mean/standard_deviation are dropped server-side)"
        )

        let rgb = try schema("RgbPayload")
        XCTAssertEqual(rgb["type"] as? String, "object")
        XCTAssertEqual(Set(((rgb["properties"] as? [String: Any]) ?? [:]).keys), ["r", "g", "b"])
        XCTAssertEqual(Set((rgb["required"] as? [String]) ?? []), ["r", "g", "b"])
        XCTAssertNil(rgb["anyOf"], "vendoring patch P3 keeps RgbPayload in the object {r,g,b} form the app sends")

        let pairScore = try schema("PairScoreRequest")
        XCTAssertEqual(
            Set((pairScore["required"] as? [String]) ?? []),
            ["pair_id", "algorithm_version"]
        )
        XCTAssertEqual(
            Set(((pairScore["properties"] as? [String: Any]) ?? [:]).keys),
            ["pair_id", "algorithm_version", "score", "similarity", "distance"]
        )
        XCTAssertNil(
            pairScore["anyOf"],
            "vendoring patch P2 flattens the anyOf(score|similarity|distance) subset constraint into optional properties"
        )

        let response = try schema("MeasurementUploadResponse")
        XCTAssertEqual(
            Set((response["required"] as? [String]) ?? []),
            ["capture_id", "measurement_count", "pair_score_count"]
        )
    }

    func testJudgmentSchemaMatchesPublishedContract() throws {
        let upload = try schema("JudgmentUploadRequest")
        XCTAssertEqual((upload["required"] as? [String]) ?? [], ["judgments"])
        let judgments = try XCTUnwrap(((upload["properties"] as? [String: Any])?["judgments"] as? [String: Any]))
        let items = try XCTUnwrap(judgments["items"] as? [String: Any])
        XCTAssertEqual(
            Set((items["required"] as? [String]) ?? []),
            ["pair_id", "judgment"]
        )
        let judgment = try XCTUnwrap((items["properties"] as? [String: Any])?["judgment"] as? [String: Any])
        XCTAssertNil(
            judgment["enum"],
            "the published spec validates judgment as a plain string; the prose contract's match/near_match/no_match list is not enforced server-side"
        )

        let response = try schema("JudgmentUploadResponse")
        XCTAssertEqual(
            Set((response["required"] as? [String]) ?? []),
            ["capture_id", "judgment_count"]
        )
    }

    func testRankedResultsSchemaMatchesPublishedContract() throws {
        let ranked = try schema("RankedResults")
        XCTAssertEqual(
            Set((ranked["required"] as? [String]) ?? []),
            ["schema_version", "sheet_id"]
        )
        let schemaVersion = try XCTUnwrap(
            ((ranked["properties"] as? [String: Any])?["schema_version"] as? [String: Any])
        )
        XCTAssertEqual(
            schemaVersion["enum"] as? [String],
            ["lps-ranked-results/v1"],
            "the published spec introduces the lps-ranked-results/v1 version string, absent from the prose contract"
        )
    }

    // MARK: - Helpers

    private static func loadVendoredSpec() throws -> [String: Any] {
        let url = packageRoot()
            .appendingPathComponent("Sources")
            .appendingPathComponent("ColorMatchingAPI")
            .appendingPathComponent("openapi.json")
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: url.path),
            "vendored OpenAPI document is missing at \(url.path); vendor it per docs/openapi-client-migration-test-plan.md"
        )
        let data = try Data(contentsOf: url)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private static func packageRoot() -> URL {
        var directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        while directory.pathComponents.count > 1 {
            if FileManager.default.fileExists(atPath: directory.appendingPathComponent("Package.swift").path) {
                return directory
            }
            directory.deleteLastPathComponent()
        }
        return URL(fileURLWithPath: "/") // unreachable in practice; tests fail with a missing-file assertion
    }

    private func operation(_ path: String, _ method: String) throws -> [String: Any] {
        let paths = try XCTUnwrap(document["paths"] as? [String: Any], "spec must declare paths")
        let pathItem = try XCTUnwrap(paths[path] as? [String: Any], "spec must declare path \(path)")
        return try XCTUnwrap(
            pathItem[method] as? [String: Any],
            "path \(path) must declare a \(method.uppercased()) operation"
        )
    }

    private func schemas() throws -> [String: Any] {
        let components = try XCTUnwrap(document["components"] as? [String: Any])
        return try XCTUnwrap(components["schemas"] as? [String: Any])
    }

    private func schema(_ name: String) throws -> [String: Any] {
        let allSchemas = try schemas()
        return try XCTUnwrap(allSchemas[name] as? [String: Any], "spec must declare schema \(name)")
    }

    private static func isNullable(_ property: [String: Any]) -> Bool {
        if let nullable = property["nullable"] as? Bool { return nullable }
        if let types = property["type"] as? [String] { return types.contains("null") }
        return false
    }
}
