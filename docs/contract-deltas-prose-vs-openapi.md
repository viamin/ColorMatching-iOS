# Contract Deltas: Prose Contract vs Published OpenAPI Spec

Comparison of `docs/color-matching-api-contract.md` (the hand-written prose
contract this app was built against) with the OpenAPI 3 document published by
[viamin/color_matching#110](https://github.com/viamin/color_matching/issues/110)
(served at `GET /api/v1/openapi.json`; reconstruction snapshot at
`docs/openapi-vendoring-source.json`, upstream HEAD 2026-10-31).

This is the source material for issue #5's PR-description deliverable:
"what changed between the prose contract and the published spec, and any
endpoint gaps discovered".

## Confirmed unchanged

- Paths for all six surfaces the app uses (`/api/v1/test_sheets/recent`,
  `.../manifest`, `.../ranked_results`, `.../captures`,
  `/api/v1/captures/{capture_id}/measurements`, `.../judgments`).
- Bearer-token authentication (`components.securitySchemes.bearerAuth`,
  `type: http`, `scheme: bearer`) on every app-facing operation.
- Capture creation accepts the prose contract's nested
  `{metadata: {...}, quality: {...}}` request form and answers
  `201 {"capture_id": "..."}`.
- Recent sheets shape (`sheets[]` of `{sheet_id, manifest_url, title}`).
- Capture metadata field names (`device_model`, `lens`,
  `exposure_duration_seconds`, `iso`, `focus_lens_position`,
  `white_balance_gains`, `image_width`, `image_height`, `app_version`,
  `timestamp` date-time) and the nested quality block
  (`detected_marker_count`, `blur_score`, `rejections`).
- Compatibility markers are now machine-visible: `schema_version` enum
  `lps-sheet-manifest/v1` and `capture_profile.scoring_algorithm_version` enum
  `lps-distance-v1` (the spec also pins a new `lps-ranked-results/v1`).

## Deltas the app must adopt

| # | Area | Prose contract | Published spec |
| --- | --- | --- | --- |
| D1 | Measurement upload response | Fire-and-forget implied; the hand-written client tolerates `204` with empty body | `200` with `{"capture_id", "measurement_count", "pair_score_count"}` (all required). No `204` documented |
| D2 | Judgment upload response | Same fire-and-forget assumption | `200` with `{"capture_id", "judgment_count"}` (required) |
| D3 | Scoring version placement | Top-level `scoring_algorithm_version` in the measurement upload body | Top-level field **gone**; each `pair_scores[]` item requires its own `algorithm_version` |
| D4 | Pair score payload | `{pair_id, distance, similarity, algorithm_version}` (both values always sent) | `pair_id` + `algorithm_version` required, plus an `anyOf` requiring at least one of `score` / `similarity` / `distance` (a direct `score` value is new) |
| D5 | Per-measurement stats | `stats: {sample_count, clipping_fraction, mean, standard_deviation}` | **Not declared** — the stats block is an endpoint gap (see below) |
| D6 | RGB payloads | Fixed object `{r, g, b}` | `RgbPayload` `anyOf`: number array, `{r,g,b}` object, or string |
| D7 | `normalized_linear_rgb_median` | Optional | **Required** on every measurement |
| D8 | Manifest schema | Full manifest documented (page, registration_markers, printer_profile, patches, pairs, ...) | Declares only `schema_version`, `sheet_id`, `capture_profile{scoring_algorithm_version}` — the server still renders the full payload, but the spec (and therefore the generated type) does not carry it |
| D9 | Ranked results | No schema at all ("latest or aggregate ranked results with source colors, scores, labels, capture provenance, printer profile, and scoring algorithm version") | Declares `schema_version` (`lps-ranked-results/v1`) + `sheet_id` only; actual payload adds `printer_profile`, `capture_count`, `latest/earliest_capture_at`, `scoring_algorithm_versions[]`, `results[]` (rank, pair_id, scoring_algorithm_version, row, col, source_colors{color_a_hex,color_b_hex}, score{average,latest,minimum,maximum,capture_count,sample_count,algorithm_versions}, current_judgment, current_judgment_observed_at, observation_count, latest_observation, capture_count, latest/earliest_capture_at) |
| D10 | Capture request forms | Nested `{metadata, quality}` only | Nested form kept, plus a flat compatibility form whose keys differ from prose: `exposure_duration` (not `exposure_duration_seconds`) and `rejection_reasons` (not `rejections`) |
| D11 | Judgment values | Enumerated (`match`, `near_match`, `no_match`) | Unconstrained string (no enum declared) |
| D12 | Recent-sheets `title` | "may be `null`" | Required-but-nullable; the server currently always renders `title: null` |
| D13 | IDs | Examples imply opaque ids (`sheet_123`, `patch_1`, `capture_123`) | `sheet_id` is the sheet's lookup code; manifest patch ids are `"{pair_id}#first"` / `"{pair_id}#second"`; `capture_id` responses stringify integer DB ids. Patch ids must stay opaque to the client |

## Endpoint gaps discovered

Spec surfaces the app does **not** use today (all bearer-auth protected):

- `GET /api/v1/printer_profiles`
- `GET /api/v1/printer_profiles/{printer_profile_id}/colors`
- `GET /api/v1/printer_profiles/{printer_profile_id}/metamer_pairs`
- `GET /api/v1/palettes`
- `GET /api/v1/colors` (query params: `printer_profile_id` required, `palette_id` optional)

Previously-undocumented-anywhere surfaces now folded into the spec by #110:

- `POST /api/illuminant_measurements`
- `POST /api/illuminant_measurements/bulk`
- `POST /api/multi_image_mapping` (JSON in, PNG out — the only non-JSON app-level response)

Undeclared-but-rendered payload fields (spec-side gaps to raise upstream, from
the controllers' renderers):

- Manifest: everything beyond `schema_version` / `sheet_id` / `capture_profile`
  (D8) — blocks the generated client from carrying `patches`/`pairs`, which
  `MeasurementCore.SheetAnalyzer` needs.
- Ranked results: everything beyond `schema_version` / `sheet_id` (D9).
- Measurement upload: the `stats` block (D5).
- Judgments: the allowed-value enum (D11).

Unsupported methods on the documented `/api/v1` read endpoints return `405`
with an `Allow` header (a `MethodNotAllowedController` route), which the prose
contract never mentioned.

## Practical consequences for the app

1. The generated measurement-upload call must send per-score
   `algorithm_version` (from `LPSScorer.algorithmVersion`) and must not expect
   a `204`; it gets counts back.
2. The manifest fetch needs a strategy for the undeclared fields (see the
   risks section of `docs/openapi-generated-client-plan.md`) until upstream
   declares them.
3. Upload facades should surface the counting bodies (useful telemetry: the
   server now echoes how many rows it accepted).
4. Patch-id handling must treat `"{pair_id}#side"` as opaque (D13).
