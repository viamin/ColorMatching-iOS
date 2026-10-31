import Foundation
import XCTest

final class OpenAPIContractTests: XCTestCase {
    func testPackageEnablesOpenAPIGenerationAndRuntime() throws {
        let package = try String(contentsOf: packageURL(), encoding: .utf8)

        XCTAssertTrue(package.contains("swift-openapi-generator"))
        XCTAssertTrue(package.contains("swift-openapi-runtime"))
        XCTAssertTrue(package.contains("OpenAPIGenerator"))
    }

    func testVendoredSpecDefinesEveryOperationUsedByTheApp() throws {
        let paths = try paths(in: spec())

        XCTAssertNotNil(paths["/api/v1/test_sheets/{sheet_id}/manifest"]?["get"])
        XCTAssertNotNil(paths["/api/v1/test_sheets/recent"]?["get"])
        XCTAssertNotNil(paths["/api/v1/test_sheets/{sheet_id}/captures"]?["post"])
        XCTAssertNotNil(paths["/api/v1/captures/{capture_id}/measurements"]?["post"])
        XCTAssertNotNil(paths["/api/v1/captures/{capture_id}/judgments"]?["post"])
        XCTAssertNotNil(paths["/api/v1/test_sheets/{sheet_id}/ranked_results"]?["get"])
    }

    func testManifestSchemaDescribesTheGeometryConsumedBySheetAnalysis() throws {
        let manifest = try schema(named: "TestSheetManifest")

        XCTAssertEqual(Set(manifest.requiredFields), [
            "schema_version", "sheet_id", "sheet_version", "manifest_url", "page",
            "registration_markers", "patches", "pairs", "capture_profile"
        ])
        XCTAssertNotNil(manifest.properties["page"])
        XCTAssertNotNil(manifest.properties["registration_markers"])
        XCTAssertNotNil(manifest.properties["patches"])
        XCTAssertNotNil(manifest.properties["pairs"])
    }

    func testMeasurementUploadSchemaDescribesEveryValueTheAppSends() throws {
        let upload = try schema(named: "MeasurementUploadRequest")
        let measurement = try XCTUnwrap(upload.properties["measurements"]?["items"] as? [String: Any])

        XCTAssertEqual(Set(upload.requiredFields), ["scoring_algorithm_version", "measurements", "pair_scores"])
        XCTAssertNotNil(measurement["properties"] as? [String: Any])
        XCTAssertNotNil((measurement["properties"] as? [String: Any])?["stats"])
    }

    func testRankedResultsSchemaDescribesTheReturnedRankedPairs() throws {
        let rankedResults = try schema(named: "RankedResults")

        XCTAssertNotNil(rankedResults.properties["results"])
        XCTAssertNotNil(rankedResults.properties["capture_count"])
        XCTAssertNotNil(rankedResults.properties["scoring_algorithm_versions"])
    }

    private func spec() throws -> [String: Any] {
        let data = try Data(contentsOf: vendoredSpecURL())
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private func paths(in spec: [String: Any]) throws -> [String: [String: [String: Any]]] {
        try XCTUnwrap(spec["paths"] as? [String: [String: [String: Any]]])
    }

    private func schema(named name: String) throws -> OpenAPISchema {
        let document = try spec()
        let components = try XCTUnwrap(document["components"] as? [String: Any])
        let schemas = try XCTUnwrap(components["schemas"] as? [String: [String: Any]])
        return OpenAPISchema(rawValue: try XCTUnwrap(schemas[name]))
    }

    private func packageURL() -> URL {
        iosRootURL().appendingPathComponent("Package.swift")
    }

    private func vendoredSpecURL() -> URL {
        iosRootURL().appendingPathComponent("Sources/ColorMatchingOpenAPI/openapi.json")
    }

    private func iosRootURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}

private struct OpenAPISchema {
    let rawValue: [String: Any]

    var properties: [String: Any] {
        rawValue["properties"] as? [String: Any] ?? [:]
    }

    var requiredFields: [String] {
        rawValue["required"] as? [String] ?? []
    }
}
