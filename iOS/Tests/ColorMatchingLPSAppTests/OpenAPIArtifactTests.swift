import Foundation
import XCTest

final class OpenAPIArtifactTests: XCTestCase {
    private static let iOSRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    private static var vendoredSpecURL: URL { iOSRoot.appendingPathComponent("OpenAPI/color-matching-openapi.json") }
    private static var packageManifestURL: URL { iOSRoot.appendingPathComponent("Package.swift") }

    func testVendoredOpenAPIDocumentExists() throws {
        let url = Self.vendoredSpecURL
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: url.path),
            "Expected the OpenAPI document published by viamin/color_matching#110 to be vendored at \(url.path)"
        )
        _ = try loadVendoredSpec()
    }

    func testVendoredDocumentIsOpenAPI3() throws {
        let spec = try loadVendoredSpec()
        let version = try XCTUnwrap(spec["openapi"] as? String, "vendored spec must declare its `openapi` version")
        XCTAssertTrue(version.hasPrefix("3."), "expected OpenAPI 3.x, found \(version)")
    }

    func testVendoredSpecCoversSurfacesAppUses() throws {
        let spec = try loadVendoredSpec()
        let paths = try XCTUnwrap(spec["paths"] as? [String: Any])

        let expectedOperations: [(path: String, method: String, operationID: String)] = [
            ("/api/v1/test_sheets/recent", "get", "getRecentSheets"),
            ("/api/v1/test_sheets/{sheet_id}/manifest", "get", "getManifest"),
            ("/api/v1/test_sheets/{sheet_id}/ranked_results", "get", "getRankedResults"),
            ("/api/v1/test_sheets/{sheet_id}/captures", "post", "createCapture"),
            ("/api/v1/captures/{capture_id}/measurements", "post", "uploadMeasurements"),
            ("/api/v1/captures/{capture_id}/judgments", "post", "uploadJudgments")
        ]

        for expected in expectedOperations {
            let pathItem = try XCTUnwrap(
                paths[expected.path] as? [String: Any],
                "vendored spec is missing path \(expected.path)"
            )
            let operation = try XCTUnwrap(
                pathItem[expected.method] as? [String: Any],
                "vendored spec is missing \(expected.method.uppercased()) \(expected.path)"
            )
            let operationID = try XCTUnwrap(operation["operationId"] as? String)
            XCTAssertEqual(
                operationID,
                expected.operationID,
                "\(expected.method.uppercased()) \(expected.path) must use the pinned client-facing operationId"
            )
        }
    }

    func testVendoredSpecSecuresAppOperationsWithBearerScheme() throws {
        let spec = try loadVendoredSpec()
        let components = try XCTUnwrap(spec["components"] as? [String: Any])
        let securitySchemes = try XCTUnwrap(components["securitySchemes"] as? [String: Any])
        let bearer = try XCTUnwrap(securitySchemes["bearerAuth"] as? [String: Any])
        XCTAssertEqual(bearer["type"] as? String, "http")
        XCTAssertEqual(bearer["scheme"] as? String, "bearer")

        for path in appOperationPaths {
            let pathOperation = try operation(path)
            let security = try XCTUnwrap(
                pathOperation["security"] as? [[String: Any]],
                "\(path) must declare its security requirements"
            )
            XCTAssertTrue(
                security.contains { $0["bearerAuth"] != nil },
                "\(path) must be reachable with the bearerAuth scheme"
            )
        }
    }

    func testVendoredManifestSchemaCoversRenderedManifest() throws {
        let manifest = try schema("TestSheetManifest")

        let renderedTopLevelKeys = [
            "schema_version", "sheet_id", "sheet_version", "manifest_url", "created_at",
            "page", "registration_markers", "printer_profile", "capture_profile",
            "patches", "pairs"
        ]
        let properties = try XCTUnwrap(manifest["properties"] as? [String: Any])
        let required = try XCTUnwrap(manifest["required"] as? [String])

        for key in renderedTopLevelKeys {
            XCTAssertTrue(properties[key] != nil, "manifest schema must declare \(key)")
            XCTAssertTrue(required.contains(key), "manifest schema must require \(key)")
        }

        XCTAssertEqual(required.count, renderedTopLevelKeys.count)

        let schemaVersion = try XCTUnwrap(properties["schema_version"] as? [String: Any])
        XCTAssertTrue((schemaVersion["enum"] as? [String])?.contains("lps-sheet-manifest/v1") == true)

        let captureProfile = try XCTUnwrap(properties["capture_profile"] as? [String: Any])
        let captureProfileProperties = try XCTUnwrap(captureProfile["properties"] as? [String: Any])
        let scoringVersion = try XCTUnwrap(captureProfileProperties["scoring_algorithm_version"] as? [String: Any])
        XCTAssertTrue((scoringVersion["enum"] as? [String])?.contains("lps-distance-v1") == true)
    }

    func testVendoredSpecDeclaresUploadResponseBodies() throws {
        let measurementResponse = try schema("MeasurementUploadResponse")
        XCTAssertEqual(
            try requiredProperties(measurementResponse),
            ["capture_id", "measurement_count", "pair_score_count"]
        )

        let judgmentResponse = try schema("JudgmentUploadResponse")
        XCTAssertEqual(
            try requiredProperties(judgmentResponse),
            ["capture_id", "judgment_count"]
        )

        let createdResponse = try schema("CaptureCreatedResponse")
        XCTAssertEqual(try requiredProperties(createdResponse), ["capture_id"])

        let measurementUpload = try operation("/api/v1/captures/{capture_id}/measurements")
        let measurementJSON = try jsonResponseSchema(measurementUpload, status: "200")
        XCTAssertEqual(
            try schemaReference(measurementJSON),
            "#/components/schemas/MeasurementUploadResponse",
            "measurement upload must document its 200 JSON body"
        )

        let judgmentUpload = try operation("/api/v1/captures/{capture_id}/judgments")
        let judgmentJSON = try jsonResponseSchema(judgmentUpload, status: "200")
        XCTAssertEqual(
            try schemaReference(judgmentJSON),
            "#/components/schemas/JudgmentUploadResponse",
            "judgment upload must document its 200 JSON body"
        )

        let createCapture = try operation("/api/v1/test_sheets/{sheet_id}/captures")
        let createdJSON = try jsonResponseSchema(createCapture, status: "201")
        XCTAssertEqual(try schemaReference(createdJSON), "#/components/schemas/CaptureCreatedResponse")
    }

    func testVendoredSpecNamesReusableRequestPayloadSchemas() throws {
        let measurementPayload = try schema("MeasurementPayload")
        XCTAssertEqual(
            Set(try requiredProperties(measurementPayload)),
            ["patch_id", "linear_rgb_median", "normalized_linear_rgb_median"]
        )
        let measurementProperties = try XCTUnwrap(measurementPayload["properties"] as? [String: Any])
        XCTAssertEqual(try schemaReference(XCTUnwrap(measurementProperties["linear_rgb_median"] as? [String: Any])), "#/components/schemas/RgbPayload")

        let measurementUpload = try schema("MeasurementUploadRequest")
        let measurementProperties2 = try XCTUnwrap(measurementUpload["properties"] as? [String: Any])
        let measurements = try XCTUnwrap(measurementProperties2["measurements"] as? [String: Any])
        let measurementItems = try XCTUnwrap(measurements["items"] as? [String: Any])
        XCTAssertEqual(
            try schemaReference(measurementItems),
            "#/components/schemas/MeasurementPayload",
            "measurement items must be a named component schema so generated types are addressable"
        )

        let judgmentPayload = try schema("JudgmentPayload")
        XCTAssertEqual(Set(try requiredProperties(judgmentPayload)), ["pair_id", "judgment"])

        let judgmentUpload = try schema("JudgmentUploadRequest")
        let judgmentProperties = try XCTUnwrap(judgmentUpload["properties"] as? [String: Any])
        let judgments = try XCTUnwrap(judgmentProperties["judgments"] as? [String: Any])
        let judgmentItems = try XCTUnwrap(judgments["items"] as? [String: Any])
        XCTAssertEqual(
            try schemaReference(judgmentItems),
            "#/components/schemas/JudgmentPayload",
            "judgment items must be a named component schema so generated types are addressable"
        )
    }

    func testVendoredSpecDeclaresAppPayloadSchemas() throws {
        let expectedSchemaTitles = [
            "TestSheetManifest",
            "RecentSheetsResponse",
            "CaptureMetadata",
            "CaptureRequest",
            "CaptureCreatedResponse",
            "RgbPayload",
            "PairScoreRequest",
            "MeasurementUploadRequest",
            "MeasurementUploadResponse",
            "JudgmentUploadRequest",
            "JudgmentUploadResponse",
            "RankedResults",
            "ApiErrorResponse"
        ]
        let schemas = try componentSchemas()
        for title in expectedSchemaTitles {
            XCTAssertTrue(schemas[title] != nil, "vendored spec must declare components.schemas.\(title)")
        }

        let rankedResults = try schema("RankedResults")
        XCTAssertEqual(Set(try requiredProperties(rankedResults)), ["schema_version", "sheet_id"])
        let rankedProperties = try XCTUnwrap(rankedResults["properties"] as? [String: Any])
        XCTAssertTrue((rankedProperties["schema_version"] as? [String: Any])?["enum"] as? [String] == ["lps-ranked-results/v1"])

        let captureMetadata = try schema("CaptureMetadata")
        let metadataProperties = try XCTUnwrap(captureMetadata["properties"] as? [String: Any])
        XCTAssertEqual(
            Set(try requiredProperties(captureMetadata)),
            ["device_model", "lens", "image_width", "image_height", "app_version", "timestamp"]
        )
        XCTAssertEqual((metadataProperties["iso"] as? [String: Any])?["type"] as? String, "integer")
        XCTAssertEqual((metadataProperties["timestamp"] as? [String: Any])?["format"] as? String, "date-time")

        let pairScore = try schema("PairScoreRequest")
        XCTAssertEqual(Set(try requiredProperties(pairScore)), ["pair_id", "algorithm_version"])
        XCTAssertTrue(((pairScore["anyOf"] as? [[String: Any]])?.count ?? 0) == 3)

        let rgbPayload = try schema("RgbPayload")
        XCTAssertTrue(((rgbPayload["anyOf"] as? [[String: Any]])?.count ?? 0) == 3)

        let captureRequest = try schema("CaptureRequest")
        let requestProperties = try XCTUnwrap(captureRequest["properties"] as? [String: Any])
        XCTAssertEqual(
            try schemaReference(XCTUnwrap(requestProperties["metadata"] as? [String: Any])),
            "#/components/schemas/CaptureMetadata"
        )
        XCTAssertTrue(requestProperties["quality"] != nil)
    }

    func testVendoredRecentSheetsSchemaKeepsNullableTitle() throws {
        let recentSheets = try schema("RecentSheetsResponse")
        let properties = try XCTUnwrap(recentSheets["properties"] as? [String: Any])
        let sheets = try XCTUnwrap(properties["sheets"] as? [String: Any])
        let item = try XCTUnwrap(sheets["items"] as? [String: Any])
        let itemProperties = try XCTUnwrap(item["properties"] as? [String: Any])
        let title = try XCTUnwrap(itemProperties["title"] as? [String: Any])
        XCTAssertEqual(title["nullable"] as? Bool, true)
        XCTAssertEqual(
            Set(try requiredProperties(item)),
            ["sheet_id", "manifest_url", "title"]
        )
    }

    func testPackageManifestWiresOpenAPIToolchain() throws {
        let manifest = try String(contentsOf: Self.packageManifestURL, encoding: .utf8)

        XCTAssertTrue(manifest.contains("apple/swift-openapi-generator"), "package must depend on swift-openapi-generator")
        XCTAssertTrue(manifest.contains("apple/swift-openapi-runtime"), "package must depend on swift-openapi-runtime")
        XCTAssertTrue(manifest.contains("name: \"OpenAPIGenerator\""), "package must declare the OpenAPIGenerator plugin product")
        XCTAssertTrue(manifest.contains("name: \"OpenAPIRuntime\""), "package must declare the OpenAPIRuntime product")
        XCTAssertTrue(
            manifest.contains("name: \"OpenAPIGeneratedCore\""),
            "package must declare the OpenAPIGeneratedCore generation target"
        )
        XCTAssertTrue(
            manifest.range(of: #"(?s)name:\s*"OpenAPIGeneratedCore".{0,400}?\.plugin\("#, options: .regularExpression) != nil,
            "the OpenAPIGenerator plugin must be applied to the OpenAPIGeneratedCore target"
        )
    }

    func testGeneratedTargetIsWiredIntoCoreAndTests() throws {
        let manifest = try String(contentsOf: Self.packageManifestURL, encoding: .utf8)

        let coreTarget = try XCTUnwrap(
            manifest.range(of: #"(?s)\.target\(\s*name:\s*"ColorMatchingLPSAppCore".*?\n\s*\)"#, options: .regularExpression),
            "package must keep the ColorMatchingLPSAppCore target"
        )
        XCTAssertTrue(
            manifest[coreTarget].contains("OpenAPIGeneratedCore"),
            "ColorMatchingLPSAppCore must depend on OpenAPIGeneratedCore so the hand-written API layer is replaced by generated types"
        )

        let testTarget = try XCTUnwrap(
            manifest.range(of: #"(?s)\.testTarget\(\s*name:\s*"ColorMatchingLPSAppTests".*?\n\s*\)"#, options: .regularExpression),
            "package must keep the ColorMatchingLPSAppTests target"
        )
        XCTAssertTrue(
            manifest[testTarget].contains("OpenAPIGeneratedCore"),
            "ColorMatchingLPSAppTests must depend on OpenAPIGeneratedCore so the generated-client contract tests compile"
        )
    }
}

private extension OpenAPIArtifactTests {
    var appOperationPaths: [String] {
        [
            "/api/v1/test_sheets/recent",
            "/api/v1/test_sheets/{sheet_id}/manifest",
            "/api/v1/test_sheets/{sheet_id}/ranked_results",
            "/api/v1/test_sheets/{sheet_id}/captures",
            "/api/v1/captures/{capture_id}/measurements",
            "/api/v1/captures/{capture_id}/judgments"
        ]
    }

    func loadVendoredSpec() throws -> [String: Any] {
        let data = try Data(contentsOf: Self.vendoredSpecURL)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    func operation(_ path: String, file: StaticString = #filePath, line: UInt = #line) throws -> [String: Any] {
        let spec = try loadVendoredSpec()
        let paths = try XCTUnwrap(spec["paths"] as? [String: Any], file: file, line: line)
        let pathItem = try XCTUnwrap(paths[path] as? [String: Any], file: file, line: line)
        let operation = (pathItem["get"] ?? pathItem["post"]) as? [String: Any]
        return try XCTUnwrap(operation, file: file, line: line)
    }

    func componentSchemas(file: StaticString = #filePath, line: UInt = #line) throws -> [String: Any] {
        let spec = try loadVendoredSpec()
        let components = try XCTUnwrap(spec["components"] as? [String: Any], file: file, line: line)
        return try XCTUnwrap(components["schemas"] as? [String: Any], file: file, line: line)
    }

    func schema(_ title: String, file: StaticString = #filePath, line: UInt = #line) throws -> [String: Any] {
        let schemas = try componentSchemas(file: file, line: line)
        return try XCTUnwrap(schemas[title] as? [String: Any], "missing components.schemas.\(title)", file: file, line: line)
    }

    func requiredProperties(_ schema: [String: Any], file: StaticString = #filePath, line: UInt = #line) throws -> [String] {
        try XCTUnwrap(schema["required"] as? [String], file: file, line: line)
    }

    func jsonResponseSchema(_ operation: [String: Any], status: String, file: StaticString = #filePath, line: UInt = #line) throws -> [String: Any] {
        let responses = try XCTUnwrap(operation["responses"] as? [String: Any], file: file, line: line)
        let response = try XCTUnwrap(responses[status] as? [String: Any], file: file, line: line)
        let content = try XCTUnwrap(response["content"] as? [String: Any], file: file, line: line)
        return try XCTUnwrap(content["application/json"] as? [String: Any], file: file, line: line)
    }

    func schemaReference(_ schema: [String: Any], file: StaticString = #filePath, line: UInt = #line) throws -> String {
        try XCTUnwrap(schema["$ref"] as? String, file: file, line: line)
    }
}
