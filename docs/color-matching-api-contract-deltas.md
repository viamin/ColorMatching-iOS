# Contract Deltas: Prose Doc vs. Published OpenAPI Spec

Source for this comparison: `viamin/color_matching` PR
[#113](https://github.com/viamin/color_matching/pull/113), which closed
[viamin/color_matching#110](https://github.com/viamin/color_matching/issues/110)
("Publish OpenAPI 3 spec for the `/api/v1` API and enforce it in CI"). Reviewed at
commit `05062f5381a6f76413cc2bdf1cb2cc08a1b70ff7`:
`lib/color_matching_web/api_schemas.ex`, `api_spec.ex`, `router.ex`,
`controllers/{test_sheet_controller,capture_controller,test_sheet_json}.ex`.

This file exists so the contract deltas found while investigating issue #5
("Replace hand-written API layer with a generated OpenAPI Swift client")
survive into that PR's description. The actual generator wiring
(`swift-openapi-generator`/`swift-openapi-runtime` dependency, vendored spec,
generated types) is implementation work and is **not** part of this
test-writing run; see the tests below for what's pinned so far.

## Confirmed matches (no delta)

- All five route paths/methods this app uses match
  `docs/color-matching-api-contract.md` exactly: `GET
  /api/v1/test_sheets/:sheet_id/manifest`, `GET /api/v1/test_sheets/recent`,
  `GET /api/v1/test_sheets/:sheet_id/ranked_results`, `POST
  /api/v1/test_sheets/:sheet_id/captures`, `POST
  /api/v1/captures/:capture_id/measurements`, `POST
  /api/v1/captures/:capture_id/judgments`.
- Bearer-token auth (`bearerAuth` HTTP scheme) matches the prose doc.
- `CaptureCreatedResponse` (`{capture_id}`), `RecentSheetsResponse`
  (`{sheets: [{sheet_id, manifest_url, title}]}`), and the nested
  `{metadata, quality}` capture-request shape (including
  `detected_marker_count`/`blur_score`/`rejections` key names) all match the
  hand-written models in `ColorMatchingLPSAppCore/APIClient.swift`.
- `PairScoreRequest`'s per-score `algorithm_version` key matches
  `PairScore.algorithmVersion`'s existing `"algorithm_version"` coding key.

## Deltas found

1. **`printer_profile` field names are completely different from the prose
   doc.** The prose doc shows `{id, name, paper, ink, settings}`. The real
   server (`TestSheetJSON.render_printer_profile/1`) renders
   `{printer_make_model, paper_type, ink_type, icc_profile, print_settings,
   driver_name, driver_version, calibration_date, calibration_version,
   notes}` — there is no numeric `id` at all. Any generated/hand-written
   model built from the prose doc would fail to decode the real field names.

2. **The published `Manifest` and `RankedResults` OpenAPI schemas are
   under-specified relative to what the server actually renders.** Both
   schemas in `api_schemas.ex` only formally declare the
   compatibility-critical fields (`schema_version`, `sheet_id`, and for
   `Manifest`, `capture_profile.scoring_algorithm_version`). `page`,
   `registration_markers`, `patches`, `pairs`, and `printer_profile` on the
   manifest, and the entire `results[]`/`score`/`printer_profile` shape on
   ranked results, are present in the live JSON (`TestSheetJSON.manifest/1`,
   `TestSheetJSON.ranked_results/1`) but absent from the schema's
   `properties`. A client generated strictly from the published spec will
   only get typed access to the compatibility fields; everything else needs
   either follow-up schema work in `color_matching` or a hand-rolled
   decode path layered on top of the generated types. **Gap to raise against
   `viamin/color_matching#110`'s follow-up, not something this repo can fix
   alone.**

3. **`ranked_results` has no client-side implementation at all today** — no
   method on `APIClient`, no response model — despite being one of the five
   surfaces this app is supposed to use per the prose doc and issue #5's
   deliverables. The real response shape, now concrete thanks to
   `TestSheetJSON.ranked_results/1`, is:
   `{schema_version, sheet_id, printer_profile, capture_count,
   latest_capture_at, earliest_capture_at, scoring_algorithm_versions: [...],
   results: [{rank, pair_id, scoring_algorithm_version, row, col,
   source_colors: {color_a_hex, color_b_hex}, score: {average, latest,
   minimum, maximum, capture_count, sample_count, algorithm_versions},
   current_judgment, current_judgment_observed_at, observation_count,
   latest_observation: {judgment, observed_at} | null, capture_count,
   latest_capture_at, earliest_capture_at}]}`. This is a materially richer
   (and differently shaped) payload than the prose doc's one-line
   description. Building this out is in scope for the implementation PR.

4. **`MeasurementUploadRequest` has no top-level `scoring_algorithm_version`
   in the published schema** — only `measurements` and `pair_scores`. Version
   compatibility for measurement uploads is carried per pair score via
   `algorithm_version` (which `PairScore` already encodes correctly). The
   hand-written `APIClient.uploadMeasurements` still sends a redundant,
   schema-non-conformant top-level `scoring_algorithm_version` key, following
   the (now outdated) prose contract. Pinned by
   `MeasurementUploadContractDeltaTests.testUploadMeasurementsBodyMatchesPublishedSchemaKeys`
   (currently failing — see below).

5. **Measurement/judgment upload responses have a body the app discards.**
   The prose doc doesn't document a response body for either upload
   endpoint. The real server returns `200` with
   `{capture_id, measurement_count, pair_score_count}` (measurements) or
   `{capture_id, judgment_count}` (judgments). `APIClient.uploadMeasurements`
   / `uploadJudgments` both call a `send()` helper that discards the response
   body entirely. Not a correctness bug (nothing today depends on those
   counts), but the generated client will decode them, so the implementation
   PR should decide whether to surface them.

6. **`CaptureRequest` accepts a flat alternative shape** in addition to the
   nested `{metadata, quality}` form this app already sends (`anyOf` in the
   schema). The flat form uses `exposure_duration` (not
   `exposure_duration_seconds`) and `rejection_reasons` (not
   `quality.rejections`). Not a break — the nested form the app uses is the
   other `anyOf` branch — but worth knowing the server is more permissive
   than the prose doc implies.

7. **`RgbPayload` (measurement upload RGB fields) is polymorphic**: `anyOf`
   array-of-numbers, `{r, g, b}` object, or string. The app already sends the
   object form, which is valid, but a strict generated client will likely
   model this as a `oneOf`/`anyOf` case type rather than a plain struct —
   something to account for when replacing `RGB` in request bodies (response
   bodies, e.g. palette colors, use a separate integer-typed `Rgb` schema
   this app doesn't consume).

8. Two endpoints in the published spec
   (`POST /api/illuminant_measurements[/bulk]`, `POST
   /multi_image_mapping`) are out of scope for this app (serve the macOS
   `PaletteAPIClient` consumer) — confirmed no missing surface here.

## What's pinned by tests so far

- `iOS/Tests/ColorMatchingLPSAppTests/ManifestContractDeltaTests.swift` pins
  delta #1/#2 (manifest side): decodes a manifest fixture built from the real
  `TestSheetJSON.manifest/1` shape and asserts `capture_profile` and
  `printer_profile` survive a decode/re-encode round trip through
  `SheetManifest`. Both assertions currently fail — `SheetManifest` has no
  `captureProfile`/`printerProfile` property, so the compatibility-critical
  `scoring_algorithm_version` and all printer-profile data are silently
  dropped.
- `iOS/Tests/ColorMatchingLPSAppTests/MeasurementUploadContractDeltaTests.swift`
  pins delta #4: asserts the measurement-upload request body's top-level
  keys equal exactly `{measurements, pair_scores}` per the published schema.
  Currently fails because the client also sends `scoring_algorithm_version`.

Deltas #3 (ranked results has no client implementation), #5 (response
bodies discarded), #6/#7 (server-side permissiveness not exercised by this
client) aren't expressible as a compiling, assertion-level Swift test without
adding the missing methods/properties themselves (implementation, not
permitted in this test-writing run) — they're recorded here instead so they
carry into the implementation PR's description.
