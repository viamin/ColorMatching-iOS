import Foundation
import XCTest

/// Structural verification for issue #5: the Swift package must wire in
/// `swift-openapi-generator` + `swift-openapi-runtime`, vendor the OpenAPI
/// document published by viamin/color_matching#110, and cover every API
/// surface the app uses today.
///
/// These tests are intentionally red until the generated client lands; see
/// `docs/openapi-generated-client.md` for the implementation contract they
/// pin.
final class OpenAPISpecCoverageTests: XCTestCase {
    // MARK: - Package manifest

    func testPackageManifestWiresGeneratorRuntimeAndGeneratedTarget() throws {
        let manifest = try String(contentsOf: Self.packageManifestURL, encoding: .utf8)

        XCTAssertTrue(
            manifest.contains("https://github.com/apple/swift-openapi-generator"),
            "iOS/Package.swift must depend on apple/swift-openapi-generator (issue #5)"
        )
        XCTAssertTrue(
            manifest.contains("https://github.com/apple/swift-openapi-runtime"),
            "iOS/Package.swift must depend on apple/swift-openapi-runtime (issue #5)"
        )
        XCTAssertTrue(
            manifest.contains("OpenAPIGenerator"),
            "iOS/Package.swift must apply the OpenAPIGenerator build plugin to the generated target"
        )
        XCTAssertTrue(
            manifest.contains("ColorMatchingOpenAPI"),
            "iOS/Package.swift must declare the generated target 'ColorMatchingOpenAPI' and link it"
        )
    }

    func testPackageManifestLinksGeneratedClientIntoAppCoreAndTests() throws {
        let manifest = try String(contentsOf: Self.packageManifestURL, encoding: .utf8)

        let generated = try Self.targetBlock(named: "ColorMatchingOpenAPI", in: manifest)
        XCTAssertTrue(
            generated.contains("OpenAPIGenerator"),
            "the ColorMatchingOpenAPI target must apply the OpenAPIGenerator plugin"
        )
        XCTAssertTrue(
            generated.contains("OpenAPIRuntime"),
            "the ColorMatchingOpenAPI target must depend on the OpenAPIRuntime product"
        )

        let appCore = try Self.targetBlock(named: "ColorMatchingLPSAppCore", in: manifest)
        XCTAssertTrue(
            appCore.contains("ColorMatchingOpenAPI"),
            "ColorMatchingLPSAppCore must depend on the generated target (issue #5)"
        )
        XCTAssertTrue(
            appCore.contains("OpenAPIRuntime"),
            "ColorMatchingLPSAppCore must depend on OpenAPIRuntime: the bearer middleware lives there"
        )

        let tests = try Self.targetBlock(named: "ColorMatchingLPSAppTests", in: manifest)
        XCTAssertTrue(
            tests.contains("ColorMatchingOpenAPI"),
            "the test target must depend on the generated target so the generated client can be exercised"
        )
        XCTAssertTrue(
            tests.contains("OpenAPIRuntime"),
            "the test target must depend on OpenAPIRuntime so the stub transport can be injected"
        )
    }

    // MARK: - Generator configuration

    func testGeneratorConfigurationUsesIdiomaticNamingAndPublicAccess() throws {
        let url = Self.generatorConfigURL
        guard FileManager.default.fileExists(atPath: url.path) else {
            XCTFail(
                """
                Missing generator configuration at \(url.path).
                The OpenAPIGenerator build plugin reads 'openapi-generator-config.yaml' from \
                the generated target's sources; it must select the idiomatic naming strategy \
                (the upstream operationIds contain dots, e.g. \
                'ColorMatchingWeb.TestSheetController.manifest') and the public access modifier \
                (the app and the tests consume the generated types across module boundaries).
                """
            )
            return
        }

        let config = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(
            config.contains("namingStrategy") && config.contains("idiomatic"),
            "the generator must use the idiomatic naming strategy; the default defensive strategy \
            would generate 'ColorMatchingWeb_period_TestSheetController_period_manifest' and \
            'sheet_id' style identifiers"
        )
        XCTAssertTrue(
            config.contains("accessModifier") && config.contains("public"),
            "the generator must emit public declarations so other modules can use the client"
        )
        XCTAssertTrue(
            config.contains("types"),
            "the generator must produce the types file (Components.Schemas.*)"
        )
        XCTAssertTrue(
            config.contains("client"),
            "the generator must produce the client file (Client, Operations.*)"
        )
    }

    // MARK: - Vendored document

    func testVendoredSpecExistsAndDeclaresOpenAPI3() throws {
        let spec = try Self.loadVendoredSpec()

        let version = try XCTUnwrap(spec["openapi"] as? String, "vendored spec must declare its OpenAPI version")
        XCTAssertTrue(version.hasPrefix("3."), "expected OpenAPI 3.x, got \(version)")
    }

    func testVendoredSpecCoversEveryAppSurface() throws {
        let spec = try Self.loadVendoredSpec()
        let paths = try Self.paths(inSpec: spec)

        let manifest = try Self.operation("get", "/api/v1/test_sheets/{sheet_id}/manifest", inPaths: paths)
        XCTAssertEqual(manifest["operationId"] as? String, "ColorMatchingWeb.TestSheetController.manifest")
        try Self.assertDeclaresPathParameter("sheet_id", inOperation: manifest)

        let recent = try Self.operation("get", "/api/v1/test_sheets/recent", inPaths: paths)
        XCTAssertEqual(recent["operationId"] as? String, "ColorMatchingWeb.TestSheetController.recent")

        let ranked = try Self.operation("get", "/api/v1/test_sheets/{sheet_id}/ranked_results", inPaths: paths)
        XCTAssertEqual(ranked["operationId"] as? String, "ColorMatchingWeb.TestSheetController.ranked_results")
        try Self.assertDeclaresPathParameter("sheet_id", inOperation: ranked)

        let create = try Self.operation("post", "/api/v1/test_sheets/{sheet_id}/captures", inPaths: paths)
        XCTAssertEqual(create["operationId"] as? String, "ColorMatchingWeb.CaptureController.create")
        try Self.assertDeclaresPathParameter("sheet_id", inOperation: create)

        let measurements = try Self.operation("post", "/api/v1/captures/{capture_id}/measurements", inPaths: paths)
        XCTAssertEqual(
            measurements["operationId"] as? String,
            "ColorMatchingWeb.CaptureController.upload_measurements"
        )
        try Self.assertDeclaresPathParameter("capture_id", inOperation: measurements)

        let judgments = try Self.operation("post", "/api/v1/captures/{capture_id}/judgments", inPaths: paths)
        XCTAssertEqual(
            judgments["operationId"] as? String,
            "ColorMatchingWeb.CaptureController.upload_judgments"
        )
        try Self.assertDeclaresPathParameter("capture_id", inOperation: judgments)
    }

    func testVendoredSpecDeclaresResponseStatusesPerSurface() throws {
        let spec = try Self.loadVendoredSpec()
        let paths = try Self.paths(inSpec: spec)

        try Self.assertResponseStatuses(["200", "401", "404"], method: "get", path: "/api/v1/test_sheets/{sheet_id}/manifest", inPaths: paths)
        try Self.assertResponseStatuses(["200", "401"], method: "get", path: "/api/v1/test_sheets/recent", inPaths: paths)
        try Self.assertResponseStatuses(["200", "401", "404"], method: "get", path: "/api/v1/test_sheets/{sheet_id}/ranked_results", inPaths: paths)
        try Self.assertResponseStatuses(["201", "401", "404", "422"], method: "post", path: "/api/v1/test_sheets/{sheet_id}/captures", inPaths: paths)
        try Self.assertResponseStatuses(["200", "401", "404", "422"], method: "post", path: "/api/v1/captures/{capture_id}/measurements", inPaths: paths)
        try Self.assertResponseStatuses(["200", "401", "404", "422"], method: "post", path: "/api/v1/captures/{capture_id}/judgments", inPaths: paths)
    }

    func testVendoredSpecDeclaresBearerAuthAndRequiresItOnEveryAppSurface() throws {
        let spec = try Self.loadVendoredSpec()

        let components = try XCTUnwrap(spec["components"] as? [String: Any])
        let schemes = try XCTUnwrap(components["securitySchemes"] as? [String: Any])
        let bearer = try XCTUnwrap(schemes["bearerAuth"] as? [String: Any])
        XCTAssertEqual(bearer["type"] as? String, "http")
        XCTAssertEqual(bearer["scheme"] as? String, "bearer")

        let paths = try Self.paths(inSpec: spec)
        for path in Self.appSurfacePaths {
            for method in ["get", "post"] {
                guard let operation = (paths[path] as? [String: Any])?[method] as? [String: Any] else { continue }
                let security = try XCTUnwrap(operation["security"] as? [[String: Any]], "\(method.uppercased()) \(path) must declare security")
                XCTAssertTrue(
                    security.contains { $0["bearerAuth"] != nil },
                    "\(method.uppercased()) \(path) must require bearerAuth"
                )
            }
        }
    }

    func testVendoredSpecPinsCompatibilityEnums() throws {
        let schemas = try Self.componentsSchemas()

        let manifestSchema = try XCTUnwrap(schemas["TestSheetManifest"] as? [String: Any])
        let manifestProperties = try XCTUnwrap(manifestSchema["properties"] as? [String: Any])
        let schemaVersion = try XCTUnwrap(manifestProperties["schema_version"] as? [String: Any])
        XCTAssertEqual(schemaVersion["enum"] as? [String], ["lps-sheet-manifest/v1"])
        XCTAssertTrue(
            (manifestSchema["required"] as? [String])?.contains("schema_version") == true,
            "schema_version must be required in TestSheetManifest"
        )
        XCTAssertTrue(
            (manifestSchema["required"] as? [String])?.contains("capture_profile") == true,
            "capture_profile must be required in TestSheetManifest"
        )

        let captureProfile = try XCTUnwrap(manifestProperties["capture_profile"] as? [String: Any])
        let scoring = try XCTUnwrap(
            (captureProfile["properties"] as? [String: Any])?["scoring_algorithm_version"] as? [String: Any]
        )
        XCTAssertEqual(scoring["enum"] as? [String], ["lps-distance-v1"])
        XCTAssertTrue(
            (captureProfile["required"] as? [String])?.contains("scoring_algorithm_version") == true,
            "scoring_algorithm_version must be required inside capture_profile"
        )

        let rankedSchema = try XCTUnwrap(schemas["RankedResults"] as? [String: Any])
        let rankedVersion = try XCTUnwrap(
            ((rankedSchema["properties"] as? [String: Any])?["schema_version"] as? [String: Any])?["enum"] as? [String]
        )
        XCTAssertEqual(rankedVersion, ["lps-ranked-results/v1"])
    }

    func testVendoredSpecDeclaresComponentSchemasForAppSurfaces() throws {
        let schemas = try Self.componentsSchemas()

        let expected = [
            "TestSheetManifest",
            "RankedResults",
            "RecentSheetsResponse",
            "CaptureMetadata",
            "CaptureRequest",
            "CaptureCreatedResponse",
            "MeasurementUploadRequest",
            "MeasurementUploadResponse",
            "JudgmentUploadRequest",
            "JudgmentUploadResponse",
            "PairScoreRequest",
            "RgbPayload",
            "ApiErrorResponse",
        ]
        let missing = expected.filter { schemas[$0] == nil }
        XCTAssertTrue(missing.isEmpty, "vendored spec is missing component schemas: \(missing)")
    }

    /// The generator parses the document with OpenAPIKit, which reads a schema
    /// that carries `anyOf` as a pure union and drops the sibling `properties`.
    /// `CaptureRequest` and `PairScoreRequest` therefore ship without `anyOf`
    /// so the generated types keep their fields; `RgbPayload` keeps its union
    /// because that is the one shape the generator expresses as an enum.
    func testVendoredSpecKeepsGeneratorCompatibleSchemaShapes() throws {
        let schemas = try Self.componentsSchemas()

        let captureRequest = try XCTUnwrap(schemas["CaptureRequest"] as? [String: Any])
        XCTAssertNil(
            captureRequest["anyOf"],
            "CaptureRequest must not carry `anyOf`: OpenAPIKit would drop the sibling `properties` \
            and the generated type would degrade to an enum without `metadata`/`quality`"
        )
        let captureProperties = try XCTUnwrap(captureRequest["properties"] as? [String: Any])
        XCTAssertNotNil(captureProperties["metadata"], "CaptureRequest must keep the nested `metadata` property")
        XCTAssertNotNil(captureProperties["quality"], "CaptureRequest must keep the nested `quality` property")

        let captureMetadata = try XCTUnwrap(schemas["CaptureMetadata"] as? [String: Any])
        XCTAssertEqual(
            Set(try XCTUnwrap(captureMetadata["required"] as? [String])),
            ["device_model", "lens", "image_width", "image_height", "app_version", "timestamp"]
        )

        let pairScore = try XCTUnwrap(schemas["PairScoreRequest"] as? [String: Any])
        XCTAssertNil(
            pairScore["anyOf"],
            "PairScoreRequest must not carry `anyOf`: the sibling `properties` would be dropped"
        )
        XCTAssertEqual(
            Set(try XCTUnwrap(pairScore["required"] as? [String])),
            ["pair_id", "algorithm_version"]
        )

        let rgbPayload = try XCTUnwrap(schemas["RgbPayload"] as? [String: Any])
        XCTAssertEqual(
            (rgbPayload["anyOf"] as? [Any])?.count,
            3,
            "RgbPayload must keep its three-branch union (array, {r,g,b} object, JSON string)"
        )

        let measurementRequest = try XCTUnwrap(schemas["MeasurementUploadRequest"] as? [String: Any])
        let measurementProperties = try XCTUnwrap(measurementRequest["properties"] as? [String: Any])
        XCTAssertNotNil(measurementProperties["measurements"], "MeasurementUploadRequest must keep `measurements`")
        XCTAssertNotNil(measurementProperties["pair_scores"], "MeasurementUploadRequest must keep `pair_scores`")

        let judgmentRequest = try XCTUnwrap(schemas["JudgmentUploadRequest"] as? [String: Any])
        XCTAssertEqual(
            Set(try XCTUnwrap(judgmentRequest["required"] as? [String])),
            ["judgments"]
        )
    }
}

// MARK: - Helpers

private extension OpenAPISpecCoverageTests {
    // iOS/Tests/ColorMatchingLPSAppTests/<this file> -> iOS/
    static var packageRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    static var packageManifestURL: URL { packageRoot.appending(path: "Package.swift") }

    /// The OpenAPIGenerator plugin only accepts a document named
    /// `openapi.json` (or `.yaml`/`.yml`) that lives inside the generated
    /// target's sources.
    static var vendoredSpecURL: URL {
        packageRoot.appending(path: "Sources/ColorMatchingOpenAPI/openapi.json")
    }

    static var generatorConfigURL: URL {
        packageRoot.appending(path: "Sources/ColorMatchingOpenAPI/openapi-generator-config.yaml")
    }

    static let appSurfacePaths = [
        "/api/v1/test_sheets/{sheet_id}/manifest",
        "/api/v1/test_sheets/recent",
        "/api/v1/test_sheets/{sheet_id}/ranked_results",
        "/api/v1/test_sheets/{sheet_id}/captures",
        "/api/v1/captures/{capture_id}/measurements",
        "/api/v1/captures/{capture_id}/judgments",
    ]

    /// Every target declared in this package; used to find where a target
    /// declaration ends inside `Package.swift`.
    static let packageTargetNames = [
        "MeasurementCore",
        "ColorMatchingLPSAppCore",
        "ColorMatchingLPSApp",
        "ColorMatchingOpenAPI",
        "MeasurementCoreTests",
        "ColorMatchingLPSAppTests",
    ]

    static func loadVendoredSpec() throws -> [String: Any] {
        let url = vendoredSpecURL
        guard FileManager.default.fileExists(atPath: url.path) else {
            XCTFail(
                """
                Vendored OpenAPI document missing at \(url.path).
                Fetch GET /api/v1/openapi.json from color_matching (viamin/color_matching#110) \
                and commit it next to the generated target as 'openapi.json'; see \
                docs/openapi-generated-client.md.
                """
            )
            return [:]
        }
        let object = try JSONSerialization.jsonObject(with: Data(contentsOf: url))
        return try XCTUnwrap(object as? [String: Any], "vendored spec must be a JSON object")
    }

    /// Returns the `Package.swift` text that belongs to a single target.
    static func targetBlock(named name: String, in manifest: String) throws -> String {
        let segments = manifest.components(separatedBy: "name: \"")
        let start = try XCTUnwrap(
            segments.firstIndex { $0.hasPrefix("\(name)\"") },
            "iOS/Package.swift must declare the target '\(name)'"
        )
        var block = segments[start]
        for segment in segments.dropFirst(start + 1) {
            let identifier = segment.components(separatedBy: "\"").first ?? ""
            if packageTargetNames.contains(identifier) { break }
            block += "name: \"" + segment
        }
        return block
    }

    static func paths(inSpec spec: [String: Any]) throws -> [String: Any] {
        try XCTUnwrap(spec["paths"] as? [String: Any], "vendored spec must declare paths")
    }

    static func componentsSchemas() throws -> [String: Any] {
        let spec = try loadVendoredSpec()
        let components = try XCTUnwrap(spec["components"] as? [String: Any])
        return try XCTUnwrap(components["schemas"] as? [String: Any], "vendored spec must declare components.schemas")
    }

    static func operation(_ method: String, _ path: String, inPaths paths: [String: Any]) throws -> [String: Any] {
        let pathItem = try XCTUnwrap(paths[path] as? [String: Any], "spec is missing path \(path)")
        return try XCTUnwrap(
            pathItem[method] as? [String: Any],
            "spec is missing \(method.uppercased()) \(path)"
        )
    }

    static func assertDeclaresPathParameter(_ name: String, inOperation operation: [String: Any]) throws {
        let parameters = try XCTUnwrap(operation["parameters"] as? [[String: Any]])
        XCTAssertTrue(
            parameters.contains {
                ($0["name"] as? String) == name && ($0["in"] as? String) == "path"
            },
            "operation must declare path parameter '\(name)'"
        )
    }

    static func assertResponseStatuses(
        _ expected: [String],
        method: String,
        path: String,
        inPaths paths: [String: Any]
    ) throws {
        let operation = try Self.operation(method, path, inPaths: paths)
        let responses = try XCTUnwrap(operation["responses"] as? [String: Any])
        XCTAssertEqual(
            Set(responses.keys),
            Set(expected),
            "\(method.uppercased()) \(path) response statuses drifted from the published spec"
        )
    }
}
