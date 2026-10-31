import Foundation
import MeasurementCore
import XCTest

/// Pins the hand-written `SheetManifest` model against the manifest shape the
/// Phoenix app actually renders (`ColorMatchingWeb.TestSheetJSON.manifest`,
/// confirmed against `viamin/color_matching` PR #113 which published the
/// OpenAPI spec tracked by `viamin/color_matching#110`).
///
/// The published OpenAPI `Manifest` schema marks
/// `capture_profile.scoring_algorithm_version` as the compatibility-critical
/// field for this response (the one thing `color_matching` promises iOS can
/// rely on). `printer_profile` is also present on every real response. The
/// hand-written `SheetManifest` in `MeasurementCore/Models.swift` has no
/// `captureProfile` or `printerProfile` property at all, so both are silently
/// dropped on decode -- exactly the kind of drift issue #5 wants a generated
/// client to turn into a compile error instead of a runtime surprise.
final class ManifestContractDeltaTests: XCTestCase {
    func testManifestRetainsCaptureProfileScoringAlgorithmVersion() throws {
        let manifest = try Self.decodeRealManifestFixture()

        let json = try Self.reencode(manifest)
        let captureProfile = try XCTUnwrap(
            json["capture_profile"] as? [String: Any],
            "SheetManifest has no captureProfile property, so capture_profile is dropped when decoding the real server response"
        )
        XCTAssertEqual(captureProfile["scoring_algorithm_version"] as? String, "lps-distance-v1")
    }

    func testManifestRetainsPrinterProfile() throws {
        let manifest = try Self.decodeRealManifestFixture()

        let json = try Self.reencode(manifest)
        let printerProfile = try XCTUnwrap(
            json["printer_profile"] as? [String: Any],
            "SheetManifest has no printerProfile property, so printer_profile is dropped when decoding the real server response"
        )
        XCTAssertEqual(printerProfile["printer_make_model"] as? String, "Epson SureColor P600")
    }

    private static func decodeRealManifestFixture() throws -> SheetManifest {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(SheetManifest.self, from: realManifestFixture)
    }

    private static func reencode(_ manifest: SheetManifest) throws -> [String: Any] {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(manifest)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    /// Shape taken from `ColorMatchingWeb.TestSheetJSON.manifest/1` in
    /// `viamin/color_matching` (as of the PR #113 commit that published the
    /// OpenAPI spec), not from the prose contract.
    private static let realManifestFixture = Data(#"""
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
        "printer_make_model": "Epson SureColor P600",
        "paper_type": "Legion Photo Luster",
        "ink_type": "UltraChrome HD",
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
