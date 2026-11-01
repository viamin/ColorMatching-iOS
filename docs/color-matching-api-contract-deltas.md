# Contract Deltas: Prose Doc vs. The Real `color_matching` API

This records what differs between `docs/color-matching-api-contract.md` (the
hand-written prose contract) and the real API as implemented in
`viamin/color_matching` today, found while scoping #5 ("Replace hand-written
API layer with a generated OpenAPI Swift client").

## Why this doc exists instead of a vendored spec file

viamin/color_matching#110 ("publish a machine-readable OpenAPI spec") is
closed, merged via viamin/color_matching#113. It added `open_api_spex`-based
specs (`lib/color_matching_web/api_spec.ex`, `api_schemas.ex`) and a
`GET /api/v1/openapi.json` route that renders the spec **at runtime**
(`OpenApiSpex.Plug.RenderSpec`). The spec is generated from Elixir code, not
checked into the repo as a static YAML/JSON file.

Fetching or vendoring the actual document (the first deliverable of #5)
therefore requires a running `color_matching` instance to hit that endpoint.
This sandbox has no database and cannot run the Phoenix app, and has no Swift
toolchain installed (confirmed: no `swift` binary, no apt/snap package;
downloading the official Linux toolchain tarball exhausted this container's
1 GB `/tmp` and was aborted and cleaned up rather than risk destabilizing the
environment further). Both the spec-fetch and the `swift-openapi-generator`
wiring are implementation work blocked on that infrastructure, and are out of
scope for this test-and-docs-only pass. This doc instead captures the deltas
by reading the real router/controllers/schemas directly, as a drop-in input
for the PR description once generation is unblocked.

Sources read (via the public GitHub REST/raw API, `main` branch):
`lib/color_matching_web/router.ex`, `api_spec.ex`, `api_schemas.ex`,
`controllers/capture_controller.ex`, `controllers/test_sheet_controller.ex`,
`controllers/test_sheet_json.ex`, `plugs/api_auth.ex`,
`lib/color_matching/ranked_results.ex`.

## Deltas found

1. **`printer_profile` shape is completely different.** Prose contract:
   `{id, name, paper, ink, settings}`. Real shape (`TestSheetJSON.render_printer_profile/1`,
   used by both the manifest and ranked-results responses):
   `{printer_make_model, paper_type, ink_type, icc_profile, print_settings,
   driver_name, driver_version, calibration_date, calibration_version, notes}`.
   No `id`, no `name`; every other field is renamed, and five fields are new.
   `MeasurementCore.SheetManifest` has no `printerProfile` property at all
   today, so this data is silently dropped on decode (see
   `RealServerContractFixtureTests.testSheetManifestModelDoesNotYetExposePrinterOrCaptureProfile`).

2. **`capture_profile` is sent but never decoded.** The real manifest
   includes `capture_profile: {expected_illuminant, preferred_camera,
   scoring_algorithm_version}` exactly as documented, but `SheetManifest` has
   no field for it, so it's dropped the same way as `printer_profile`.

3. **Measurement upload request: extra fields the app sends are not part of
   the real schema.** The real `MeasurementUploadRequest` schema's
   measurement items are only `{patch_id, linear_rgb_median,
   normalized_linear_rgb_median}` — there is no `stats` field. There is also
   no top-level `scoring_algorithm_version`; algorithm version instead
   travels per pair-score (`pair_scores[].algorithm_version`, which the app
   already sends). Because the real schema doesn't set
   `additionalProperties: false`, the app's current extra `stats` /
   top-level `scoring_algorithm_version` fields are tolerated, not rejected —
   but a generated client built strictly from the spec won't have a `stats`
   field to populate, so that data (sample count, clipping fraction, mean,
   standard deviation) has nowhere to go without a server-side schema change.

4. **`linear_rgb_median` / `normalized_linear_rgb_median` accept more shapes
   than the app uses.** Real schema (`RgbPayload`) is `anyOf` an array
   `[r, g, b]`, an object `{r, g, b}`, or a string. The app only ever sends
   the object form, which is valid but is one of three accepted encodings.

5. **`pair_scores[]` accepts a plain `score` field.** Real
   `PairScoreRequest` requires `pair_id` + `algorithm_version`, plus one of
   `score` / `similarity` / `distance`. The prose contract and the app only
   use `distance` + `similarity`; `score` is undocumented and unused.

6. **Measurement and judgment upload responses are no longer empty-bodied.**
   The prose contract documents no response body for either upload endpoint,
   and `APIClient.uploadMeasurements` / `uploadJudgments` discard the
   response entirely. The real API now returns:
   - `POST .../measurements` → `{capture_id, measurement_count, pair_score_count}`
   - `POST .../judgments` → `{capture_id, judgment_count}`

7. **Capture creation accepts two request shapes.** The real `CaptureRequest`
   schema is `anyOf` a flat top-level shape (`device_model`, `lens`, …) or
   the nested `{metadata: {...}, quality: {...}}` shape. The prose contract
   and the app only use the nested form, which is valid but is one of two
   accepted encodings.

8. **A formal error response shape now exists** (`ErrorResponse`):
   `{errors: <object, e.g. {detail}> | [{detail, source: {pointer}}]}`. Not
   documented in the prose contract at all. `APIError` on the Swift side has
   only a single `.badStatus` case with no parsed detail — failures carry no
   diagnostic information today.

9. **Ranked results has a concrete, much richer shape** than the prose
   contract's vague description ("latest or aggregate ranked results with
   source colors, scores, labels, capture provenance, printer profile, and
   scoring algorithm version"). Real shape (`TestSheetJSON.ranked_results/1`
   + `ColorMatching.RankedResults`):
   ```json
   {
     "schema_version": "lps-ranked-results/v1",
     "sheet_id": "...",
     "printer_profile": { "...": "see #1" },
     "capture_count": 3,
     "latest_capture_at": "...",
     "earliest_capture_at": "...",
     "scoring_algorithm_versions": ["lps-distance-v1"],
     "results": [
       {
         "rank": 1,
         "pair_id": "pair_1",
         "scoring_algorithm_version": "lps-distance-v1",
         "row": 0, "col": 1,
         "source_colors": {"color_a_hex": "#FF0000", "color_b_hex": "#00FF00"},
         "score": {
           "average": 0.035, "latest": 0.03, "minimum": 0.02, "maximum": 0.05,
           "capture_count": 3, "sample_count": 3,
           "algorithm_versions": ["lps-distance-v1"]
         },
         "current_judgment": "near_match",
         "current_judgment_observed_at": "...",
         "observation_count": 1,
         "latest_observation": {"judgment": "near_match", "observed_at": "..."},
         "capture_count": 3,
         "latest_capture_at": "...",
         "earliest_capture_at": "..."
       }
     ]
   }
   ```
   This is a **functional gap**, not just a shape mismatch: the app has no
   model and no `APIClient` method for this endpoint at all today.

10. **New, previously-undocumented endpoint:** `GET /api/v1/openapi.json`
    (no auth pipeline applied) — the actual machine-readable contract this
    whole issue is about.

11. **Auth is fully optional server-side**, not just "may allow
    unauthenticated requests... for local personal research" as the prose
    contract hints: `ColorMatchingWeb.Plugs.ApiAuth` allows every request
    through unless `config :color_matching, :api_token` is set to a non-empty
    string, with no distinction between environments. A rejected request
    gets `401` with `{"errors": {"detail": "Unauthorized"}}` (shape now
    covered by #8), which isn't specified in the prose contract either.

12. **Endpoints that exist but are out of scope for this app:**
    `/api/v1/printer_profiles`, `/api/v1/printer_profiles/:id/colors`,
    `/api/v1/printer_profiles/:id/metamer_pairs`, `/api/v1/palettes`,
    `/api/v1/colors`, `/api/illuminant_measurements`,
    `/api/illuminant_measurements/bulk`, `/api/multi_image_mapping`. These
    back the companion macOS app's `PaletteAPIClient`, not this app — no
    client surface needed here (consistent with the issue's non-goals).

## Endpoints this app uses that match the prose contract as-is

- `GET /api/v1/test_sheets/recent` — `{sheets: [{sheet_id, manifest_url,
  title}]}` matches exactly (`title` is always `null` server-side today,
  consistent with "`title` may be `null`").
- `POST /api/v1/test_sheets/:sheet_id/captures` response —
  `{"capture_id": "..."}` matches exactly.
- Manifest `patches` / `pairs` / `page` / `registration_markers` shapes match
  exactly.

## Follow-up work this unblocks (not done in this pass)

- Fetch/vendor the real OpenAPI document by running `color_matching` locally
  (or from a committed snapshot, if one is added upstream) and wire
  `swift-openapi-generator` + `swift-openapi-runtime` into `iOS/Package.swift`.
- Replace `SheetManifest`'s missing `printer_profile` / `capture_profile`
  decoding, and add a ranked-results client method, using the generated
  types once available.
- Decide whether to keep sending the extra `stats` / top-level
  `scoring_algorithm_version` fields (harmless today, but worth raising
  upstream as a schema gap if that per-measurement detail should be
  queryable later) or drop them.
