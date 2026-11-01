import Foundation
import MeasurementCore
import XCTest

/// Compares `SheetManifest`'s decoded/encoded shape against a fixture built from the
/// *published* manifest renderer (`ColorMatchingWeb.TestSheetJSON.manifest/1`,
/// viamin/color_matching#113, commit 094bd6d3443ddacbda7e63354299867eb5bdfa9f) rather than
/// the prose contract in docs/color-matching-api-contract.md. `SheetManifest` currently has
/// no properties for `created_at`, `printer_profile`, or `capture_profile`, so those fields
/// are silently dropped on decode. See docs/color-matching-api-contract-deltas.md.
final class ManifestSchemaDriftTests: XCTestCase {
    func testManifestModelsEveryFieldThePublishedManifestEndpointReturns() throws {
        let realManifestJSON = Data(Self.realManifestJSON.utf8)

        let manifest = try JSONDecoder().decode(SheetManifest.self, from: realManifestJSON)
        let roundTripped = try JSONEncoder().encode(manifest)

        let publishedKeys = try Self.topLevelKeys(of: realManifestJSON)
        let modeledKeys = try Self.topLevelKeys(of: roundTripped)

        XCTAssertEqual(
            modeledKeys,
            publishedKeys,
            "SheetManifest is missing: \(publishedKeys.subtracting(modeledKeys).sorted())"
        )
    }

    private static func topLevelKeys(of data: Data) throws -> Set<String> {
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        return Set(object.keys)
    }

    // Field names/shape mirror `ColorMatchingWeb.TestSheetJSON.manifest/1` and
    // `ColorMatchingWeb.ApiSchemas.PrinterProfile`, not the prose contract doc, which still
    // shows the pre-spec `{id, name, paper, ink, settings}` printer_profile shape.
    private static let realManifestJSON = """
    {
      "schema_version": "lps-sheet-manifest/v1",
      "sheet_id": "sheet_123",
      "sheet_version": "lps-letter-grid-v1",
      "manifest_url": "https://example.test/api/v1/test_sheets/sheet_123/manifest",
      "created_at": "2026-07-25T12:00:00Z",
      "page": {"units": "mm", "width": 215.9, "height": 279.4},
      "registration_markers": [
        {"role": "top_left", "shape": "solid_square", "rect": {"x": 12, "y": 12, "width": 8, "height": 8}}
      ],
      "printer_profile": {
        "printer_make_model": "Canon PIXMA Pro-200",
        "paper_type": "Research printer",
        "ink_type": "ink set",
        "icc_profile": null,
        "print_settings": null,
        "driver_name": null,
        "driver_version": null,
        "calibration_date": null,
        "calibration_version": null,
        "notes": null
      },
      "capture_profile": {
        "expected_illuminant": "low_pressure_sodium",
        "preferred_camera": "built_in_wide_angle_rear",
        "scoring_algorithm_version": "lps-distance-v1"
      },
      "patches": [
        {"id": "pair_1#first", "role": "pair_color", "pair_id": "pair_1", "pair_side": "first", "reference_role": null, "source_color": "#FF0000", "safe_inset_mm": 1.5, "rect": {"x": 16, "y": 38, "width": 16, "height": 10}},
        {"id": "pair_1#second", "role": "pair_color", "pair_id": "pair_1", "pair_side": "second", "reference_role": null, "source_color": "#00FF00", "safe_inset_mm": 1.5, "rect": {"x": 36, "y": 38, "width": 16, "height": 10}}
      ],
      "pairs": [
        {"id": "pair_1", "first_patch_id": "pair_1#first", "second_patch_id": "pair_1#second", "source_colors": ["#FF0000", "#00FF00"], "grid_row": 0, "grid_col": 1}
      ]
    }
    """
}
