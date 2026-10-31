# `color_matching` API Contract For iOS Companion

> **Status: superseded as the source of truth.** `viamin/color_matching#110` now publishes a
> machine-readable OpenAPI 3 spec at `GET /api/v1/openapi.json`; the iOS app generates its
> API layer from a vendored copy of it. See `docs/color-matching-openapi-delta.md` for the
> differences between this prose contract and the published spec.

This contract describes the API that `viamin/color_matching` should expose for the iOS companion app. The implementation belongs in the Phoenix app, not in this repository.

## Authentication

MVP authentication can be a shared bearer token:

```http
Authorization: Bearer <token>
```

For local personal research, `color_matching` may allow unauthenticated requests in development.

## Fetch Sheet Manifest

```http
GET /api/v1/test_sheets/:sheet_id/manifest
```

Response schema version: `lps-sheet-manifest/v1`.

```json
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
    "id": "printer_profile_1",
    "name": "Research printer",
    "paper": "paper name",
    "ink": "ink set",
    "settings": {}
  },
  "capture_profile": {
    "expected_illuminant": "low_pressure_sodium",
    "preferred_camera": "built_in_wide_angle_rear",
    "scoring_algorithm_version": "lps-distance-v1"
  },
  "patches": [
    {
      "id": "patch_1",
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
      "first_patch_id": "patch_1",
      "second_patch_id": "patch_2",
      "source_colors": ["#FF0000", "#00FF00"],
      "grid_row": 0,
      "grid_col": 1
    }
  ]
}
```

Patch roles:

- `pair_color`
- `reference`

Reference roles:

- `white`
- `gray`
- `black`
- `blank_paper`

## Fetch Recent Sheets

```http
GET /api/v1/test_sheets/recent
```

Response:

```json
{
  "sheets": [
    {
      "sheet_id": "sheet_123",
      "manifest_url": "https://example.test/api/v1/test_sheets/sheet_123/manifest",
      "title": "July LPS comparison sheet"
    }
  ]
}
```

`title` may be `null` when the Phoenix app has no display name for the sheet.

## Create Capture Session

```http
POST /api/v1/test_sheets/:sheet_id/captures
Content-Type: application/json
```

```json
{
  "metadata": {
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
  },
  "quality": {
    "detected_marker_count": 4,
    "blur_score": 0.82,
    "rejections": []
  }
}
```

Allowed capture rejection strings:

- `missingRegistrationMarks`
- `incompleteSheetCoverage`
- `clipping`
- `excessiveBlur`
- `glare`
- `poorReferencePatch`

Response:

```json
{"capture_id": "capture_123"}
```

## Upload Measurements And Scores

```http
POST /api/v1/captures/:capture_id/measurements
Content-Type: application/json
```

```json
{
  "scoring_algorithm_version": "lps-distance-v1",
  "measurements": [
    {
      "patch_id": "patch_1",
      "linear_rgb_median": {"r": 0.12, "g": 0.10, "b": 0.02},
      "normalized_linear_rgb_median": {"r": 0.15, "g": 0.12, "b": 0.02},
      "stats": {
        "sample_count": 900,
        "clipping_fraction": 0.0,
        "mean": {"r": 0.12, "g": 0.10, "b": 0.02},
        "standard_deviation": {"r": 0.01, "g": 0.01, "b": 0.004}
      }
    }
  ],
  "pair_scores": [
    {
      "pair_id": "pair_1",
      "distance": 0.035,
      "similarity": 0.965,
      "algorithm_version": "lps-distance-v1"
    }
  ]
}
```

## Upload User Judgments

```http
POST /api/v1/captures/:capture_id/judgments
Content-Type: application/json
```

```json
{
  "judgments": [
    {"pair_id": "pair_1", "judgment": "near_match"}
  ]
}
```

Allowed judgments:

- `match`
- `near_match`
- `no_match`

## Retrieve Ranked Results

```http
GET /api/v1/test_sheets/:sheet_id/ranked_results
```

The Phoenix app should return the latest or aggregate ranked results with source colors, scores, labels, capture provenance, printer profile, and scoring algorithm version.
