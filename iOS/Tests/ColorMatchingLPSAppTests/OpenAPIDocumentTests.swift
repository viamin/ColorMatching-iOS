import Foundation
import XCTest

/// Guards the vendored OpenAPI document that drives swift-openapi-generator.
///
/// The document is vendored from `color_matching` (`GET /api/v1/openapi.json`,
/// published by viamin/color_matching#110) at
/// `iOS/Sources/ColorMatchingLPSAppCore/openapi.json`, which is the location
/// the `OpenAPIGenerator` build plugin reads it from.
///
/// These tests are the compile-free half of the generated-client test plan in
/// `docs/color-matching-openapi-deltas.md`; `GeneratedClientTests.swift`
/// covers the generated client mechanics once the plugin is wired in.
final class OpenAPIDocumentTests: XCTestCase {
    /// <repo>/iOS/Sources/ColorMatchingLPSAppCore/openapi.json
    private static let documentURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent() // OpenAPIDocumentTests.swift
        .deletingLastPathComponent() // ColorMatchingLPSAppTests
        .deletingLastPathComponent() // Tests -> now at iOS/
        .appendingPathComponent("Sources/ColorMatchingLPSAppCore/openapi.json")

    /// The /api/v1 surfaces the iOS app consumes today (issue #5).
    private static let appSurfaces: [(path: String, method: String)] = [
        ("/api/v1/test_sheets/recent", "get"),
        ("/api/v1/test_sheets/{sheet_id}/manifest", "get"),
        ("/api/v1/test_sheets/{sheet_id}/ranked_results", "get"),
        ("/api/v1/test_sheets/{sheet_id}/captures", "post"),
        ("/api/v1/captures/{capture_id}/measurements", "post"),
        ("/api/v1/captures/{capture_id}/judgments", "post")
    ]

    func testVendoredDocumentExistsAndParsesAsJSON() throws {
        let document = try Self.loadDocument()
        XCTAssertFalse(document.isEmpty)
    }

    func testVendoredDocumentIsOpenAPI3() throws {
        let document = try Self.loadDocument()
        let version = try XCTUnwrap(document["openapi"] as? String, "Missing top-level openapi version")
        XCTAssertTrue(version.hasPrefix("3."), "Expected OpenAPI 3.x, got \(version)")
    }

    func testVendoredDocumentDeclaresEveryAppSurface() throws {
        let document = try Self.loadDocument()
        let paths = try XCTUnwrap(document["paths"] as? [String: Any], "Missing paths object")

        for surface in Self.appSurfaces {
            let pathItem = try XCTUnwrap(paths[surface.path] as? [String: Any], "Missing path \(surface.path)")
            let operation = try XCTUnwrap(
                pathItem[surface.method] as? [String: Any],
                "Missing \(surface.method.uppercased()) operation for \(surface.path)"
            )
            let operationID = try XCTUnwrap(operation["operationId"] as? String, "Missing operationId on \(surface.path)")
            XCTAssertFalse(operationID.isEmpty)
        }
    }

    func testVendoredDocumentDeclaresBearerAuth() throws {
        let document = try Self.loadDocument()
        let components = try XCTUnwrap(document["components"] as? [String: Any])
        let securitySchemes = try XCTUnwrap(components["securitySchemes"] as? [String: Any])
        let bearer = try XCTUnwrap(securitySchemes["bearerAuth"] as? [String: Any])
        XCTAssertEqual(bearer["type"] as? String, "http")
        XCTAssertEqual(bearer["scheme"] as? String, "bearer")
    }

    func testVendoredDocumentDeclaresSchemasForAppSurfaces() throws {
        let document = try Self.loadDocument()
        let schemas = try XCTUnwrap(
            (document["components"] as? [String: Any])?["schemas"] as? [String: Any],
            "Missing components.schemas"
        )
        let expectedSchemas = [
            "TestSheetManifest",
            "RecentSheetsResponse",
            "RankedResults",
            "CaptureRequest",
            "CaptureMetadata",
            "CaptureCreatedResponse",
            "MeasurementUploadRequest",
            "MeasurementUploadResponse",
            "JudgmentUploadRequest",
            "JudgmentUploadResponse",
            "PairScoreRequest",
            "RgbPayload",
            "ApiErrorResponse"
        ]
        for schema in expectedSchemas {
            XCTAssertNotNil(schemas[schema], "Missing components.schemas.\(schema)")
        }
    }

    /// The versioned schema strings are the cross-repo compatibility contract;
    /// if the published spec changes them, regeneration must surface it.
    func testManifestSchemaPinsVersionedSchemaStrings() throws {
        let document = try Self.loadDocument()
        let manifest = try Self.schemaNamed("TestSheetManifest", in: document)

        let schemaVersion = try XCTUnwrap(
            (manifest["properties"] as? [String: Any])?["schema_version"] as? [String: Any]
        )
        XCTAssertEqual(schemaVersion["enum"] as? [String], ["lps-sheet-manifest/v1"])

        let captureProfile = try XCTUnwrap(
            (manifest["properties"] as? [String: Any])?["capture_profile"] as? [String: Any]
        )
        let scoringVersion = try XCTUnwrap(
            (captureProfile["properties"] as? [String: Any])?["scoring_algorithm_version"] as? [String: Any]
        )
        XCTAssertEqual(scoringVersion["enum"] as? [String], ["lps-distance-v1"])
    }

    func testRankedResultsSchemaPinsVersionedSchemaString() throws {
        let document = try Self.loadDocument()
        let ranked = try Self.schemaNamed("RankedResults", in: document)
        let schemaVersion = try XCTUnwrap(
            (ranked["properties"] as? [String: Any])?["schema_version"] as? [String: Any]
        )
        XCTAssertEqual(schemaVersion["enum"] as? [String], ["lps-ranked-results/v1"])
    }

    // MARK: - Helpers

    private static func loadDocument() throws -> [String: Any] {
        let url = documentURL
        guard FileManager.default.fileExists(atPath: url.path) else {
            XCTFail(
                """
                Vendored OpenAPI document is missing at \(url.path). \
                Fetch it from color_matching with:
                curl -o iOS/Sources/ColorMatchingLPSAppCore/openapi.json \
                <server>/api/v1/openapi.json
                (spec published by viamin/color_matching#110)
                """
            )
            throw CocoaError(.fileNoSuchFile)
        }
        let data = try Data(contentsOf: url)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private func schemaNamed(_ name: String, in document: [String: Any]) throws -> [String: Any] {
        let schemas = try XCTUnwrap(
            (document["components"] as? [String: Any])?["schemas"] as? [String: Any]
        )
        return try XCTUnwrap(schemas[name] as? [String: Any], "Missing schema \(name)")
    }
}
