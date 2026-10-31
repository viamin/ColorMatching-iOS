import XCTest

final class VendoredOpenAPISchemaTests: XCTestCase {
    private static let requiredSchemaTitles = [
        "TestSheetManifest",
        "RankedResults",
        "RecentSheetsResponse",
        "CaptureRequest",
        "CaptureCreatedResponse",
        "MeasurementUploadRequest",
        "MeasurementUploadResponse",
        "JudgmentUploadRequest",
        "JudgmentUploadResponse"
    ]

    func testSpecDefinesBearerAuthScheme() throws {
        let components = try Self.components()
        let schemes = try XCTUnwrap(components["securitySchemes"] as? [String: Any])
        let bearer = try XCTUnwrap(schemes["bearerAuth"] as? [String: Any])
        XCTAssertEqual(bearer["type"] as? String, "http")
        XCTAssertEqual(bearer["scheme"] as? String, "bearer")
    }

    func testSpecDefinesSchemasForAppPayloads() throws {
        let schemas = try Self.schemas()
        for title in Self.requiredSchemaTitles {
            XCTAssertNotNil(schemas[title], "vendored spec is missing schema \(title)")
        }
    }

    func testManifestSchemaPinsCompatibilityVersions() throws {
        let manifest = try Self.schema("TestSheetManifest")
        let properties = try XCTUnwrap(manifest["properties"] as? [String: Any])
        XCTAssertEqual(
            try Self.enumValues(of: properties["schema_version"]),
            ["lps-sheet-manifest/v1"]
        )
        let captureProfile = try XCTUnwrap(properties["capture_profile"] as? [String: Any])
        let captureProfileProperties = try XCTUnwrap(captureProfile["properties"] as? [String: Any])
        XCTAssertEqual(
            try Self.enumValues(of: captureProfileProperties["scoring_algorithm_version"]),
            ["lps-distance-v1"]
        )
    }

    func testRankedResultsSchemaDeclaresOwnVersion() throws {
        let rankedResults = try Self.schema("RankedResults")
        let properties = try XCTUnwrap(rankedResults["properties"] as? [String: Any])
        XCTAssertEqual(
            try Self.enumValues(of: properties["schema_version"]),
            ["lps-ranked-results/v1"]
        )
    }

    func testCaptureCreatedResponseRequiresCaptureID() throws {
        let response = try Self.schema("CaptureCreatedResponse")
        let properties = try XCTUnwrap(response["properties"] as? [String: Any])
        XCTAssertNotNil(properties["capture_id"])
        XCTAssertEqual(response["required"] as? [String], ["capture_id"])
    }

    private static func enumValues(of schema: Any?) throws -> [String] {
        let dictionary = try XCTUnwrap(schema as? [String: Any])
        return try XCTUnwrap(dictionary["enum"] as? [String])
    }

    private static func schema(_ title: String) throws -> [String: Any] {
        let schemas = try Self.schemas()
        return try XCTUnwrap(schemas[title] as? [String: Any], "missing schema \(title)")
    }

    private static func schemas() throws -> [String: Any] {
        let components = try Self.components()
        return try XCTUnwrap(components["schemas"] as? [String: Any])
    }

    private static func components() throws -> [String: Any] {
        try XCTUnwrap(spec()["components"] as? [String: Any])
    }

    private static func spec() throws -> [String: Any] {
        let packageRoot = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let document = try OpenAPIDocumentLocator.vendoredDocument(packageRoot: packageRoot)
        return try document.jsonObject()
    }
}
