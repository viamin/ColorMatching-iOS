import Foundation
import XCTest

/// Red-phase tripwires for issue #5: the OpenAPI toolchain, the vendored spec
/// document, and the surface coverage the app depends on must all exist inside
/// the iOS package before the hand-written API layer is retired.
///
/// These assertions fail until the implementation run lands the migration
/// described in docs/openapi-client-migration.md, and keep guarding against
/// silent drift afterwards: removing a path, an operationId, or a
/// manifest/ranked-results field the app relies on fails here first.
final class OpenAPIMigrationArtifactsTests: XCTestCase {
    private let packageRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    private var specURL: URL {
        packageRoot.appending(path: "Sources/ColorMatchingOpenAPI/openapi.yaml")
    }

    func testPackageDeclaresOpenAPIGeneratorPluginAndRuntime() throws {
        let manifest = try String(contentsOf: packageRoot.appending(path: "Package.swift"), encoding: .utf8)
        XCTAssertTrue(
            manifest.contains("swift-openapi-generator"),
            "Package.swift must depend on apple/swift-openapi-generator (issue #5); see docs/openapi-client-migration.md"
        )
        XCTAssertTrue(
            manifest.contains("swift-openapi-runtime"),
            "Package.swift must depend on apple/swift-openapi-runtime (issue #5); see docs/openapi-client-migration.md"
        )
        XCTAssertTrue(
            manifest.contains("OpenAPIGenerator"),
            "Package.swift must apply the OpenAPIGenerator plugin to the ColorMatchingOpenAPI target; see docs/openapi-client-migration.md"
        )
    }

    func testOpenAPIDocumentIsVendoredForGeneration() {
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: specURL.path),
            "Vendored OpenAPI document is missing at \(specURL.path); vendor the published spec from viamin/color_matching (issue #110 / PR #113) as described in docs/openapi-client-migration.md"
        )
    }

    func testSpecCoversEverySurfaceTheAppUses() throws {
        let spec = try specText()
        let requiredPaths = [
            "/api/v1/test_sheets/{sheet_id}/manifest",
            "/api/v1/test_sheets/recent",
            "/api/v1/test_sheets/{sheet_id}/captures",
            "/api/v1/captures/{capture_id}/measurements",
            "/api/v1/captures/{capture_id}/judgments",
            "/api/v1/test_sheets/{sheet_id}/ranked_results",
        ]
        for path in requiredPaths {
            XCTAssertTrue(
                spec.contains(path),
                "Vendored spec must declare path \(path); a missing surface cannot be generated and server drift stays invisible"
            )
        }
    }

    func testSpecDefinesStableOperationIDsForGeneratedClientMethods() throws {
        let spec = try specText()
        let requiredOperationIDs = [
            "fetchSheetManifest",
            "fetchRecentSheets",
            "createCapture",
            "uploadMeasurements",
            "uploadJudgments",
            "fetchRankedResults",
        ]
        for operationID in requiredOperationIDs {
            XCTAssertTrue(
                spec.contains(operationID),
                "Vendored spec must define operationId \(operationID); upstream OpenApiSpex defaults produce controller-qualified ids like 'ColorMatchingWeb.TestSheetController.manifest' that sanitize into unstable Swift method names"
            )
        }
    }

    func testSpecDeclaresBearerAuth() throws {
        let spec = try specText()
        XCTAssertTrue(
            spec.contains("bearerAuth"),
            "Vendored spec must declare the bearerAuth security scheme applied to every /api/v1 endpoint by viamin/color_matching"
        )
    }

    func testSpecDocumentsManifestFieldsTheAppDecodes() throws {
        let spec = try specText()
        let manifestFields = [
            "sheet_version",
            "manifest_url",
            "created_at",
            "registration_markers",
            "printer_profile",
            "expected_illuminant",
            "preferred_camera",
            "safe_inset_mm",
            "pair_side",
            "source_color",
            "grid_row",
            "grid_col",
        ]
        for field in manifestFields {
            XCTAssertTrue(
                spec.contains(field),
                "Vendored spec must document manifest field \(field): the upstream spec only requires schema_version/sheet_id/capture_profile, but SheetAnalyzer decodes this field from every manifest"
            )
        }
    }

    func testSpecDocumentsRankedResultsPayload() throws {
        let spec = try specText()
        let rankedResultsFields = [
            "lps-ranked-results/v1",
            "scoring_algorithm_versions",
            "source_colors",
            "current_judgment",
            "observation_count",
            "latest_observation",
            "capture_count",
        ]
        for field in rankedResultsFields {
            XCTAssertTrue(
                spec.contains(field),
                "Vendored spec must document ranked-results field \(field): the upstream spec only requires schema_version/sheet_id, but the endpoint renders a full aggregate payload (see docs/openapi-client-migration.md)"
            )
        }
    }

    private func specText() throws -> String {
        do {
            return try String(contentsOf: specURL, encoding: .utf8)
        } catch {
            XCTFail("Cannot read vendored OpenAPI document at \(specURL.path) — vendor the published spec first (docs/openapi-client-migration.md)")
            throw error
        }
    }
}
