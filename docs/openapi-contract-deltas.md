# OpenAPI Contract Deltas: Prose Doc vs. Published Spec

Tracks differences between `docs/color-matching-api-contract.md` (the
hand-written prose contract this repo maintained) and the machine-readable
OpenAPI 3 spec that `viamin/color_matching` now serves at
`GET /api/v1/openapi.json` (published in viamin/color_matching#113, closing
viamin/color_matching#110).

This repo has no way to run the Phoenix app (no database/service
infrastructure in this environment), so the spec's JSON body could not be
fetched live. The findings below come from reading the merged source for
PR 113 directly: `lib/color_matching_web/api_spec.ex`,
`lib/color_matching_web/api_schemas.ex`, `lib/color_matching_web/router.ex`,
and `test/color_matching_web/controllers/open_api_controller_test.exs`. The
generated-client implementation work (#5) should re-derive this list from
the live `/api/v1/openapi.json` response and fetch the document itself
rather than trust this snapshot.

## Deltas relevant to the iOS app's current surfaces

- **`CaptureMetadata.image_width` / `image_height` are required by the real
  schema.** The prose contract's example always includes them, but this
  app's `CaptureMetadata` (`iOS/Sources/ColorMatchingLPSAppCore/APIClient.swift`)
  declares both as `Int?`. A capture encoded with either `nil` silently
  omits the key (Swift's synthesized `Encodable` uses `encodeIfPresent` for
  `Optional` properties) and would fail the real API's required-field
  validation at request time instead of compile time — exactly the failure
  mode this issue exists to close. Covered by a new test:
  `CaptureMetadataContractTests.swift`.
- **Measurement/judgment upload responses carry a body the app discards.**
  The real schema defines `MeasurementUploadResponse`
  (`capture_id`, `measurement_count`, `pair_score_count`) and
  `JudgmentUploadResponse` (`capture_id`, `judgment_count`). The prose
  contract didn't document any response for these two endpoints, and
  `APIClient.uploadMeasurements` / `uploadJudgments` both return `Void`,
  dropping the body entirely. Worth deciding whether the generated client
  should surface these counts (e.g., for upload confirmation UI) when #5
  lands.
- **`MeasurementUploadRequest`'s top-level `scoring_algorithm_version` field
  isn't part of the published schema.** The real schema only types
  `measurements` and `pair_scores` at the top level; the algorithm version
  lives per-pair-score on `PairScoreRequest.algorithm_version` (required
  there). This app's `uploadMeasurements` still sends a redundant top-level
  `scoring_algorithm_version` key (harmless today since the schema has no
  `additionalProperties: false`, but it won't have a generated property to
  populate once the client is typed).
- **`PairScoreRequest` accepts a generic `score` field, not just
  `similarity`/`distance`.** Required: `pair_id`, `algorithm_version`, plus
  `anyOf` one of `score` / `similarity` / `distance`. The prose contract's
  example only showed `distance` + `similarity` together, which still
  satisfies two of the three `anyOf` branches, but didn't mention `score`
  as a valid alternative.
- **`RgbPayload` (measurement RGB fields) is looser than documented.** The
  real schema is `anyOf` an array of numbers, an object with `r`/`g`/`b`
  numbers, or a plain string — not just the single object-of-doubles shape
  the prose doc and this app's `RGB` Codable type assume. This app's
  encoding (object of doubles) is one of the three valid shapes, so this
  isn't a break, just a looser contract than documented.
- **Error responses are now formally typed.** `ApiErrorResponse.errors` is
  `oneOf` an arbitrary object or an array of
  `{detail, source: {pointer}}`. The prose contract never documented error
  shapes; the generated client integration should decide how (or whether)
  to surface typed error decoding.

## Manifest and ranked-results schemas are far thinner than the prose contract

This is the most significant gap for #5: the published `Manifest` schema
(`ColorMatchingWeb.ApiSchemas.Manifest`) only types and requires
`schema_version`, `sheet_id`, and `capture_profile.scoring_algorithm_version`.
It does **not** type `sheet_version`, `manifest_url`, `page`,
`registration_markers`, `patches`, `pairs`, or `printer_profile` — the exact
fields this app's `SheetManifest` model (`iOS/Sources/MeasurementCore/Models.swift`)
relies on for rendering the sheet and driving sampling. Likewise
`RankedResults` only types `schema_version` and `sheet_id`.

Generating a Swift client straight from this spec as published would give
the app a typed `schema_version`/`sheet_id`/`capture_profile` and leave
everything else as untyped `additionalProperties` — losing exactly the type
safety this issue is meant to add for the fields the app actually samples
against. Before (or alongside) generating the client, either:

1. File a follow-up against `viamin/color_matching` to type the remaining
   `Manifest`/`RankedResults` fields in the OpenAPI schema, or
2. Accept untyped `additionalProperties` for those fields in the generated
   client and keep a thin hand-written decode layer on top for `page`,
   `registration_markers`, `patches`, and `pairs` — which only partially
   satisfies the issue's goal of replacing hand-written models.

## Confirmed as matching (no delta)

- Bearer-token auth (`bearerAuth`, HTTP bearer scheme) on the `:api_auth`
  pipeline, as the prose doc assumed.
- `POST /api/v1/test_sheets/:sheet_id/captures` accepts the nested
  `{metadata, quality}` shape this app sends (one of the request's two
  `anyOf` branches); `CaptureCreatedResponse` (`capture_id`) matches both
  the prose doc and current decoding.
- `/api/v1/printer_profiles*`, `/api/v1/palettes`, `/api/v1/colors`,
  `/api/v1/printer_profiles/:id/metamer_pairs`, `/api/illuminant_measurements*`,
  and `/api/multi_image_mapping` all exist in the real spec but belong to
  the macOS app's `PaletteAPIClient`, not this app's surfaces — out of
  scope per issue #5's non-goals.

## Open item for the implementation run

This analysis was done without the ability to add `swift-openapi-generator`
/ `swift-openapi-runtime` to `iOS/Package.swift` or vendor the spec
document, because this run is scoped to tests and documentation only (see
commit history on this branch). The implementation run should:

1. Fetch the live `/api/v1/openapi.json` document (not just this reading of
   the source) and confirm the deltas above still hold.
2. Decide the Manifest/RankedResults typing gap above before wiring the
   generated client into `SheetManifest`'s call sites.
