import Foundation
import XCTest

final class OpenAPISpecCoverageTests: XCTestCase {
    private static let requiredOperations: [(path: String, method: String, surface: String)] = [
        ("/api/v1/test_sheets/recent", "get", "recent sheets"),
        ("/api/v1/test_sheets/{sheet_id}/manifest", "get", "sheet manifest"),
        ("/api/v1/test_sheets/{sheet_id}/captures", "post", "capture session creation"),
        ("/api/v1/test_sheets/{sheet_id}/ranked_results", "get", "ranked results"),
        ("/api/v1/captures/{capture_id}/measurements", "post", "measurement upload"),
        ("/api/v1/captures/{capture_id}/judgments", "post", "judgment upload")
    ]

    func testVendoredSpecExistsAsJSONDocument() throws {
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: Self.specURL.path),
            "Expected the vendored OpenAPI document at \(Self.specURL.path). Fetch it from viamin/color_matching#110 and commit it as JSON."
        )
    }

    func testVendoredSpecDeclaresVersionAndComponentSchemas() throws {
        let document = try Self.specDocument()
        XCTAssertNotNil(document["openapi"], "Vendored document must declare its OpenAPI version.")
        let components = try XCTUnwrap(
            document["components"] as? [String: Any],
            "Vendored document must declare components."
        )
        let schemas = try XCTUnwrap(
            components["schemas"] as? [String: Any],
            "Vendored document must declare component schemas."
        )
        XCTAssertFalse(schemas.isEmpty, "Vendored document must declare at least one component schema.")
    }

    func testVendoredSpecCoversEverySurfaceTheAppUses() throws {
        let document = try Self.specDocument()
        let paths = try XCTUnwrap(
            document["paths"] as? [String: Any],
            "Vendored document must declare paths."
        )
        let missing = Self.requiredOperations.filter { operation in
            guard let pathItem = paths[operation.path] as? [String: Any] else { return true }
            return pathItem[operation.method] == nil
        }
        XCTAssertTrue(
            missing.isEmpty,
            "Vendored OpenAPI document is missing operations for app surfaces: \(missing.map(\.surface))."
        )
    }

    private static let specURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("Sources/ColorMatchingOpenAPI/openapi.json")

    private static func specDocument() throws -> [String: Any] {
        let data = try Data(contentsOf: specURL)
        return try XCTUnwrap(
            try JSONSerialization.jsonObject(with: data) as? [String: Any],
            "Vendored OpenAPI document at \(specURL.path) is not a JSON object."
        )
    }
}
