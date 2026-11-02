import Foundation
import XCTest

final class OpenAPISpecConformanceTests: XCTestCase {
    private static let packageRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    private func loadSpec() throws -> [String: Any] {
        let url = Self.packageRoot.appending(path: "Sources/ColorMatchingAPI/openapi.json")
        let data = try Data(contentsOf: url)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private func operation(_ spec: [String: Any], path: String, method: String) throws -> [String: Any] {
        let paths = try XCTUnwrap(spec["paths"] as? [String: Any])
        let pathItem = try XCTUnwrap(paths[path] as? [String: Any])
        return try XCTUnwrap(pathItem[method] as? [String: Any])
    }

    private func resolve(_ node: [String: Any], in spec: [String: Any]) throws -> [String: Any] {
        var current = node
        while let ref = current["$ref"] as? String {
            let segments = ref.split(separator: "/").map(String.init).filter { $0 != "#" }
            var cursor: Any = spec
            for segment in segments {
                let container = try XCTUnwrap(cursor as? [String: Any])
                cursor = try XCTUnwrap(container[segment])
            }
            current = try XCTUnwrap(cursor as? [String: Any])
        }
        return current
    }

    private func componentSchema(_ spec: [String: Any], name: String) throws -> [String: Any] {
        let components = try XCTUnwrap(spec["components"] as? [String: Any])
        let schemas = try XCTUnwrap(components["schemas"] as? [String: Any])
        return try XCTUnwrap(schemas[name] as? [String: Any])
    }

    private func responseSchema(_ spec: [String: Any], operation: [String: Any], status: String) throws -> [String: Any] {
        let responses = try XCTUnwrap(operation["responses"] as? [String: Any])
        let response = try XCTUnwrap(responses[status] as? [String: Any])
        let content = try XCTUnwrap(response["content"] as? [String: Any])
        let json = try XCTUnwrap(content["application/json"] as? [String: Any])
        let schema = try XCTUnwrap(json["schema"] as? [String: Any])
        return try resolve(schema, in: spec)
    }

    private func requestBodySchema(_ spec: [String: Any], operation: [String: Any]) throws -> [String: Any] {
        let requestBody = try XCTUnwrap(operation["requestBody"] as? [String: Any])
        let content = try XCTUnwrap(requestBody["content"] as? [String: Any])
        let json = try XCTUnwrap(content["application/json"] as? [String: Any])
        let schema = try XCTUnwrap(json["schema"] as? [String: Any])
        return try resolve(schema, in: spec)
    }

    private func properties(_ schema: [String: Any]) throws -> [String: Any] {
        try XCTUnwrap(schema["properties"] as? [String: Any])
    }

    private func requiredFields(_ schema: [String: Any]) throws -> [String] {
        try XCTUnwrap(schema["required"] as? [String])
    }

    func testSpecExistsAndParsesAsOpenAPIV3() throws {
        let spec = try loadSpec()
        let version = try XCTUnwrap(spec["openapi"] as? String)
        XCTAssertTrue(version.hasPrefix("3."), "expected OpenAPI 3.x, got \(version)")
        let info = try XCTUnwrap(spec["info"] as? [String: Any])
        XCTAssertFalse(try XCTUnwrap(info["title"] as? String).isEmpty)
    }

    func testSpecDeclaresBearerAuthSecurityScheme() throws {
        let spec = try loadSpec()
        let components = try XCTUnwrap(spec["components"] as? [String: Any])
        let schemes = try XCTUnwrap(components["securitySchemes"] as? [String: Any])
        let bearer = try XCTUnwrap(schemes["bearerAuth"] as? [String: Any])
        XCTAssertEqual(bearer["type"] as? String, "http")
        XCTAssertEqual(bearer["scheme"] as? String, "bearer")
    }

    func testManifestOperationMatchesPublishedAPI() throws {
        let spec = try loadSpec()
        let operation = try operation(
            spec,
            path: "/api/v1/test_sheets/{sheet_id}/manifest",
            method: "get"
        )
        XCTAssertEqual(operation["operationId"] as? String, "ColorMatchingWeb.TestSheetController.manifest")
        XCTAssertEqual(
            operation["security"] as? [[String: [String]]],
            [["bearerAuth": []]]
        )
        let schema = try responseSchema(spec, operation: operation, status: "200")
        XCTAssertEqual(schema["title"] as? String, "TestSheetManifest")
        let responses = try XCTUnwrap(operation["responses"] as? [String: Any])
        XCTAssertNotNil(responses["404"])
    }

    func testRecentSheetsOperationMatchesPublishedAPI() throws {
        let spec = try loadSpec()
        let operation = try operation(
            spec,
            path: "/api/v1/test_sheets/recent",
            method: "get"
        )
        XCTAssertEqual(operation["operationId"] as? String, "ColorMatchingWeb.TestSheetController.recent")
        let schema = try responseSchema(spec, operation: operation, status: "200")
        XCTAssertEqual(schema["title"] as? String, "RecentSheetsResponse")
        XCTAssertEqual(try requiredFields(schema), ["sheets"])
    }

    func testRankedResultsOperationMatchesPublishedAPI() throws {
        let spec = try loadSpec()
        let operation = try operation(
            spec,
            path: "/api/v1/test_sheets/{sheet_id}/ranked_results",
            method: "get"
        )
        XCTAssertEqual(operation["operationId"] as? String, "ColorMatchingWeb.TestSheetController.ranked_results")
        let schema = try responseSchema(spec, operation: operation, status: "200")
        XCTAssertEqual(schema["title"] as? String, "RankedResults")
        XCTAssertEqual(try requiredFields(schema), ["schema_version", "sheet_id"])
    }

    func testCreateCaptureOperationMatchesPublishedAPI() throws {
        let spec = try loadSpec()
        let operation = try operation(
            spec,
            path: "/api/v1/test_sheets/{sheet_id}/captures",
            method: "post"
        )
        XCTAssertEqual(operation["operationId"] as? String, "ColorMatchingWeb.CaptureController.create")
        let bodySchema = try requestBodySchema(spec, operation: operation)
        XCTAssertEqual(bodySchema["title"] as? String, "CaptureRequest")
        let created = try responseSchema(spec, operation: operation, status: "201")
        XCTAssertEqual(created["title"] as? String, "CaptureCreatedResponse")
    }

    func testMeasurementUploadOperationMatchesPublishedAPI() throws {
        let spec = try loadSpec()
        let operation = try operation(
            spec,
            path: "/api/v1/captures/{capture_id}/measurements",
            method: "post"
        )
        XCTAssertEqual(
            operation["operationId"] as? String,
            "ColorMatchingWeb.CaptureController.upload_measurements"
        )
        let bodySchema = try requestBodySchema(spec, operation: operation)
        XCTAssertEqual(bodySchema["title"] as? String, "MeasurementUploadRequest")
        let accepted = try responseSchema(spec, operation: operation, status: "200")
        XCTAssertEqual(accepted["title"] as? String, "MeasurementUploadResponse")
    }

    func testJudgmentUploadOperationMatchesPublishedAPI() throws {
        let spec = try loadSpec()
        let operation = try operation(
            spec,
            path: "/api/v1/captures/{capture_id}/judgments",
            method: "post"
        )
        XCTAssertEqual(
            operation["operationId"] as? String,
            "ColorMatchingWeb.CaptureController.upload_judgments"
        )
        let bodySchema = try requestBodySchema(spec, operation: operation)
        XCTAssertEqual(bodySchema["title"] as? String, "JudgmentUploadRequest")
        let accepted = try responseSchema(spec, operation: operation, status: "200")
        XCTAssertEqual(accepted["title"] as? String, "JudgmentUploadResponse")
    }

    func testManifestSchemaPinsCompatibilityVersions() throws {
        let spec = try loadSpec()
        let manifest = try componentSchema(spec, name: "TestSheetManifest")
        XCTAssertEqual(try requiredFields(manifest), ["schema_version", "sheet_id", "capture_profile"])
        let manifestProperties = try properties(manifest)
        let schemaVersion = try XCTUnwrap(manifestProperties["schema_version"] as? [String: Any])
        XCTAssertEqual(schemaVersion["enum"] as? [String], ["lps-sheet-manifest/v1"])
        let captureProfile = try resolve(try XCTUnwrap(manifestProperties["capture_profile"] as? [String: Any]), in: spec)
        let scoring = try XCTUnwrap(try properties(captureProfile)["scoring_algorithm_version"] as? [String: Any])
        XCTAssertEqual(scoring["enum"] as? [String], ["lps-distance-v1"])
    }

    func testCaptureRequestAcceptsNestedMetadataAndQualityShape() throws {
        let spec = try loadSpec()
        let captureRequest = try componentSchema(spec, name: "CaptureRequest")
        let captureProperties = try properties(captureRequest)
        let metadata = try resolve(try XCTUnwrap(captureProperties["metadata"] as? [String: Any]), in: spec)
        XCTAssertEqual(metadata["title"] as? String, "CaptureMetadata")
        XCTAssertEqual(
            try requiredFields(metadata),
            ["device_model", "lens", "image_width", "image_height", "app_version", "timestamp"]
        )
        let quality = try XCTUnwrap(captureProperties["quality"] as? [String: Any])
        let qualityProperties = try properties(quality)
        XCTAssertNotNil(qualityProperties["detected_marker_count"])
        XCTAssertNotNil(qualityProperties["blur_score"])
        XCTAssertNotNil(qualityProperties["rejections"])
    }

    func testMeasurementUploadSchemaMatchesAppPayloadShape() throws {
        let spec = try loadSpec()
        let upload = try componentSchema(spec, name: "MeasurementUploadRequest")
        let uploadProperties = try properties(upload)
        let measurements = try XCTUnwrap(uploadProperties["measurements"] as? [String: Any])
        let items = try XCTUnwrap(measurements["items"] as? [String: Any])
        XCTAssertEqual(try requiredFields(items), ["patch_id", "linear_rgb_median", "normalized_linear_rgb_median"])
        let itemProperties = try properties(items)
        let median = try XCTUnwrap(itemProperties["linear_rgb_median"] as? [String: Any])
        let resolvedMedian = try resolve(median, in: spec)
        XCTAssertEqual(resolvedMedian["title"] as? String, "RgbPayload")
        let pairScores = try resolve(try XCTUnwrap(uploadProperties["pair_scores"] as? [String: Any]), in: spec)
        let pairScoreItems = try XCTUnwrap(pairScores["items"] as? [String: Any])
        XCTAssertEqual(pairScoreItems["$ref"] as? String, "#/components/schemas/PairScoreRequest")
    }

    func testRgbPayloadAndPairScoreSchemasSupportAppShapes() throws {
        let spec = try loadSpec()
        let rgbPayload = try componentSchema(spec, name: "RgbPayload")
        let variants = try XCTUnwrap(rgbPayload["anyOf"] as? [[String: Any]])
        let objectVariant = try XCTUnwrap(variants.first { ($0["type"] as? String) == "object" })
        XCTAssertEqual(try requiredFields(objectVariant), ["r", "g", "b"])
        let pairScore = try componentSchema(spec, name: "PairScoreRequest")
        XCTAssertEqual(try requiredFields(pairScore), ["pair_id", "algorithm_version"])
        let pairProperties = try properties(pairScore)
        XCTAssertNotNil(pairProperties["similarity"])
        XCTAssertNotNil(pairProperties["distance"])
    }

    func testUploadResponsesReturnJSONBodiesWithCounts() throws {
        let spec = try loadSpec()
        let measurements = try componentSchema(spec, name: "MeasurementUploadResponse")
        XCTAssertEqual(try requiredFields(measurements), ["capture_id", "measurement_count", "pair_score_count"])
        let judgments = try componentSchema(spec, name: "JudgmentUploadResponse")
        XCTAssertEqual(try requiredFields(judgments), ["capture_id", "judgment_count"])
    }
}
