import Foundation
import XCTest

/// Guards the vendored OpenAPI document against drift from the API surfaces
/// this companion app consumes. Fails until issue #5's implementation vendors
/// the spec published at `GET /api/v1/openapi.json` (viamin/color_matching#110)
/// at `iOS/Sources/OpenAPIGenerated/openapi.json`; see
/// docs/color-matching-openapi-client.md for the pinned contract.
final class OpenAPISpecCoverageTests: XCTestCase {
    private static let expectedEndpoints: [(path: String, verb: String, operationID: String)] = [
        ("/api/v1/test_sheets/{sheet_id}/manifest", "get", "ColorMatchingWeb.TestSheetController.manifest"),
        ("/api/v1/test_sheets/recent", "get", "ColorMatchingWeb.TestSheetController.recent"),
        (
            "/api/v1/test_sheets/{sheet_id}/ranked_results",
            "get",
            "ColorMatchingWeb.TestSheetController.ranked_results"
        ),
        ("/api/v1/test_sheets/{sheet_id}/captures", "post", "ColorMatchingWeb.CaptureController.create"),
        (
            "/api/v1/captures/{capture_id}/measurements",
            "post",
            "ColorMatchingWeb.CaptureController.upload_measurements"
        ),
        ("/api/v1/captures/{capture_id}/judgments", "post", "ColorMatchingWeb.CaptureController.upload_judgments"),
    ]

    func testVendoredSpecCoversEveryCompanionEndpoint() throws {
        let paths = try XCTUnwrap(try Self.loadVendoredSpec()["paths"] as? [String: Any], "spec has no paths object")

        for endpoint in Self.expectedEndpoints {
            let pathItem = try XCTUnwrap(
                paths[endpoint.path] as? [String: Any],
                "vendored spec is missing path \(endpoint.path)"
            )
            let operation = try XCTUnwrap(
                pathItem[endpoint.verb] as? [String: Any],
                "vendored spec is missing \(endpoint.verb.uppercased()) \(endpoint.path)"
            )
            XCTAssertEqual(
                operation["operationId"] as? String,
                endpoint.operationID,
                "operationId drift for \(endpoint.verb.uppercased()) \(endpoint.path)"
            )
        }
    }

    func testVendoredSpecPinsCompatibilityVersionStrings() throws {
        let spec = try Self.loadVendoredSpec()

        let manifestProperties = try XCTUnwrap(try Self.schema("TestSheetManifest", in: spec)["properties"] as? [String: Any])
        XCTAssertEqual(try Self.allowedValues(of: manifestProperties["schema_version"]), ["lps-sheet-manifest/v1"])

        let captureProfile = try XCTUnwrap(manifestProperties["capture_profile"] as? [String: Any])
        let captureProfileProperties = try XCTUnwrap(captureProfile["properties"] as? [String: Any])
        XCTAssertEqual(
            try Self.allowedValues(of: captureProfileProperties["scoring_algorithm_version"]),
            ["lps-distance-v1"]
        )

        let rankedProperties = try XCTUnwrap(try Self.schema("RankedResults", in: spec)["properties"] as? [String: Any])
        XCTAssertTrue(
            try Self.allowedValues(of: rankedProperties["schema_version"]).contains("lps-ranked-results/v1"),
            "RankedResults schema_version must pin lps-ranked-results/v1"
        )
    }

    func testVendoredSpecDeclaresBearerAuth() throws {
        let spec = try Self.loadVendoredSpec()
        let components = try XCTUnwrap(spec["components"] as? [String: Any], "spec has no components object")
        let securitySchemes = try XCTUnwrap(components["securitySchemes"] as? [String: Any])
        let bearerAuth = try XCTUnwrap(
            securitySchemes["bearerAuth"] as? [String: Any],
            "spec must declare the bearerAuth security scheme the companion app authenticates with"
        )
        XCTAssertEqual(bearerAuth["type"] as? String, "http")
        XCTAssertEqual(bearerAuth["scheme"] as? String, "bearer")
    }

    private static func loadVendoredSpec() throws -> [String: Any] {
        let specURL = try XCTUnwrap(
            vendoredSpecURL(),
            "No OpenAPI document vendored at iOS/Sources/OpenAPIGenerated/openapi.json. "
                + "Issue #5 must vendor the JSON served by color_matching's GET /api/v1/openapi.json "
                + "(viamin/color_matching#110); see docs/color-matching-openapi-client.md."
        )
        return try XCTUnwrap(
            try JSONSerialization.jsonObject(with: Data(contentsOf: specURL)) as? [String: Any],
            "vendored OpenAPI document is not a JSON object"
        )
    }

    private static func vendoredSpecURL() -> URL? {
        let packageRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let candidate = packageRoot.appendingPathComponent("Sources/OpenAPIGenerated/openapi.json")
        return FileManager.default.fileExists(atPath: candidate.path(percentEncoded: false)) ? candidate : nil
    }

    private static func schema(_ name: String, in spec: [String: Any]) throws -> [String: Any] {
        let components = try XCTUnwrap(spec["components"] as? [String: Any], "spec has no components object")
        return try XCTUnwrap(
            (components["schemas"] as? [String: Any])?[name] as? [String: Any],
            "spec is missing components.schemas.\(name)"
        )
    }

    private static func allowedValues(of property: Any?) throws -> [String] {
        let schema = try XCTUnwrap(property as? [String: Any])
        return try XCTUnwrap(schema["enum"] as? [String], "schema has no string enum values")
    }
}
