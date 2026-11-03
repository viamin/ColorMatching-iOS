import Foundation

/// Canned server payloads used by the API tests.
///
/// The payloads mirror what `viamin/color_matching` actually renders for the
/// `/api/v1` endpoints the companion app talks to, so a stubbed exchange is
/// shaped like a real exchange.
enum APIFixtures {
    /// `GET /api/v1/test_sheets/{sheet_id}/manifest` response.
    static let manifest = """
    {
      "schema_version": "lps-sheet-manifest/v1",
      "sheet_id": "sheet_123",
      "sheet_version": "lps-letter-grid-v1",
      "manifest_url": "https://example.test/api/v1/test_sheets/sheet_123/manifest",
      "created_at": "2026-07-25T12:00:00Z",
      "page": {"units": "mm", "width": 215.9, "height": 279.4},
      "registration_markers": [
        {"role": "top_left", "shape": "solid_square", "rect": {"x": 12, "y": 12, "width": 8, "height": 8}},
        {"role": "top_right", "shape": "solid_square", "rect": {"x": 195.9, "y": 12, "width": 8, "height": 8}}
      ],
      "printer_profile": {
        "printer_make_model": "Research printer",
        "paper_type": "paper name",
        "ink_type": "ink set",
        "print_settings": {}
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
          "rect": {"x": 32, "y": 38, "width": 16, "height": 10}
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
    """

    /// `GET /api/v1/test_sheets/recent` response.
    static let recentSheets = """
    {
      "sheets": [
        {
          "sheet_id": "sheet_123",
          "manifest_url": "https://example.test/api/v1/test_sheets/sheet_123/manifest",
          "title": null
        }
      ]
    }
    """

    /// Capture metadata as the companion app records it for a still frame.
    static let captureMetadata = """
    {
      "device_model": "iPhone",
      "lens": "built_in_wide_angle",
      "exposure_duration_seconds": 0.016,
      "iso": 100,
      "focus_lens_position": 0.42,
      "white_balance_gains": {"red": 1.2, "green": 1.0, "blue": 1.4},
      "image_width": 4032,
      "image_height": 3024,
      "app_version": "0.1.0",
      "timestamp": "2026-07-25T12:00:00Z"
    }
    """

    /// A single user judgment for the pair `pair_1`.
    static let judgments = """
    [
      {"pair_id": "pair_1", "judgment": "near_match"}
    ]
    """

    /// `GET /api/v1/test_sheets/{sheet_id}/ranked_results` response.
    static let rankedResults = """
    {
      "schema_version": "lps-ranked-results/v1",
      "sheet_id": "sheet_123",
      "printer_profile": {
        "printer_make_model": "Research printer",
        "paper_type": "paper name",
        "ink_type": "ink set"
      },
      "capture_count": 1,
      "latest_capture_at": "2026-07-25T12:00:00Z",
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
            "average": 0.965,
            "latest": 0.965,
            "minimum": 0.965,
            "maximum": 0.965,
            "capture_count": 1,
            "sample_count": 1,
            "algorithm_versions": ["lps-distance-v1"]
          },
          "current_judgment": "near_match",
          "current_judgment_observed_at": "2026-07-25T12:05:00Z",
          "observation_count": 1,
          "latest_observation": {"judgment": "near_match", "observed_at": "2026-07-25T12:05:00Z"},
          "capture_count": 1,
          "latest_capture_at": "2026-07-25T12:00:00Z",
          "earliest_capture_at": "2026-07-25T12:00:00Z"
        }
      ]
    }
    """
}
