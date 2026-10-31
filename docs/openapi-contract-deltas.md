# Contract Deltas: `docs/color-matching-api-contract.md` vs. the Published OpenAPI Spec

Tracking issue: `viamin/ColorMatching-iOS#5` ("Replace hand-written API layer
with a generated OpenAPI Swift client"). Source of truth for this comparison
is `viamin/color_matching#113` (merged, closes `viamin/color_matching#110`),
specifically:

- `lib/color_matching_web/router.ex`
- `lib/color_matching_web/api_spec.ex` / `api_schemas.ex` (the OpenAPI document itself)
- `lib/color_matching_web/controllers/test_sheet_json.ex` (actual manifest/ranked-results rendering)
- `lib/color_matching_web/controllers/capture_controller.ex`
- `lib/color_matching_web/plugs/api_auth.ex`

This environment has no live Phoenix server to hit `GET /api/v1/openapi.json`
directly, so the comparison below is against the merged Elixir source rather
than a captured JSON document. Fetching/vendoring the literal generated
`openapi.json` happens in the implementation PR once the generator and
`Package.swift` changes land (out of scope for this test-only PR).

## Confirmed — no delta

- **Auth**: `Plugs.ApiAuth` is bearer-token-optional when `config :color_matching, :api_token` is unset (dev default) and strictly enforced otherwise. Matches the contract's "shared bearer token... may allow unauthenticated requests in development."
- **Capture ID shape**: `capture_id` is always a string (`Integer.to_string(capture.id)`). Matches.
- **Judgment upload wire shape**: `{"judgments": [{"pair_id", "judgment"}]}`. Matches.
- **`capture_profile`**: `{expected_illuminant, preferred_camera, scoring_algorithm_version}`. Matches the contract example exactly.
- **Recent sheets `title`**: contract says `title` "may be null"; in the current implementation it is **always** `nil` (`render_recent_sheet/1` hardcodes `title: nil` — there's no display-name source yet). Not a shape delta, just stricter than documented today.

## Real deltas found

1. **`printer_profile` field names are completely different from the contract.**
   Contract (`docs/color-matching-api-contract.md`):
   ```json
   {"id": "printer_profile_1", "name": "Research printer", "paper": "paper name", "ink": "ink set", "settings": {}}
   ```
   Actual (`TestSheetJSON.render_printer_profile/1`):
   ```json
   {
     "printer_make_model": "...", "paper_type": "...", "ink_type": "...",
     "icc_profile": null, "print_settings": null, "driver_name": null,
     "driver_version": null, "calibration_date": null, "calibration_version": null,
     "notes": null
   }
   ```
   No `id` field exists at all. The generated client's `PrinterProfile` type must use the real field names; there is nothing to "migrate" on the hand-written side because `SheetManifest` (iOS/Sources/MeasurementCore/Models.swift) never modeled `printer_profile` in the first place — it's silently dropped on decode today (see `ManifestContractDeltaTests`).

2. **`manifest.created_at` and `manifest.printer_profile`/`manifest.capture_profile` are present on the wire but absent from the current Swift `SheetManifest` model.** Codable ignores unrecognized keys, so this doesn't throw — it just means the app has no compile-time signal if the server renames/removes/retypes `capture_profile.scoring_algorithm_version` (the exact enum the whole LPS scoring pipeline is pinned to via `LPSScorer.algorithmVersion`). This is the core "runtime surprise" the issue is about; see the new failing tests in `ManifestContractDeltaTests.swift` that pin the *desired* post-migration behavior (fields must round-trip, not disappear).

3. **The published OpenAPI schemas for `Manifest` and `RankedResults` are much thinner than the actual JSON responses.** `ColorMatchingWeb.ApiSchemas.Manifest` only declares `schema_version`, `sheet_id`, and `capture_profile.scoring_algorithm_version` as typed/required properties — `page`, `registration_markers`, `printer_profile`, `patches`, `pairs`, `created_at`, `sheet_version` are all present at runtime but **undeclared** in the spec. Same story for `RankedResults`: the schema only requires `schema_version` + `sheet_id`, while the real response (`TestSheetJSON.ranked_results/1`) also returns `printer_profile`, `capture_count`, `latest_capture_at`, `earliest_capture_at`, `scoring_algorithm_versions` (plural, an array — not the singular `algorithm_version` the issue description implies), and a `results` array of objects with `rank`, `pair_id`, `source_colors` (an object with `color_a_hex`/`color_b_hex`, not the array of hex strings the prose contract's `pairs[].source_colors` shape might suggest), a nested `score` object, `current_judgment`, `observation_count`, `latest_observation`, etc.
   **Endpoint gap to flag upstream**: generating a Swift client straight from today's spec would produce `Manifest`/`RankedResults` types with almost none of the fields the app actually needs — `viamin/color_matching` needs a follow-up to flesh out these two response schemas before codegen is useful for the sheet/ranked-results surfaces. Captures and recent-sheets schemas are already complete and codegen-ready.

4. **`POST .../captures` request body is more flexible than documented**: `ApiSchemas.CaptureRequest` is `anyOf` two shapes — the nested `{metadata, quality}` shape the contract documents, **or** a flattened shape with `device_model`/`lens`/... directly at the top level alongside `detected_marker_count`/`blur_score`/`rejection_reasons`. The app's hand-written client only ever sends the nested shape, which is one of the two valid `anyOf` branches, so no behavior change is needed — just a note that the generated request type will be a union/either type where the contract implied a single shape.

5. **`POST .../measurements` request schema has no `stats` field and no top-level `scoring_algorithm_version`.**
   Contract's top-level request includes `scoring_algorithm_version` and each measurement includes a `stats` object (`sample_count`, `clipping_fraction`, `mean`, `standard_deviation`). The actual `MeasurementUploadRequest` schema only declares `measurements: [{patch_id, linear_rgb_median, normalized_linear_rgb_median}]` and `pair_scores: [PairScoreRequest]`; `algorithm_version` moved to be **required per pair score** (`PairScoreRequest` requires `pair_id` + `algorithm_version`, and at least one of `score`/`similarity`/`distance`). The app's hand-written client (`APIClient.uploadMeasurements`) still sends the old top-level `scoring_algorithm_version` plus a `stats` object per measurement; neither is declared in the real schema. Since the server schema doesn't set `additionalProperties: false` anywhere observed, these extra fields are not rejected — but they are dead weight the generated client's request type won't have a slot for. Decision needed in the implementation PR: either drop `stats`/top-level `scoring_algorithm_version` from the wire payload (changes capture/scoring *transport*, not scoring *behavior* — `stats` is already computed and kept client-side either way) or extend the server schema. Flagging here per the issue's "any endpoint gaps discovered" ask; not implemented in this PR (non-goal: "changing the app's capture/scoring behavior").

6. **`POST .../measurements` and `POST .../judgments` now have typed response bodies the hand-written client discards.**
   - Measurements: `{capture_id, measurement_count, pair_score_count}`
   - Judgments: `{capture_id, judgment_count}`
   The contract didn't document a response body for either (implying "no body to parse"). `APIClient.uploadMeasurements`/`uploadJudgments` call a `send(_:)` helper that only checks the HTTP status and throws the body away. A generated client will produce typed response structs for these; wiring the app to actually read `measurement_count`/`pair_score_count`/`judgment_count` (e.g. for upload confirmation UI) is a product decision for the implementation PR, not required for parity.

## Not in scope for the iOS app (confirmed via `router.ex`)

`/api/v1/printer_profiles`, `/api/v1/printer_profiles/:id/colors`, `/api/v1/printer_profiles/:id/metamer_pairs`, `/api/v1/palettes`, `/api/v1/colors`, and the un-versioned `/api/illuminant_measurements(/bulk)` + `/api/multi_image_mapping` routes exist in `color_matching` but are consumed by the macOS app's `PaletteAPIClient`, not this iOS companion. Excluded from client generation per the issue's listed surfaces (manifest, recent sheets, capture creation, measurement upload, judgment upload, ranked results).

## What this means for the implementation PR

- Vendor the real `GET /api/v1/openapi.json` document (not hand-transcribed) once a running `color_matching` instance is available to the implementation run.
- Before wiring `swift-openapi-generator`, either get `Manifest`/`RankedResults` schemas fleshed out upstream (preferred — makes the generated types actually useful) or accept generating thin types now and layering a hand-written decode step on top for the undeclared fields (defeats much of the point of codegen for those two endpoints specifically).
- The two tests added in this PR (`ManifestContractDeltaTests`) encode the minimum bar: whatever model replaces `SheetManifest`, it must not silently drop `printer_profile` or `capture_profile.scoring_algorithm_version` the way the current hand-written `Codable` struct does.
