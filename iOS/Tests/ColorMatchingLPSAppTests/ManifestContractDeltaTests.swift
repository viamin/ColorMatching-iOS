import Foundation
import MeasurementCore
import XCTest

/// Pins the behavior the generated OpenAPI client must have once it replaces
/// `SheetManifest` (see `docs/openapi-contract-deltas.md`, delta #2).
///
/// `realManifestJSON` below is shaped like the actual `color_matching`
/// `GET /api/v1/test_sheets/:sheet_id/manifest` response (per
/// `ColorMatchingWeb.TestSheetJSON.manifest/1` in `viamin/color_matching#113`),
/// which includes `printer_profile` and `capture_profile` — fields the
/// hand-written `SheetManifest` (iOS/Sources/MeasurementCore/Models.swift)
/// never declared. `Codable` silently ignores unrecognized keys, so decoding
/// succeeds today but those fields vanish on the way back out. These tests
/// are expected to fail until the manifest model (generated or hand-written)
/// actually models `printer_profile` / `capture_profile`.
final class ManifestContractDeltaTests: XCTestCase {
    func testManifestDecodingPreservesServerDeclaredCaptureProfile() throws {
        let manifest = try JSONDecoder().decode(SheetManifest.self, from: Self.realManifestJSON)
        let roundTripped = try Self.jsonObject(from: JSONEncoder().encode(manifest))

        let captureProfile = roundTripped["capture_profile"] as? [String: Any]
        XCTAssertNotNil(
            captureProfile,
            "capture_profile must survive decode/encode so the app can detect the server changing scoring_algorithm_version at compile time, not at runtime"
        )
        XCTAssertEqual(captureProfile?["scoring_algorithm_version"] as? String, LPSScorer.algorithmVersion)
    }

    func testManifestDecodingPreservesServerDeclaredPrinterProfile() throws {
        let manifest = try JSONDecoder().decode(SheetManifest.self, from: Self.realManifestJSON)
        let roundTripped = try Self.jsonObject(from: JSONEncoder().encode(manifest))

        let printerProfile = roundTripped["printer_profile"] as? [String: Any]
        XCTAssertNotNil(printerProfile, "printer_profile must survive decode/encode instead of being silently dropped")
        XCTAssertEqual(printerProfile?["printer_make_model"] as? String, "Epson SureColor P900")
        XCTAssertEqual(printerProfile?["paper_type"] as? String, "paper name")
        XCTAssertEqual(printerProfile?["ink_type"] as? String, "ink set")
    }

    private static func jsonObject(from data: Data) throws -> [String: Any] {
        try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    /// Shaped like `ColorMatchingWeb.TestSheetJSON.manifest/1`'s real response,
    /// not the (now-stale) example in `docs/color-matching-api-contract.md`.
    private static let realManifestJSON = Data(#"""
    {
      "schema_version": "lps-sheet-manifest/v1",
      "sheet_version": "lps-letter-grid-v1",
      "sheet_id": "sheet_123",
      "manifest_url": "https://example.test/api/v1/test_sheets/sheet_123/manifest",
      "created_at": "2026-07-25T12:00:00Z",
      "page": {"units": "mm", "width": 215.9, "height": 279.4},
      "registration_markers": [
        {"role": "top_left", "shape": "solid_square", "rect": {"x": 12, "y": 12, "width": 8, "height": 8}}
      ],
      "printer_profile": {
        "printer_make_model": "Epson SureColor P900",
        "paper_type": "paper name",
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
        {
          "id": "pair_1#first",
          "role": "pair_color",
          "pair_id": "pair_1",
          "pair_side": "first",
          "reference_role": null,
          "source_color": "#FF0000",
          "safe_inset_mm": 1.5,
          "rect": {"x": 16, "y": 38, "width": 16, "height": 10}
        }
      ],
      "pairs": [
        {
          "id": "pair_1",
          "first_patch_id": "pair_1#first",
          "second_patch_id": "pair_1#second",
          "source_colors": ["#FF0000", "#00FF00"],
          "grid_row": 0,
          "grid_col": 1
        }
      ]
    }
    """#.utf8)
}
