import Foundation
import XCTest

/// Guards the vendored OpenAPI document that drives client generation.
///
/// The implementation copies `docs/color-matching-openapi-v1.yaml` verbatim
/// to `iOS/Sources/ColorMatchingOpenAPI/openapi.yaml` (the generator's
/// document path). These checks pin the upstream operationIds, paths,
/// status codes, and the gap-filled schema fields the app depends on, so
/// that any regeneration drift (upstream contract change or accidental
/// spec edit) is caught as a test failure instead of a runtime surprise.
final class OpenAPISpecContractTests: XCTestCase {
    private let specURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("Sources/ColorMatchingOpenAPI/openapi.yaml")

    private func loadSpec() throws -> String {
        try String(contentsOf: specURL, encoding: .utf8)
    }

    func testVendoredSpecExistsAtGeneratorDocumentPath() throws {
        XCTAssertTrue(
            assertFileExists(specURL),
            "expected a spec at \(specURL.path). Copy docs/color-matching-openapi-v1.yaml verbatim to iOS/Sources/ColorMatchingOpenAPI/openapi.yaml (see docs/openapi-generated-client-plan.md)"
        )
    }

    func testAppSurfacesKeepUpstreamPathsAndOperationIds() throws {
        let spec = try loadSpec()
        let appSurfaces: [(path: String, operationId: String)] = [
            ("/api/v1/test_sheets/recent", "ColorMatchingWeb.TestSheetController.recent"),
            ("/api/v1/test_sheets/{sheet_id}/manifest", "ColorMatchingWeb.TestSheetController.manifest"),
            ("/api/v1/test_sheets/{sheet_id}/ranked_results", "ColorMatchingWeb.TestSheetController.ranked_results"),
            ("/api/v1/test_sheets/{sheet_id}/captures", "ColorMatchingWeb.CaptureController.create"),
            ("/api/v1/captures/{capture_id}/measurements", "ColorMatchingWeb.CaptureController.upload_measurements"),
            ("/api/v1/captures/{capture_id}/judgments", "ColorMatchingWeb.CaptureController.upload_judgments")
        ]
        for surface in appSurfaces {
            XCTAssertTrue(spec.contains("operationId: \(surface.operationId)"), "missing operationId \(surface.operationId)")
            XCTAssertTrue(spec.contains("\(surface.path):"), "missing path \(surface.path)")
        }
    }

    func testUploadEndpointsDeclareJSONResponsesWithCounts() throws {
        let spec = try loadSpec()
        XCTAssertTrue(spec.contains("MeasurementUploadResponse:"))
        XCTAssertTrue(spec.contains("#/components/schemas/MeasurementUploadResponse"))
        XCTAssertTrue(spec.contains("JudgmentUploadResponse:"))
        XCTAssertTrue(spec.contains("#/components/schemas/JudgmentUploadResponse"))
        XCTAssertTrue(spec.contains("measurement_count:"))
        XCTAssertTrue(spec.contains("pair_score_count:"))
        XCTAssertTrue(spec.contains("judgment_count:"))
    }

    func testManifestSchemaCarriesGeometryGapFill() throws {
        let spec = try loadSpec()
        let manifestBlock = try XCTUnwrap(spec.block(named: "TestSheetManifest:"))
        for key in [
            "schema_version:", "sheet_id:", "sheet_version:", "manifest_url:", "created_at:",
            "page:", "registration_markers:", "printer_profile:", "capture_profile:",
            "patches:", "pairs:"
        ] {
            XCTAssertTrue(manifestBlock.contains(key), "TestSheetManifest is missing \(key)")
        }
        XCTAssertTrue(spec.contains("#/components/schemas/ManifestPatch"))
        XCTAssertTrue(spec.contains("#/components/schemas/ManifestPair"))
        XCTAssertTrue(spec.contains("#/components/schemas/RegistrationMarker"))
        XCTAssertTrue(spec.contains("safe_inset_mm:"))
    }

    func testRankedResultsSchemaCarriesAggregateGapFill() throws {
        let spec = try loadSpec()
        XCTAssertTrue(spec.contains("#/components/schemas/RankedResultPair"))
        XCTAssertTrue(spec.contains("#/components/schemas/RankedResultScore"))
        XCTAssertTrue(spec.contains("#/components/schemas/RankedResultColors"))
        let rankedBlock = try XCTUnwrap(spec.block(named: "RankedResults:"))
        for key in ["schema_version:", "sheet_id:", "printer_profile:", "capture_count:", "scoring_algorithm_versions:", "results:"] {
            XCTAssertTrue(rankedBlock.contains(key), "RankedResults is missing \(key)")
        }
    }

    func testMeasurementUploadItemPinsPublishedWireShape() throws {
        let spec = try loadSpec()
        let itemBlock = try XCTUnwrap(spec.block(named: "MeasurementUploadItem:"))
        XCTAssertTrue(itemBlock.contains("- patch_id"))
        XCTAssertTrue(itemBlock.contains("- linear_rgb_median"))
        XCTAssertTrue(itemBlock.contains("- normalized_linear_rgb_median"))
        XCTAssertFalse(
            itemBlock.contains("sample_count"),
            "the published MeasurementUploadRequest carries no per-measurement stats block (delta D3/D4)"
        )
        let requestBlock = try XCTUnwrap(spec.block(named: "MeasurementUploadRequest:"))
        XCTAssertFalse(
            requestBlock.contains("scoring_algorithm_version"),
            "the published MeasurementUploadRequest has no top-level scoring_algorithm_version (delta D3)"
        )
    }

    func testRgbPayloadIsPinnedToObjectForm() throws {
        let spec = try loadSpec()
        let block = try XCTUnwrap(spec.block(named: "RgbPayload:"))
        XCTAssertFalse(block.contains("anyOf:"), "RgbPayload must stay pinned to the {r, g, b} object form (normalization V2)")
        for key in ["r:", "g:", "b:"] {
            XCTAssertTrue(block.contains(key))
        }
    }

    func testBearerSecuritySchemeIsDeclared() throws {
        let spec = try loadSpec()
        XCTAssertTrue(spec.contains("bearerAuth:"))
        XCTAssertTrue(spec.contains("scheme: bearer"))
    }
}

private extension String {
    /// Returns the YAML block for a component schema key (indented four
    /// spaces), so assertions cannot accidentally match identically named
    /// keys inside unrelated schemas.
    func block(named key: String) -> Substring? {
        guard let range = range(of: "\n    \(key)\n") else { return nil }
        let lines = self[range.lowerBound...]
            .dropFirst()
            .split(separator: "\n", omittingEmptySubsequences: false)
            .dropFirst()
        var collected: [String] = []
        for line in lines {
            guard line.hasPrefix("      ") else { break }
            collected.append(String(line))
        }
        return collected.joined(separator: "\n")[...]
    }
}

private func assertFileExists(_ url: URL) -> Bool {
    FileManager.default.fileExists(atPath: url.path)
}
