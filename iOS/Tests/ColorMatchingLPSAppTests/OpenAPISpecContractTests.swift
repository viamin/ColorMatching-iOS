import Foundation
import XCTest

/// Contract tests for the OpenAPI document vendored from `viamin/color_matching`.
///
/// The canonical location is `iOS/Sources/OpenAPIGeneratedClient/openapi.json`,
/// a verbatim copy of `GET /api/v1/openapi.json` published by upstream issue
/// #110 / PR #113. These tests pin the surfaces the iOS companion uses so that
/// server-side drift shows up as a test failure here (and as a regeneration
/// diff), instead of a runtime surprise.
///
/// See `docs/openapi-client-generation.md` for the vendoring workflow and the
/// deltas found between the prose contract and the published spec.
final class OpenAPISpecContractTests: XCTestCase {
    private struct UnresolvedReference: Error { let ref: String }

    /// The `iOS/` package root, derived from this file's location so the tests
    /// work under both `swift test` and the Xcode project.
    private static var packageRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // ColorMatchingLPSAppTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // iOS
    }

    private static var specURL: URL {
        packageRoot.appending(path: "Sources/OpenAPIGeneratedClient/openapi.json")
    }

    private func loadedSpec() throws -> [String: Any] {
        let url = Self.specURL
        let data = try XCTUnwrap(
            try? Data(contentsOf: url),
            """
            Vendored OpenAPI document is missing at \(url.path). \
            Fetch it from a running color_matching instance via \
            `curl -fsS "$BASE_URL/api/v1/openapi.json" -o \(url.path)` \
            (see docs/openapi-client-generation.md).
            """
        )
        let object = try? JSONSerialization.jsonObject(with: data)
        return try XCTUnwrap(
            object as? [String: Any],
            "Vendored OpenAPI document at \(url.path) is not a JSON object."
        )
    }

    private func operation(_ spec: [String: Any], _ path: String, _ method: String) throws -> [String: Any] {
        let paths = try XCTUnwrap(spec["paths"] as? [String: Any])
        let pathItem = try XCTUnwrap(paths[path] as? [String: Any], "Spec is missing path \(path)")
        return try XCTUnwrap(pathItem[method] as? [String: Any], "Path \(path) is missing \(method.uppercased())")
    }

    /// Resolves the schema when it is a `$ref`, otherwise returns it as-is.
    private func resolveIfReferenced(_ spec: [String: Any], _ schema: [String: Any]) throws -> [String: Any] {
        guard let ref = schema["$ref"] as? String else { return schema }
        return try resolveReference(spec, ref)
    }

    /// Resolves `#/components/...`-style references.
    private func resolveReference(_ spec: [String: Any], _ ref: String) throws -> [String: Any] {
        let segments = ref.dropFirst(2).split(separator: "/").map(String.init)
        var current: Any = spec
        for segment in segments {
            guard let object = current as? [String: Any], let next = object[segment] else {
                throw UnresolvedReference(ref: ref)
            }
            current = next
        }
        guard let resolved = current as? [String: Any] else {
            throw UnresolvedReference(ref: ref)
        }
        return resolved
    }

    private func schema(_ spec: [String: Any], _ name: String) throws -> [String: Any] {
        let components = try XCTUnwrap(spec["components"] as? [String: Any])
        let schemas = try XCTUnwrap(components["schemas"] as? [String: Any])
        return try XCTUnwrap(schemas[name] as? [String: Any], "Spec is missing components.schemas.\(name)")
    }

    private func requestJSONSchema(_ spec: [String: Any], _ path: String, _ method: String) throws -> [String: Any] {
        let operation = try operation(spec, path, method)
        let requestBody = try XCTUnwrap(operation["requestBody"] as? [String: Any], "\(method.uppercased()) \(path) has no requestBody")
        return try referencedContentSchema(spec, requestBody)
    }

    private func responseJSONSchema(_ spec: [String: Any], _ path: String, _ method: String, _ status: String) throws -> [String: Any] {
        let operation = try operation(spec, path, method)
        let responses = try XCTUnwrap(operation["responses"] as? [String: Any])
        let response = try XCTUnwrap(responses[status] as? [String: Any], "\(method.uppercased()) \(path) does not document \(status)")
        return try referencedContentSchema(spec, response)
    }

    private func referencedContentSchema(_ spec: [String: Any], _ container: [String: Any]) throws -> [String: Any] {
        let content = try XCTUnwrap(container["content"] as? [String: Any])
        let json = try XCTUnwrap(content["application/json"] as? [String: Any])
        return try resolveIfReferenced(spec, try XCTUnwrap(json["schema"] as? [String: Any]))
    }

    private func isNullable(_ schema: [String: Any]) -> Bool {
        if schema["nullable"] as? Bool == true { return true }
        if let types = schema["type"] as? [Any] { return types.contains { "\($0)" == "null" } }
        return false
    }

    private func requiredProperties(_ schema: [String: Any]) -> Set<String> {
        Set((schema["required"] as? [String]) ?? [])
    }

    private func stringEnumValues(_ schema: [String: Any]) -> [String] {
        (schema["enum"] as? [String]) ?? []
    }

    // MARK: Deliverable: fetch or vendor the OpenAPI document

    func testVendoredSpecExistsParsesAndDeclaresOpenAPI3() throws {
        let spec = try loadedSpec()
        let version = try XCTUnwrap(spec["openapi"] as? String)
        XCTAssertTrue(version.hasPrefix("3."), "Expected OpenAPI 3.x, got \(version)")
        XCTAssertNotNil(spec["info"] as? [String: Any])
    }

    func testDeclaresBearerAuthSecurityScheme() throws {
        let spec = try loadedSpec()
        let components = try XCTUnwrap(spec["components"] as? [String: Any])
        let schemes = try XCTUnwrap(components["securitySchemes"] as? [String: Any])
        let bearer = try XCTUnwrap(schemes["bearerAuth"] as? [String: Any])
        XCTAssertEqual(bearer["type"] as? String, "http")
        XCTAssertEqual(bearer["scheme"] as? String, "bearer")
    }

    // MARK: Deliverable: the six surfaces the app uses are generated

    func testDocumentsAllAppSurfacesWithUpstreamOperationIds() throws {
        let spec = try loadedSpec()
        let expected: [(path: String, method: String, operationId: String)] = [
            ("/api/v1/test_sheets/{sheet_id}/manifest", "get", "ColorMatchingWeb.TestSheetController.manifest"),
            ("/api/v1/test_sheets/recent", "get", "ColorMatchingWeb.TestSheetController.recent"),
            ("/api/v1/test_sheets/{sheet_id}/ranked_results", "get", "ColorMatchingWeb.TestSheetController.ranked_results"),
            ("/api/v1/test_sheets/{sheet_id}/captures", "post", "ColorMatchingWeb.CaptureController.create"),
            ("/api/v1/captures/{capture_id}/measurements", "post", "ColorMatchingWeb.CaptureController.upload_measurements"),
            ("/api/v1/captures/{capture_id}/judgments", "post", "ColorMatchingWeb.CaptureController.upload_judgments"),
        ]
        for surface in expected {
            let operation = try operation(spec, surface.path, surface.method)
            XCTAssertEqual(
                operation["operationId"] as? String,
                surface.operationId,
                "\(surface.method.uppercased()) \(surface.path) operationId drifted"
            )
            let security = try XCTUnwrap(operation["security"] as? [[String: Any]], "\(surface.path) declares no security requirement")
            XCTAssertTrue(security.contains { ($0["bearerAuth"] as? [Any]) != nil })
        }
    }

    func testSheetPathParametersAreRequiredStrings() throws {
        let spec = try loadedSpec()
        for (path, method) in [("/api/v1/test_sheets/{sheet_id}/manifest", "get"), ("/api/v1/test_sheets/{sheet_id}/captures", "post")] {
            let operation = try operation(spec, path, method)
            let parameters = try XCTUnwrap(operation["parameters"] as? [[String: Any]])
            let sheetID = try XCTUnwrap(parameters.first { ($0["name"] as? String) == "sheet_id" })
            XCTAssertEqual(sheetID["in"] as? String, "path")
            XCTAssertEqual(sheetID["required"] as? Bool, true)
        }
    }

    // MARK: Manifest / recent sheets shapes

    func testManifestSchemaRequiresVersionedFields() throws {
        let spec = try loadedSpec()
        let manifest = try responseJSONSchema(spec, "/api/v1/test_sheets/{sheet_id}/manifest", "get", "200")
        XCTAssertEqual(requiredProperties(manifest), ["schema_version", "sheet_id", "capture_profile"])
        let properties = try XCTUnwrap(manifest["properties"] as? [String: Any])
        XCTAssertEqual(stringEnumValues(try XCTUnwrap(properties["schema_version"] as? [String: Any])), ["lps-sheet-manifest/v1"])
        let captureProfile = try XCTUnwrap(properties["capture_profile"] as? [String: Any])
        let captureProperties = try XCTUnwrap(captureProfile["properties"] as? [String: Any])
        XCTAssertEqual(stringEnumValues(try XCTUnwrap(captureProperties["scoring_algorithm_version"] as? [String: Any])), ["lps-distance-v1"])
    }

    func testRecentSheetsResponseRequiresSheetIDManifestURLAndNullableTitle() throws {
        let spec = try loadedSpec()
        let recent = try responseJSONSchema(spec, "/api/v1/test_sheets/recent", "get", "200")
        XCTAssertEqual(requiredProperties(recent), ["sheets"])
        let sheets = try XCTUnwrap((try XCTUnwrap(recent["properties"] as? [String: Any]))["sheets"] as? [String: Any])
        let items = try XCTUnwrap(sheets["items"] as? [String: Any])
        XCTAssertEqual(requiredProperties(items), ["sheet_id", "manifest_url", "title"])
        let properties = try XCTUnwrap(items["properties"] as? [String: Any])
        XCTAssertTrue(isNullable(try XCTUnwrap(properties["title"] as? [String: Any])), "sheets[].title must stay nullable (prose: 'title may be null')")
    }

    // MARK: Capture session creation

    func testCaptureCreateReturns201WithCaptureID() throws {
        let spec = try loadedSpec()
        let created = try responseJSONSchema(spec, "/api/v1/test_sheets/{sheet_id}/captures", "post", "201")
        XCTAssertEqual(requiredProperties(created), ["capture_id"])
    }

    func testCaptureRequestAcceptsTheNestedMetadataShapeTheAppSends() throws {
        let spec = try loadedSpec()
        let request = try requestJSONSchema(spec, "/api/v1/test_sheets/{sheet_id}/captures", "post")
        let properties = try XCTUnwrap(request["properties"] as? [String: Any])
        let metadata = try resolveIfReferenced(spec, try XCTUnwrap(properties["metadata"] as? [String: Any]))
        XCTAssertEqual(
            requiredProperties(metadata),
            ["device_model", "lens", "image_width", "image_height", "app_version", "timestamp"]
        )
        let quality = try XCTUnwrap(properties["quality"] as? [String: Any])
        let qualityProperties = try XCTUnwrap(quality["properties"] as? [String: Any])
        XCTAssertEqual(Set(qualityProperties.keys), ["detected_marker_count", "blur_score", "rejections"])
    }

    // MARK: Measurement + judgment uploads

    func testMeasurementUploadReturnsCountedBody() throws {
        let spec = try loadedSpec()
        let response = try responseJSONSchema(spec, "/api/v1/captures/{capture_id}/measurements", "post", "200")
        XCTAssertEqual(requiredProperties(response), ["capture_id", "measurement_count", "pair_score_count"])
    }

    func testMeasurementUploadRequestShape() throws {
        let spec = try loadedSpec()
        let request = try requestJSONSchema(spec, "/api/v1/captures/{capture_id}/measurements", "post")
        let properties = try XCTUnwrap(request["properties"] as? [String: Any])
        let measurements = try XCTUnwrap(properties["measurements"] as? [String: Any])
        let item = try XCTUnwrap(measurements["items"] as? [String: Any])
        XCTAssertEqual(requiredProperties(item), ["patch_id", "linear_rgb_median", "normalized_linear_rgb_median"])
        let itemProperties = try XCTUnwrap(item["properties"] as? [String: Any])
        let rgbPayload = try resolveIfReferenced(spec, try XCTUnwrap(itemProperties["linear_rgb_median"] as? [String: Any]))
        let anyOf = try XCTUnwrap(rgbPayload["anyOf"] as? [[String: Any]], "RgbPayload must stay an anyOf")
        let objectShape = try XCTUnwrap(
            anyOf.first { ($0["type"] as? String) == "object" },
            "RgbPayload must accept the {r,g,b} object shape the app sends"
        )
        let channels = try XCTUnwrap(objectShape["properties"] as? [String: Any])
        XCTAssertEqual(Set(channels.keys), ["r", "g", "b"])
    }

    func testPairScoreRequiresAlgorithmVersionAndOneScoreField() throws {
        let spec = try loadedSpec()
        let request = try requestJSONSchema(spec, "/api/v1/captures/{capture_id}/measurements", "post")
        let properties = try XCTUnwrap(request["properties"] as? [String: Any])
        let pairScores = try XCTUnwrap(properties["pair_scores"] as? [String: Any])
        let pairScore = try resolveIfReferenced(spec, try XCTUnwrap(pairScores["items"] as? [String: Any]))
        XCTAssertTrue(requiredProperties(pairScore).isSuperset(of: ["pair_id", "algorithm_version"]))
        let anyOf = try XCTUnwrap(pairScore["anyOf"] as? [[String: Any]])
        let alternatives = anyOf.compactMap { $0["required"] as? [String] }.flatMap { $0 }
        XCTAssertEqual(Set(alternatives), ["score", "similarity", "distance"])
    }

    func testJudgmentUploadRequestAndCountedResponse() throws {
        let spec = try loadedSpec()
        let response = try responseJSONSchema(spec, "/api/v1/captures/{capture_id}/judgments", "post", "200")
        XCTAssertEqual(requiredProperties(response), ["capture_id", "judgment_count"])
        let request = try requestJSONSchema(spec, "/api/v1/captures/{capture_id}/judgments", "post")
        XCTAssertEqual(requiredProperties(request), ["judgments"])
        let judgments = try XCTUnwrap((try XCTUnwrap(request["properties"] as? [String: Any]))["judgments"] as? [String: Any])
        let item = try XCTUnwrap(judgments["items"] as? [String: Any])
        XCTAssertEqual(requiredProperties(item), ["pair_id", "judgment"])
    }

    // MARK: Ranked results

    func testRankedResultsSchemaIsVersioned() throws {
        let spec = try loadedSpec()
        let ranked = try responseJSONSchema(spec, "/api/v1/test_sheets/{sheet_id}/ranked_results", "get", "200")
        XCTAssertEqual(requiredProperties(ranked), ["schema_version", "sheet_id"])
        let properties = try XCTUnwrap(ranked["properties"] as? [String: Any])
        XCTAssertEqual(stringEnumValues(try XCTUnwrap(properties["schema_version"] as? [String: Any])), ["lps-ranked-results/v1"])
    }

    // MARK: Error contract

    func testErrorResponsesAreDocumentedOnAppSurfaces() throws {
        let spec = try loadedSpec()
        let expectations: [(path: String, method: String, statuses: [String])] = [
            ("/api/v1/test_sheets/{sheet_id}/manifest", "get", ["401", "404"]),
            ("/api/v1/test_sheets/recent", "get", ["401"]),
            ("/api/v1/test_sheets/{sheet_id}/ranked_results", "get", ["401", "404"]),
            ("/api/v1/test_sheets/{sheet_id}/captures", "post", ["401", "404", "422"]),
            ("/api/v1/captures/{capture_id}/measurements", "post", ["401", "404", "422"]),
            ("/api/v1/captures/{capture_id}/judgments", "post", ["401", "404", "422"]),
        ]
        for expectation in expectations {
            let operation = try operation(spec, expectation.path, expectation.method)
            let responses = try XCTUnwrap(operation["responses"] as? [String: Any])
            for status in expectation.statuses {
                XCTAssertNotNil(responses[status], "\(expectation.method.uppercased()) \(expectation.path) missing \(status)")
            }
        }
        let errorSchema = try schema(spec, "ApiErrorResponse")
        XCTAssertEqual(requiredProperties(errorSchema), ["errors"])
    }
}
