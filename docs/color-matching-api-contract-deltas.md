# Contract Deltas: Prose Contract vs Published OpenAPI Spec

Tracking doc for #5 ("Replace hand-written API layer with a generated OpenAPI Swift
client"). Captures what changed between `docs/color-matching-api-contract.md` (the
hand-written prose contract this app was built against) and the real `/api/v1` API as
published by `viamin/color_matching` once `viamin/color_matching#110` closed. Intended
to be folded into the PR description for the implementation PR, per the issue's exit
criteria.

## Dependency status

`viamin/color_matching#110` ("Publish OpenAPI 3 spec for the /api/v1 API and enforce it
in CI (Schemathesis + oasdiff)") is **closed as completed**, via `viamin/color_matching#113`
(merged). The spec is served at `GET /api/v1/openapi.json` by an `OpenApiController`, built
from `OpenApiSpex` schema modules in `lib/color_matching_web/api_schemas.ex`. There is no
static spec file checked into that repo — it's generated at runtime from the Phoenix router
and `ApiSchemas` module — so fetching/vendoring the document for the iOS package requires
either a reachable `color_matching` instance or running that repo's `mix` task that dumps the
spec to a file. Neither was available in this sandbox (no network path to a live
`color_matching` server, no Elixir/Phoenix toolchain, and the GitHub API proxy available here
only permits calls against this repo, not `viamin/color_matching`). **This blocks actually
vendoring the OpenAPI document and generating the client** — that step needs to happen in an
environment with access to a running `color_matching` instance or a checkout of that repo.

The schema/route details below were recovered by reading the merged PR and the
`api_schemas.ex` / `router.ex` / `plugs/api_auth.ex` source on GitHub.

## Real routes under `/api/v1` and `/api`

Authenticated (`[:api, :api_auth]`):
- `GET /api/v1/test_sheets/recent` — `TestSheetController#recent`
- `GET /api/v1/test_sheets/:sheet_id/manifest` — `TestSheetController#manifest`
- `GET /api/v1/test_sheets/:sheet_id/ranked_results` — `TestSheetController#ranked_results`
- `POST /api/v1/test_sheets/:sheet_id/captures` — `CaptureController#create`
- `POST /api/v1/captures/:capture_id/measurements` — `CaptureController#upload_measurements`
- `POST /api/v1/captures/:capture_id/judgments` — `CaptureController#upload_judgments`
- `GET /api/v1/printer_profiles`, `/api/v1/printer_profiles/:id/colors`,
  `/api/v1/printer_profiles/:id/metamer_pairs`, `/api/v1/palettes`, `/api/v1/colors` —
  `ColorPaletteController` (not used by this app today; out of scope per issue non-goals,
  noted here as an endpoint gap discovered)

Unauthenticated (`:api`):
- `GET /api/v1/openapi.json` — `OpenApiController#show`

Outside `/api/v1` (not used by this app; noted as gaps discovered, not adopted):
- `POST /api/illuminant_measurements`, `POST /api/illuminant_measurements/bulk`
- `POST /api/multi_image_mapping` (accepts JSON or PNG)

## Schema deltas

1. **`scoring_algorithm_version` moved off the measurement upload request.** The prose
   contract's `POST /api/v1/captures/:capture_id/measurements` example has a top-level
   `scoring_algorithm_version` field. The real `MeasurementUploadRequest` schema has no such
   field — only `measurements` and `pair_scores`. Each `pair_scores` item
   (`PairScoreRequest`) now carries its own required `algorithm_version`. The hand-written
   `APIClient.uploadMeasurements` still sends the old top-level field
   (`iOS/Sources/ColorMatchingLPSAppCore/APIClient.swift:176-186`); see the failing test
   `testUploadMeasurementsOmitsTopLevelScoringAlgorithmVersion`.

2. **Upload endpoints return bodies, not empty responses.** The hand-written client treats
   `uploadMeasurements`/`uploadJudgments` as fire-and-forget (`send(_:)` discards the
   response body). The real API returns `MeasurementUploadResponse`
   (`capture_id`, `measurement_count`, `pair_score_count`) and `JudgmentUploadResponse`
   (`capture_id`, `judgment_count`). The generated client will decode these; the app should
   start using them (e.g. to confirm upload counts) instead of discarding them.

3. **Structured error bodies on failure.** `api_auth` rejects with `401` and body
   `{"errors": {"detail": "Unauthorized"}}`; other validation failures use the same
   `ErrorResponse` schema shape. The hand-written client's `validate(_:)` throws a bare
   `APIError.badStatus` with no detail from the body. See the failing test
   `testServerErrorDetailIsSurfacedInsteadOfGenericBadStatus`.

4. **`CaptureMetadata` required fields are stricter than the Swift model.** The real schema
   requires `device_model`, `lens`, `image_width`, `image_height`, `app_version`, and
   `timestamp`. The hand-written `CaptureMetadata` models `imageWidth`/`imageHeight` as
   optional `Int?`, so a caller can build a request the server will reject. See the failing
   test `testCaptureMetadataAlwaysSendsRequiredImageDimensions`. Also: `iso` is typed as an
   integer (`greater than 0`) in the real schema vs. `Float?` in the hand-written model.

5. **`PrinterProfile` fields were renamed and aren't modeled client-side at all.** The real
   schema has `id` (integer), `printer_make_model`, `paper_type`, `ink_type`. The prose
   contract's manifest example shows `printer_profile: {id, name, paper, ink, settings}`
   (string `id`, different field names, extra `settings` key). The hand-written
   `SheetManifest` Swift struct doesn't decode `printer_profile` (or `capture_profile`, or
   `created_at`) at all — those keys are silently dropped by `Codable`'s default lenient
   decoding. No client-visible crash today, but the data is unavailable to the app.

6. **RGB fields are polymorphic server-side.** `RgbPayload` is `anyOf`: an array of numbers,
   an `{r, g, b}` object, or a string. The hand-written `RGB` struct always encodes/decodes
   the object form, which is one valid arm — fine for what this app currently *sends*, but
   the generated client's type for these fields will be a `oneOf`-style enum the app must
   switch on rather than a plain struct.

7. **Auth mechanics match the prose contract.** Confirmed via `plugs/api_auth.ex`: header is
   `Authorization: Bearer <token>`, compared with `Plug.Crypto.secure_compare/2`; an unset
   server-side token allows all requests (matches "may allow unauthenticated requests in
   development" in the prose contract). No action needed here.

## Endpoint gaps discovered (non-goals for this issue, recorded for later)

`printer_profiles`, `palettes`, `colors`, `metamer_pairs`, `illuminant_measurements`, and
`multi_image_mapping` all exist server-side with published schemas but aren't used by this
app and aren't part of this issue's surface (test-sheet manifest/recent, capture creation,
measurement upload, judgment upload, ranked results). Flagging them here rather than
generating client code for them, per the issue's non-goals.

## What's blocked

Vendoring the actual OpenAPI document, adding `swift-openapi-generator` /
`swift-openapi-runtime` to `iOS/Package.swift`, generating the client, and replacing the
hand-written models all require either network access to a running `color_matching`
instance or a local checkout of that repo with its Elixir toolchain — neither is available
in this sandbox. The failing tests added in `APIContractDriftTests.swift` encode the
concrete, verified deltas above against the current hand-written client so the follow-up
implementation work has red tests to turn green once the generated client is wired in.
