import Foundation
import MeasurementCore
import ColorMatchingLPSAppCore

enum OpenAPIFixtures {
    static let manifest = #"""
    {
      "schema_version": "lps-sheet-manifest/v1",
      "sheet_id": "sheet_1",
      "sheet_version": "lps-letter-grid-v1",
      "manifest_url": "/api/v1/test_sheets/sheet_1/manifest",
      "created_at": "2026-07-25T12:00:00Z",
      "page": {"units": "mm", "width": 215.9, "height": 279.4},
      "registration_markers": [
        {"role": "top_left", "shape": "solid_square", "rect": {"x": 12, "y": 12, "width": 8, "height": 8}}
      ],
      "printer_profile": {
        "printer_make_model": "Research printer",
        "paper_type": "Plain A4",
        "ink_type": "Dye 6-color",
        "icc_profile": null,
        "print_settings": {"quality": "high"},
        "driver_name": null,
        "driver_version": null,
        "calibration_date": "2026-07-01",
        "calibration_version": "2",
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
        },
        {
          "id": "pair_1#second",
          "role": "pair_color",
          "pair_id": "pair_1",
          "pair_side": "second",
          "reference_role": null,
          "source_color": "#00FF00",
          "safe_inset_mm": 1.5,
          "rect": {"x": 36, "y": 38, "width": 16, "height": 10}
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
    """#

    static let recentSheets = #"""
    {
      "sheets": [
        {"sheet_id": "sheet_1", "manifest_url": "/api/v1/test_sheets/sheet_1/manifest", "title": null},
        {"sheet_id": "sheet_2", "manifest_url": "/api/v1/test_sheets/sheet_2/manifest", "title": "July LPS comparison sheet"}
      ]
    }
    """#

    static let captureCreated = #"{"capture_id": "42"}"#

    static let measurementUploadResponse = #"{"capture_id": "42", "measurement_count": 2, "pair_score_count": 1}"#

    static let judgmentUploadResponse = #"{"capture_id": "42", "judgment_count": 1}"#

    static let rankedResults = #"""
    {
      "schema_version": "lps-ranked-results/v1",
      "sheet_id": "sheet_1",
      "printer_profile": {
        "printer_make_model": "Research printer",
        "paper_type": "Plain A4",
        "ink_type": "Dye 6-color",
        "icc_profile": null,
        "print_settings": {},
        "driver_name": null,
        "driver_version": null,
        "calibration_date": null,
        "calibration_version": null,
        "notes": null
      },
      "capture_count": 2,
      "latest_capture_at": "2026-07-26T10:00:00Z",
      "earliest_capture_at": "2026-07-25T12:00:00Z",
      "scoring_algorithm_versions": ["lps-distance-v1"],
      "results": [
        {
          "rank": 1,
          "pair_id": "pair_1",
          "scoring_algorithm_version": "lps-distance-v1",
          "row": 0,
          "col": 1,
          "source_colors": {"color_a_hex": "#FF0000", "color_b_hex": "#00FF00"},
          "score": {
            "average": 0.04,
            "latest": 0.05,
            "minimum": 0.03,
            "maximum": 0.06,
            "capture_count": 2,
            "sample_count": 4,
            "algorithm_versions": ["lps-distance-v1"]
          },
          "current_judgment": "near_match",
          "current_judgment_observed_at": "2026-07-26T10:00:00Z",
          "observation_count": 1,
          "latest_observation": {"judgment": "near_match", "observed_at": "2026-07-26T10:00:00Z"},
          "capture_count": 2,
          "latest_capture_at": "2026-07-26T10:00:00Z",
          "earliest_capture_at": "2026-07-25T12:00:00Z"
        }
      ]
    }
    """#

    static let errorResponse = #"{"errors": {"detail": "Sheet not found"}}"#

    static func jsonData(_ fixture: String) -> Data {
        Data(fixture.utf8)
    }

    static func makeMetadata() -> CaptureMetadata {
        CaptureMetadata(
            deviceModel: "iPhone",
            lens: "built_in_wide_angle",
            exposureDurationSeconds: 0.016,
            iso: 100,
            focusLensPosition: 0.42,
            whiteBalanceGains: WhiteBalanceGains(red: 1.2, green: 1.0, blue: 1.4),
            imageWidth: 4032,
            imageHeight: 3024,
            appVersion: "0.1.0",
            timestamp: Date(timeIntervalSince1970: 1_784_980_800)
        )
    }

    static func makeStats() -> ChannelStats {
        let median = RGB(r: 0.12, g: 0.10, b: 0.02)
        return ChannelStats(
            median: median,
            mean: median,
            standardDeviation: RGB(r: 0.01, g: 0.01, b: 0.004),
            min: median,
            max: median,
            sampleCount: 900,
            clippingFraction: 0
        )
    }

    static func makeMeasurement(patchID: String = "pair_1#first", normalized: RGB? = RGB(r: 0.15, g: 0.12, b: 0.02)) -> PatchMeasurement {
        PatchMeasurement(
            patchID: patchID,
            linearRGBMedian: RGB(r: 0.12, g: 0.10, b: 0.02),
            normalizedLinearRGBMedian: normalized,
            stats: makeStats()
        )
    }
}

enum TestRepoLayout {
    static func packageRelative(_ relativePath: String) -> URL {
        let testFile = URL(fileURLWithPath: #filePath)
        let packageRoot = testFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return packageRoot.appendingPathComponent(relativePath)
    }

    static var vendoredSpecURL: URL {
        packageRelative("Sources/ColorMatchingAPI/openapi.json")
    }
}
