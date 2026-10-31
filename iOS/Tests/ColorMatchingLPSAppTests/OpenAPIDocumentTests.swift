import Foundation
import XCTest

final class OpenAPIDocumentTests: XCTestCase {
    private static let expectedOperations: [(path: String, operationID: String)] = [
        ("/api/v1/test_sheets/{sheet_id}/manifest", "getTestSheetManifest"),
        ("/api/v1/test_sheets/recent", "listRecentTestSheets"),
        ("/api/v1/test_sheets/{sheet_id}/captures", "createCapture"),
        ("/api/v1/captures/{capture_id}/measurements", "uploadMeasurements"),
        ("/api/v1/captures/{capture_id}/judgments", "uploadJudgments"),
        ("/api/v1/test_sheets/{sheet_id}/ranked_results", "getRankedResults")
    ]

    private static let expectedProperties = [
        "schema_version",
        "sheet_id",
        "manifest_url",
        "capture_id",
        "scoring_algorithm_version",
        "detected_marker_count",
        "pair_scores",
        "judgments"
    ]

    func testVendoredSpecExistsAndDeclaresOpenAPI3() throws {
        let spec = try loadSpec()
        XCTAssertTrue(
            spec.contains("openapi: 3") || spec.contains("\"openapi\": \"3"),
            "iOS/openapi.yaml must declare OpenAPI 3.x so swift-openapi-generator accepts it"
        )
    }

    func testSpecCoversEverySurfaceTheAppUses() throws {
        let spec = try loadSpec()
        for expected in Self.expectedOperations {
            XCTAssertTrue(
                spec.contains(expected.path),
                "iOS/openapi.yaml must document \(expected.path) (required by the app and docs/color-matching-api-contract.md)"
            )
            XCTAssertTrue(
                Self.containsOperationID(expected.operationID, in: spec),
                "iOS/openapi.yaml must declare operationId \(expected.operationID) for \(expected.path)"
            )
        }
    }

    func testSpecDeclaresBearerAuthentication() throws {
        let spec = try loadSpec()
        XCTAssertTrue(
            spec.contains("bearerAuth"),
            "iOS/openapi.yaml must define a bearerAuth security scheme for the shared bearer token"
        )
        XCTAssertTrue(
            spec.range(of: "scheme:\\s*\"?bearer\\b", options: .regularExpression) != nil,
            "bearerAuth must use type: http with scheme: bearer"
        )
    }

    func testSpecDefinesContractPropertyNames() throws {
        let spec = try loadSpec()
        for property in Self.expectedProperties {
            XCTAssertTrue(
                Self.containsProperty(property, in: spec),
                "iOS/openapi.yaml must define the snake_case property \(property) used by the wire contract"
            )
        }
    }

    func testSpecMarksRecentSheetTitleNullable() throws {
        let spec = try loadSpec()
        XCTAssertTrue(
            Self.containsProperty("title", in: spec),
            "iOS/openapi.yaml must define the recent-sheet title property"
        )
        XCTAssertTrue(
            spec.range(of: "title\"?:.{0,200}(nullable|type\"?:\\s*\"?(string|\\[)", options: [.regularExpression, .caseInsensitive]) != nil,
            "Recent sheet title must be nullable; the prose contract allows null titles"
        )
    }

    private func loadSpec() throws -> String {
        let specURL = Self.packageRoot.appendingPathComponent("openapi.yaml")
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: specURL.path),
            "Vendor the published OpenAPI document from viamin/color_matching#110 at iOS/openapi.yaml (see docs/generated-openapi-client-verification.md)"
        )
        return String(decoding: try Data(contentsOf: specURL), as: UTF8.self)
    }

    private static var packageRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private static func containsOperationID(_ operationID: String, in spec: String) -> Bool {
        spec.range(of: "operationId\"?\\s*:\\s*\"?" + operationID + "\\b", options: .regularExpression) != nil
    }

    private static func containsProperty(_ property: String, in spec: String) -> Bool {
        spec.range(of: "\"?" + property + "\"?\\s*:", options: .regularExpression) != nil
    }
}
