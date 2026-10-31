import Foundation
import XCTest

final class OpenAPISpecVendoringTests: XCTestCase {
    private var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private var packageManifestURL: URL {
        repositoryRoot.appending(path: "iOS/Package.swift")
    }

    private var vendoredSpecURL: URL {
        repositoryRoot.appending(path: "iOS/OpenAPI/color-matching.json")
    }

    func testPackageManifestDeclaresGeneratedClientWiring() throws {
        let manifest = try String(contentsOf: packageManifestURL, encoding: .utf8)
        let requiredMarkers = [
            "swift-openapi-generator",
            "swift-openapi-runtime",
            "swift-openapi-urlsession",
            "OpenAPIGenerator",
            "ColorMatchingOpenAPI"
        ]
        for marker in requiredMarkers {
            XCTAssertTrue(
                manifest.contains(marker),
                "iOS/Package.swift must declare \(marker); see docs/openapi-client-migration.md"
            )
        }
    }

    func testVendoredSpecParsesAsOpenAPIDocument() throws {
        let data = try Data(contentsOf: vendoredSpecURL)
        let object = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let version = try XCTUnwrap(object["openapi"] as? String)
        XCTAssertTrue(version.hasPrefix("3"), "expected OpenAPI 3.x, got \(version)")
        XCTAssertNotNil(object["paths"])
        XCTAssertNotNil(object["components"])
    }

    func testVendoredSpecDocumentsAppSurfacesWithUpstreamOperationIDs() throws {
        let spec = try loadSpecObject()
        let surfaces: [(method: String, path: String, operationID: String)] = [
            ("get", "/api/v1/test_sheets/recent", "ColorMatchingWeb.TestSheetController.recent"),
            ("get", "/api/v1/test_sheets/{sheet_id}/manifest", "ColorMatchingWeb.TestSheetController.manifest"),
            ("get", "/api/v1/test_sheets/{sheet_id}/ranked_results", "ColorMatchingWeb.TestSheetController.ranked_results"),
            ("post", "/api/v1/test_sheets/{sheet_id}/captures", "ColorMatchingWeb.CaptureController.create"),
            ("post", "/api/v1/captures/{capture_id}/measurements", "ColorMatchingWeb.CaptureController.upload_measurements"),
            ("post", "/api/v1/captures/{capture_id}/judgments", "ColorMatchingWeb.CaptureController.upload_judgments")
        ]
        for surface in surfaces {
            let operation = try operation(surface.method, surface.path, in: spec)
            XCTAssertEqual(
                operation["operationId"] as? String,
                surface.operationID,
                "\(surface.method) \(surface.path) must keep the operationId published at GET /api/v1/openapi.json so regeneration diffs stay meaningful"
            )
        }
    }

    func testManifestSchemaDeltasAgainstProseContract() throws {
        let spec = try loadSpecObject()
        let manifest = try schemaNamed("TestSheetManifest", in: spec)
        XCTAssertEqual(try requiredSet(manifest), ["schema_version", "sheet_id", "capture_profile"])
        let props = try properties(manifest)
        let fieldsTheAppStillNeeds = [
            "page", "patches", "pairs", "registration_markers",
            "printer_profile", "sheet_version", "manifest_url", "created_at"
        ]
        for field in fieldsTheAppStillNeeds {
            XCTAssertNil(
                props[field],
                "\(field) is documented in the spec but not in docs/color-matching-api-contract.md; update the delta record in docs/openapi-client-migration.md"
            )
        }
        let schemaVersion = try XCTUnwrap(props["schema_version"] as? [String: Any])
        XCTAssertEqual(schemaVersion["enum"] as? [String], ["lps-sheet-manifest/v1"])
        let captureProfile = try XCTUnwrap(props["capture_profile"] as? [String: Any])
        let captureProfileProps = try XCTUnwrap(captureProfile["properties"] as? [String: Any])
        let scoring = try XCTUnwrap(captureProfileProps["scoring_algorithm_version"] as? [String: Any])
        XCTAssertEqual(scoring["enum"] as? [String], ["lps-distance-v1"])
    }

    func testCaptureSurfaceDeltasAgainstProseContract() throws {
        let spec = try loadSpecObject()
        let request = try schemaNamed("CaptureRequest", in: spec)
        XCTAssertGreaterThanOrEqual(
            try anyOfBranches(request).count, 2,
            "spec accepts both the nested {metadata, quality} shape and a flat legacy shape"
        )
        let flatProps = try properties(request)
        XCTAssertNotNil(
            flatProps["exposure_duration"],
            "flat legacy branch uses exposure_duration, not the prose exposure_duration_seconds"
        )
        XCTAssertNotNil(
            flatProps["rejection_reasons"],
            "flat legacy branch uses rejection_reasons, not the prose quality.rejections"
        )
        let metadata = try schemaNamed("CaptureMetadata", in: spec)
        XCTAssertEqual(
            try requiredSet(metadata),
            ["device_model", "lens", "image_width", "image_height", "app_version", "timestamp"]
        )
        let created = try responseObject("201", "post", "/api/v1/test_sheets/{sheet_id}/captures", in: spec)
        XCTAssertEqual(try referencedSchemaName(created), "CaptureCreatedResponse")
        XCTAssertEqual(try requiredSet(try schemaNamed("CaptureCreatedResponse", in: spec)), ["capture_id"])
    }

    func testMeasurementUploadDeltasAgainstProseContract() throws {
        let spec = try loadSpecObject()
        let request = try schemaNamed("MeasurementUploadRequest", in: spec)
        let props = try properties(request)
        XCTAssertNil(
            props["scoring_algorithm_version"],
            "spec dropped the prose top-level scoring_algorithm_version field"
        )
        let items = try XCTUnwrap((props["measurements"] as? [String: Any])?["items"] as? [String: Any])
        XCTAssertEqual(
            try requiredSet(items),
            ["patch_id", "linear_rgb_median", "normalized_linear_rgb_median"],
            "spec requires normalized_linear_rgb_median on every measurement; prose and the app treat it as optional"
        )
        let itemProps = try properties(items)
        XCTAssertNil(itemProps["stats"], "spec dropped the prose per-measurement stats block")
        let rgbPayload = try schemaNamed("RgbPayload", in: spec)
        XCTAssertGreaterThanOrEqual(
            try anyOfBranches(rgbPayload).count, 3,
            "RgbPayload accepts array, object, and string forms; prose documents only the object form"
        )
        let pairScore = try schemaNamed("PairScoreRequest", in: spec)
        XCTAssertEqual(try requiredSet(pairScore), ["pair_id", "algorithm_version"])
        XCTAssertGreaterThanOrEqual(
            try anyOfBranches(pairScore).count, 3,
            "a pair score may arrive as score, similarity, or distance"
        )
        let response = try responseObject("200", "post", "/api/v1/captures/{capture_id}/measurements", in: spec)
        XCTAssertEqual(try referencedSchemaName(response), "MeasurementUploadResponse")
        XCTAssertEqual(
            try requiredSet(try schemaNamed("MeasurementUploadResponse", in: spec)),
            ["capture_id", "measurement_count", "pair_score_count"]
        )
    }

    func testJudgmentAndRankedResultsDeltasAgainstProseContract() throws {
        let spec = try loadSpecObject()
        let judgmentRequest = try schemaNamed("JudgmentUploadRequest", in: spec)
        XCTAssertEqual(try requiredSet(judgmentRequest), ["judgments"])
        let judgmentItems = try XCTUnwrap((try properties(judgmentRequest))["judgments"] as? [String: Any])
        let items = try XCTUnwrap(judgmentItems["items"] as? [String: Any])
        XCTAssertEqual(try requiredSet(items), ["pair_id", "judgment"])

        let judgmentResponse = try responseObject("200", "post", "/api/v1/captures/{capture_id}/judgments", in: spec)
        XCTAssertEqual(try referencedSchemaName(judgmentResponse), "JudgmentUploadResponse")
        XCTAssertEqual(
            try requiredSet(try schemaNamed("JudgmentUploadResponse", in: spec)),
            ["capture_id", "judgment_count"]
        )

        let ranked = try schemaNamed("RankedResults", in: spec)
        XCTAssertEqual(try requiredSet(ranked), ["schema_version", "sheet_id"])
        let rankedProps = try properties(ranked)
        let schemaVersion = try XCTUnwrap(rankedProps["schema_version"] as? [String: Any])
        XCTAssertEqual(
            schemaVersion["enum"] as? [String],
            ["lps-ranked-results/v1"],
            "lps-ranked-results/v1 is a schema version string the prose contract never mentioned"
        )
        XCTAssertEqual(
            rankedProps.count, 2,
            "spec documents no scores, labels, capture provenance, or printer profile for ranked results yet"
        )

        let recent = try schemaNamed("RecentSheetsResponse", in: spec)
        let sheets = try XCTUnwrap((try properties(recent))["sheets"] as? [String: Any])
        let sheetItems = try XCTUnwrap(sheets["items"] as? [String: Any])
        XCTAssertEqual(try requiredSet(sheetItems), ["sheet_id", "manifest_url", "title"])
        let title = try XCTUnwrap((try properties(sheetItems))["title"] as? [String: Any])
        XCTAssertEqual(title["nullable"] as? Bool, true)
    }

    func testVendoredSpecDocumentsEndpointsBeyondTheProseContract() throws {
        let spec = try loadSpecObject()
        let paths = try XCTUnwrap(spec["paths"] as? [String: Any])
        let undocumentedInProse = [
            "/api/v1/printer_profiles",
            "/api/v1/printer_profiles/{printer_profile_id}/colors",
            "/api/v1/printer_profiles/{printer_profile_id}/metamer_pairs",
            "/api/v1/palettes",
            "/api/v1/colors",
            "/api/illuminant_measurements",
            "/api/illuminant_measurements/bulk",
            "/api/multi_image_mapping"
        ]
        for path in undocumentedInProse {
            XCTAssertNotNil(
                paths[path],
                "spec path \(path) is missing; the spec covers endpoints the prose contract never documented"
            )
        }
    }

    private func loadSpecObject() throws -> [String: Any] {
        let data = try Data(contentsOf: vendoredSpecURL)
        return try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private func schemaNamed(_ name: String, in spec: [String: Any]) throws -> [String: Any] {
        let components = try XCTUnwrap(spec["components"] as? [String: Any])
        let schemas = try XCTUnwrap(components["schemas"] as? [String: Any])
        return try XCTUnwrap(schemas[name] as? [String: Any], "components.schemas.\(name) missing from vendored spec")
    }

    private func operation(_ method: String, _ path: String, in spec: [String: Any]) throws -> [String: Any] {
        let paths = try XCTUnwrap(spec["paths"] as? [String: Any])
        let pathItem = try XCTUnwrap(paths[path] as? [String: Any], "path \(path) missing from vendored spec")
        return try XCTUnwrap(pathItem[method] as? [String: Any], "\(method) missing on \(path)")
    }

    private func responseObject(
        _ status: String,
        _ method: String,
        _ path: String,
        in spec: [String: Any]
    ) throws -> [String: Any] {
        let operation = try operation(method, path, in: spec)
        let responses = try XCTUnwrap(operation["responses"] as? [String: Any])
        return try XCTUnwrap(responses[status] as? [String: Any], "\(status) response missing on \(method) \(path)")
    }

    private func referencedSchemaName(_ response: [String: Any]) throws -> String {
        let content = try XCTUnwrap(response["content"] as? [String: Any])
        let json = try XCTUnwrap(content["application/json"] as? [String: Any])
        let schema = try XCTUnwrap(json["schema"] as? [String: Any])
        let reference = try XCTUnwrap(schema["$ref"] as? String)
        return String(reference.dropFirst("#/components/schemas/".count))
    }

    private func requiredSet(_ schema: [String: Any]) throws -> Set<String> {
        Set(try XCTUnwrap(schema["required"] as? [String]))
    }

    private func properties(_ schema: [String: Any]) throws -> [String: Any] {
        (schema["properties"] as? [String: Any]) ?? [:]
    }

    private func anyOfBranches(_ schema: [String: Any]) throws -> [[String: Any]] {
        try XCTUnwrap(schema["anyOf"] as? [[String: Any]])
    }
}
