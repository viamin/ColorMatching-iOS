# OpenAPI Contract Deltas (issue #5 / `viamin/color_matching#110`)

Findings from comparing `docs/color-matching-api-contract.md` against the real,
machine-readable OpenAPI spec added by `viamin/color_matching#113` (which closed
`viamin/color_matching#110`). The spec is served dynamically at
`GET /api/v1/openapi.json` via `OpenApiSpex.Plug.CastAndValidate`; there is no
static spec file checked into `color_matching` to vendor directly, so fetching
it for client generation means hitting that endpoint (or exporting it) against
a running `color_matching` instance — not available in this sandbox, so this
pass reviewed the Elixir source (`lib/color_matching_web/api_schemas.ex`,
`api_spec.ex`, `router.ex`, and the two controllers) at the PR's merge commit
instead of the rendered JSON.

This is research/evidence for the generated-client migration, not the
migration itself. See `iOS/Tests/ColorMatchingLPSAppTests/APIContractDeltaTests.swift`
for the executable assertions that pin or red-flag the deltas below.

## Deltas vs. the prose contract

- **Measurement upload has no `scoring_algorithm_version` and no per-measurement `stats`.**
  `MeasurementUploadRequest` only defines `measurements[].{patch_id, linear_rgb_median,
  normalized_linear_rgb_median}` and `pair_scores`. The prose doc (and the
  hand-written client) also send a top-level `scoring_algorithm_version` and a
  `stats` object (`sample_count`, `clipping_fraction`, `mean`, `standard_deviation`)
  per measurement. The server doesn't reject extra properties (no
  `additionalProperties: false`), so this isn't a runtime break today, but a
  client generated from the spec has no `stats`/`scoring_algorithm_version`
  properties to populate — these fields need to drop out of the request when
  the generated client lands.
- **`pair_scores[]` scoring is `anyOf(score, similarity, distance)`, not a fixed pair.**
  `PairScoreRequest` requires `pair_id` + `algorithm_version`, plus at least one
  of `score`, `similarity`, or `distance`. The current client always sends both
  `distance` and `similarity` (satisfies the `anyOf` twice over) and never sends
  the generic `score` field; no break, just worth knowing the generated request
  type will model three optional branches rather than two required numbers.
- **Measurement/judgment uploads answer `200 OK` with a JSON body, never `204 No Content`.**
  `CaptureController.upload_measurements` returns `{capture_id, measurement_count,
  pair_score_count}`; `upload_judgments` returns `{capture_id, judgment_count}`.
  The prose doc doesn't document a response at all for either, and the
  hand-written client (`APIClient.uploadMeasurements`/`uploadJudgments`)
  discards the response body entirely, returning `Void`. Once wired to the
  generated client, these calls should surface the decoded confirmation
  payload instead of throwing it away — this is in-repo, fixable work for the
  implementation PR, not an upstream gap.
- **`CaptureRequest` accepts a flat shape as an alternative to nested `metadata`/`quality`.**
  The schema's `anyOf` allows top-level `device_model`/`lens`/etc. fields
  directly on the request body, not just nested under `metadata`. The
  hand-written client's nested `{metadata, quality}` shape satisfies the other
  `anyOf` branch (`required: [:metadata]`), so no change needed, but the flat
  alternative exists if the generated client's request builder prefers it.
- **`linear_rgb_median` / `normalized_linear_rgb_median` accept three shapes.**
  `RgbPayload` is `anyOf(array of numbers, {r,g,b} object, JSON-encoded string)`.
  The hand-written client always sends the object form, which is valid; no
  change forced here, but the generated request type will model all three.
- **Error responses have a real, documented shape.** `ErrorResponse` is
  `{errors: object | [{detail, source: {pointer}}]}`. Neither the prose doc nor
  the hand-written client decode error bodies today (only the HTTP status is
  checked). Out of scope for this migration per the issue's non-goals, but
  worth a follow-up if the app ever wants to surface server validation errors.

## Endpoint gaps discovered

- **No client method exists yet for `GET /api/v1/test_sheets/:sheet_id/ranked_results`.**
  The route, controller action, and `RankedResults` schema all exist
  server-side, and the prose doc describes the intended payload (source
  colors, scores, labels, capture provenance, printer profile, scoring
  algorithm version), but `APIClient` never implemented a call for it — the
  app's "Ranked Pairs" UI currently uses locally computed scores, not a server
  fetch. The generated-client migration should add this call as part of
  closing out the issue's "ranked results" surface.
- **The published spec types `Manifest` and `RankedResults` far more loosely
  than the app needs.** `ApiSchemas.Manifest` only requires/types
  `schema_version`, `sheet_id`, and `capture_profile.scoring_algorithm_version`;
  it says nothing about `page`, `registration_markers`, `patches`, `pairs`,
  `manifest_url`, or `sheet_version`, all of which the app's `SheetManifest`
  model requires non-optionally today (confirmed in
  `APIContractDeltaTests.testManifestPublishedSchemaOnlyGuaranteesScoringAlgorithmVersion`).
  `ApiSchemas.RankedResults` is even thinner: only `schema_version` and
  `sheet_id` are typed, with none of the scores/labels/provenance the prose doc
  promises. A Swift client generated directly from this spec would produce
  manifest/ranked-results response types that are far less useful than the
  current hand-written `SheetManifest`/the richer payload the app actually
  needs — generating those two endpoints "as-is" would be a regression, not an
  upgrade. Closing this gap means either extending the `color_matching` spec
  (a follow-up issue against `viamin/color_matching`, out of scope for this
  non-goal-bound issue) or keeping a hand-authored decode layer on top of the
  generated response for just these two endpoints until the spec catches up.

## Implication for the implementation run

- Surfaces that can swap cleanly to generated types as-is: create capture
  session, upload measurements (once the confirmation response is surfaced),
  upload judgments (ditto), recent sheets.
- Surfaces that need either a spec follow-up or a hand-authored decode shim to
  avoid losing fidelity: test-sheet manifest, ranked results (net new client
  code either way, since no client method exists today).
