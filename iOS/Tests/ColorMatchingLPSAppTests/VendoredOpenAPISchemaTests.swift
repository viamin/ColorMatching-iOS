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

    func testManifestRequiredFieldsMatchUpstreamUnderSpecification() throws {
        let manifest = try Self.schema("TestSheetManifest")
        XCTAssertEqual(
            Set(try Self.required(of: manifest)),
            ["schema_version", "sheet_id", "capture_profile"],
            "Upstream only requires these manifest fields today. If this fails after a " +
                "regeneration, upstream expanded TestSheetManifest — refresh the vendored " +
                "document and move the geometry fields from client-side models to generated types."
        )
    }

    func testUploadResponsesDeclareJSONBodiesProseContractAssumedEmpty() throws {
        let measurement = try Self.schema("MeasurementUploadResponse")
        XCTAssertEqual(
            Set(try Self.required(of: measurement)),
            ["capture_id", "measurement_count", "pair_score_count"],
            "Measurement upload answers 200 with a count body, not the prose contract's empty 204"
        )
        let judgment = try Self.schema("JudgmentUploadResponse")
        XCTAssertEqual(
            Set(try Self.required(of: judgment)),
            ["capture_id", "judgment_count"],
            "Judgment upload answers 200 with a count body, not the prose contract's empty 204"
        )
    }

    func testCaptureRequestAcceptsNestedMetadataQualityShape() throws {
        let captureRequest = try Self.schema("CaptureRequest")
        let properties = try XCTUnwrap(captureRequest["properties"] as? [String: Any])
        XCTAssertNotNil(
            properties["metadata"],
            "CaptureRequest must keep the nested metadata property the app sends"
        )
        XCTAssertNotNil(
            properties["quality"],
            "CaptureRequest must keep the nested quality property the app sends"
        )
        let branches = try XCTUnwrap(captureRequest["anyOf"] as? [[String: Any]])
        XCTAssertTrue(
            branches.contains { Set(($0["required"] as? [String]) ?? []) == ["metadata"] },
            "CaptureRequest anyOf must accept the nested {metadata, quality} request shape"
        )
    }

    func testMeasurementItemsRequireNormalizedMedian() throws {
        let upload = try Self.schema("MeasurementUploadRequest")
        let properties = try XCTUnwrap(upload["properties"] as? [String: Any])
        let measurements = try XCTUnwrap(properties["measurements"] as? [String: Any])
        let items = try XCTUnwrap(measurements["items"] as? [String: Any])
        XCTAssertEqual(
            Set(try Self.required(of: items)),
            ["patch_id", "linear_rgb_median", "normalized_linear_rgb_median"],
            "normalized_linear_rgb_median is required per measurement (optional in the prose contract)"
        )
    }

    func testRgbPayloadAcceptsChannelObjectForm() throws {
        let rgb = try Self.schema("RgbPayload")
        let branches = try XCTUnwrap(rgb["anyOf"] as? [[String: Any]])
        XCTAssertTrue(
            branches.contains { Set(($0["required"] as? [String]) ?? []) == ["r", "g", "b"] },
            "RgbPayload anyOf must accept the {r, g, b} object form the app uploads"
        )
    }

    func testPairScoreItemsRequireAlgorithmVersionAndOneScoreKind() throws {
        let pairScore = try Self.schema("PairScoreRequest")
        XCTAssertEqual(
            Set(try Self.required(of: pairScore)),
            ["pair_id", "algorithm_version"],
            "Pair scores carry algorithm_version per item, not in a top-level scoring_algorithm_version"
        )
        let branches = try XCTUnwrap(pairScore["anyOf"] as? [[String: Any]])
        let offeredScoreKinds = branches.compactMap { $0["required"] as? [String] }.flatMap { $0 }
        for scoreKind in ["score", "similarity", "distance"] {
            XCTAssertTrue(
                offeredScoreKinds.contains(scoreKind),
                "PairScoreRequest must accept a \(scoreKind) value"
            )
        }
    }

    func testRecentSheetsTitleIsRequiredButNullable() throws {
        let recent = try Self.schema("RecentSheetsResponse")
        let properties = try XCTUnwrap(recent["properties"] as? [String: Any])
        let sheets = try XCTUnwrap(properties["sheets"] as? [String: Any])
        let items = try XCTUnwrap(sheets["items"] as? [String: Any])
        XCTAssertTrue(
            Set(try Self.required(of: items)).contains("title"),
            "Recent sheet items must declare title"
        )
        let itemProperties = try XCTUnwrap(items["properties"] as? [String: Any])
        let title = try XCTUnwrap(itemProperties["title"] as? [String: Any])
        XCTAssertEqual(
            title["nullable"] as? Bool,
            true,
            "title is required-but-nullable: sheets without display names send null"
        )
    }

    private static func required(of schema: [String: Any]) throws -> [String] {
        try XCTUnwrap(schema["required"] as? [String], "schema has no required list")
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
