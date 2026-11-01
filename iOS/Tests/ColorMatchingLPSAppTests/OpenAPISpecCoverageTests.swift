import XCTest

final class OpenAPISpecCoverageTests: XCTestCase {
    private static let expectedOperations: [(method: String, path: String, operationID: String, statuses: [String])] = [
        ("get", "/api/v1/test_sheets/recent", "listRecentTestSheets", ["200", "401"]),
        ("get", "/api/v1/test_sheets/{sheet_id}/manifest", "getTestSheetManifest", ["200", "401", "404"]),
        ("get", "/api/v1/test_sheets/{sheet_id}/ranked_results", "getRankedResults", ["200", "401", "404"]),
        ("post", "/api/v1/test_sheets/{sheet_id}/captures", "createCapture", ["201", "401", "404", "422"]),
        ("post", "/api/v1/captures/{capture_id}/measurements", "uploadMeasurements", ["200", "401", "404", "422"]),
        ("post", "/api/v1/captures/{capture_id}/judgments", "uploadJudgments", ["200", "401", "404", "422"])
    ]

    func testVendoredOpenAPIDocumentExistsAndParses() throws {
        let url = TestRepoLayout.vendoredSpecURL
        guard FileManager.default.fileExists(atPath: url.path) else {
            XCTFail("Vendored OpenAPI document missing at \(url.path). Fetch it from viamin/color_matching GET /api/v1/openapi.json (issue #110) and commit it with the documented extensions from docs/openapi-client-migration.md.")
            return
        }
        let document = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        XCTAssertNotNil(document["openapi"], "vendored document must declare its OpenAPI version")
        XCTAssertNotNil(document["paths"])
        XCTAssertNotNil(document["components"])
    }

    func testVendoredDocumentCoversEveryAppSurface() throws {
        let document = try XCTUnwrap(Self.loadVendoredDocument())
        let paths = try XCTUnwrap(document["paths"] as? [String: Any])

        for expected in Self.expectedOperations {
            let pathItem = try XCTUnwrap(paths[expected.path] as? [String: Any], "vendored document is missing path \(expected.path)")
            let operation = try XCTUnwrap(pathItem[expected.method] as? [String: Any], "vendored document is missing \(expected.method.uppercased()) \(expected.path)")
            XCTAssertEqual(operation["operationId"] as? String, expected.operationID)
            let responses = try XCTUnwrap(operation["responses"] as? [String: Any])
            for status in expected.statuses {
                XCTAssertNotNil(responses[status], "\(expected.method.uppercased()) \(expected.path) must document status \(status)")
            }
        }

        let unexpectedPaths = Set(paths.keys).subtracting(Self.expectedOperations.map(\.path)).filter { $0.hasPrefix("/api/v1") }
        XCTAssertTrue(unexpectedPaths.isEmpty, "unexpected /api/v1 paths in vendored document: \(unexpectedPaths)")
    }

    func testVendoredDocumentRequiresBearerAuth() throws {
        let document = try XCTUnwrap(Self.loadVendoredDocument())
        let components = try XCTUnwrap(document["components"] as? [String: Any])
        let schemes = try XCTUnwrap(components["securitySchemes"] as? [String: Any])
        let bearer = try XCTUnwrap(schemes["bearerAuth"] as? [String: Any])
        XCTAssertEqual(bearer["type"] as? String, "http")
        XCTAssertEqual(bearer["scheme"] as? String, "bearer")
    }

    func testVendoredDocumentDeclaresFullManifestComponent() throws {
        let schemas = try Self.loadVendoredSchemas()
        let manifest = try XCTUnwrap(schemas["TestSheetManifest"] as? [String: Any])
        let properties = try XCTUnwrap(manifest["properties"] as? [String: Any])

        for key in ["schema_version", "sheet_id", "sheet_version", "manifest_url", "created_at", "page", "registration_markers", "printer_profile", "capture_profile", "patches", "pairs"] {
            XCTAssertNotNil(properties[key], "TestSheetManifest must declare \(key) (upstream spec under-documents the manifest; see docs/openapi-client-migration.md)")
        }

        let schemaVersion = try XCTUnwrap(properties["schema_version"] as? [String: Any])
        XCTAssertTrue((schemaVersion["enum"] as? [String])?.contains("lps-sheet-manifest/v1") == true)

        let captureProfile = try XCTUnwrap(Self.resolve(properties["capture_profile"], schemas: schemas))
        let captureProfileProperties = try XCTUnwrap(captureProfile["properties"] as? [String: Any])
        let scoring = try XCTUnwrap(captureProfileProperties["scoring_algorithm_version"] as? [String: Any])
        XCTAssertTrue((scoring["enum"] as? [String])?.contains("lps-distance-v1") == true)
    }

    func testVendoredDocumentDeclaresRankedResultsComponent() throws {
        let schemas = try Self.loadVendoredSchemas()
        let ranked = try XCTUnwrap(schemas["RankedResults"] as? [String: Any])
        let properties = try XCTUnwrap(ranked["properties"] as? [String: Any])

        for key in ["schema_version", "sheet_id", "printer_profile", "capture_count", "latest_capture_at", "earliest_capture_at", "scoring_algorithm_versions", "results"] {
            XCTAssertNotNil(properties[key], "RankedResults must declare \(key) (upstream spec under-documents ranked results; see docs/openapi-client-migration.md)")
        }

        let schemaVersion = try XCTUnwrap(properties["schema_version"] as? [String: Any])
        XCTAssertTrue((schemaVersion["enum"] as? [String])?.contains("lps-ranked-results/v1") == true)

        let results = try XCTUnwrap(Self.resolve(properties["results"], schemas: schemas))
        let items = try XCTUnwrap(Self.resolve(results["items"], schemas: schemas))
        let itemProperties = try XCTUnwrap(items["properties"] as? [String: Any])
        for key in ["rank", "pair_id", "source_colors", "score", "current_judgment", "observation_count"] {
            XCTAssertNotNil(itemProperties[key], "ranked result items must declare \(key)")
        }
    }

    func testVendoredDocumentDeclaresMeasurementStatsPayload() throws {
        let schemas = try Self.loadVendoredSchemas()
        let upload = try XCTUnwrap(schemas["MeasurementUploadRequest"] as? [String: Any])
        let properties = try XCTUnwrap(upload["properties"] as? [String: Any])
        let measurements = try XCTUnwrap(Self.resolve(properties["measurements"], schemas: schemas))
        let items = try XCTUnwrap(Self.resolve(measurements["items"], schemas: schemas))
        let itemProperties = try XCTUnwrap(items["properties"] as? [String: Any])

        for key in ["patch_id", "linear_rgb_median", "normalized_linear_rgb_median", "stats"] {
            XCTAssertNotNil(itemProperties[key], "measurement items must declare \(key); the app uploads stats and the upstream spec does not declare them")
        }
        let required = (items["required"] as? [String]) ?? []
        XCTAssertTrue(required.contains("normalized_linear_rgb_median"), "upstream spec requires normalized_linear_rgb_median on every measurement")

        XCTAssertNotNil(properties["pair_scores"], "MeasurementUploadRequest must declare pair_scores")
        let pairScores = try XCTUnwrap(Self.resolve(properties["pair_scores"], schemas: schemas))
        let scoreItems = try XCTUnwrap(Self.resolve(pairScores["items"], schemas: schemas))
        let scoreProperties = try XCTUnwrap(scoreItems["properties"] as? [String: Any])
        for key in ["pair_id", "algorithm_version", "similarity", "distance"] {
            XCTAssertNotNil(scoreProperties[key], "pair score items must declare \(key)")
        }
    }

    func testVendoredDocumentDeclaresSharedComponentsForAllAppSurfaces() throws {
        let schemas = try Self.loadVendoredSchemas()
        for name in [
            "TestSheetManifest", "RecentSheetsResponse", "RankedResults",
            "CaptureRequest", "CaptureMetadata", "CaptureQuality", "CaptureCreatedResponse",
            "MeasurementUploadRequest", "MeasurementUploadResponse",
            "JudgmentUploadRequest", "JudgmentUploadResponse", "ApiErrorResponse"
        ] {
            XCTAssertNotNil(schemas[name], "vendored document must declare component schema \(name)")
        }
    }

    func testPackageDeclaresOpenAPIGeneratorAndRuntime() throws {
        let manifestURL = TestRepoLayout.packageRelative("Package.swift")
        let manifest = try String(contentsOf: manifestURL, encoding: .utf8)

        XCTAssertTrue(manifest.contains("https://github.com/apple/swift-openapi-generator"), "Package.swift must depend on apple/swift-openapi-generator")
        XCTAssertTrue(manifest.contains("OpenAPIGenerator"), "the ColorMatchingAPI target must apply the OpenAPIGenerator build plugin")
        XCTAssertTrue(manifest.contains("https://github.com/apple/swift-openapi-runtime"), "Package.swift must depend on apple/swift-openapi-runtime")
        XCTAssertTrue(manifest.contains("OpenAPIURLSession"), "Package.swift must depend on apple/swift-openapi-urlsession for URLSessionTransport")
        XCTAssertTrue(manifest.contains("ColorMatchingAPI"), "Package.swift must declare the ColorMatchingAPI target that vendors openapi.json")
        XCTAssertTrue(manifest.contains("ColorMatchingLPSAppCore"), "the app core target must keep compiling against the generated client target")
    }

    private static func loadVendoredDocument() throws -> [String: Any]? {
        let url = TestRepoLayout.vendoredSpecURL
        guard FileManager.default.fileExists(atPath: url.path) else {
            XCTFail("Vendored OpenAPI document missing at \(url.path)")
            return nil
        }
        return try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
    }

    private static func loadVendoredSchemas() throws -> [String: Any] {
        let document = try XCTUnwrap(loadVendoredDocument())
        let components = try XCTUnwrap(document["components"] as? [String: Any])
        return try XCTUnwrap(components["schemas"] as? [String: Any])
    }

    private static func resolve(_ schema: Any?, schemas: [String: Any]) -> [String: Any]? {
        guard let schema = schema as? [String: Any] else { return nil }
        guard let reference = schema["$ref"] as? String else { return schema }
        let name = reference.replacingOccurrences(of: "#/components/schemas/", with: "")
        return schemas[name] as? [String: Any]
    }
}
