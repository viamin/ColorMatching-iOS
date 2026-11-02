# Generated OpenAPI Client Migration (issue #5)

This document records the plan, the contract deltas found between
`docs/color-matching-api-contract.md` (the hand-written prose contract) and the
published OpenAPI spec from `viamin/color_matching#110`, and the verification
plan that maps each acceptance criterion to a concrete test. It is the source
material for the PR description's "what changed / endpoint gaps" sections.

## Status

- **Tests-first (red phase).** The permanent test suite
  (`iOS/Tests/ColorMatchingLPSAppTests/GeneratedOpenAPIClientTests.swift` +
  `OpenAPIClientTestSupport.swift`) is written and fails to build because the
  `ColorMatchingOpenAPI` module it exercises does not exist yet — the generated
  client is the missing behavior. The implementation run adds
  `swift-openapi-generator` + `swift-openapi-runtime`, vendors the OpenAPI
  document as specified below, and generates the module; these tests then drive
  the wiring to green.
- The existing `APIClientTests` and `MeasurementCoreTests` are untouched and
  remain the app-surface regression net while `APIClient` is rewired onto the
  generated client.

## Provenance of the OpenAPI document

- Upstream: `viamin/color_matching` at commit
  `47057afd58f7d46b4d4b740ca7d2d08947774471` (main, 2026-10-31).
- The spec is assembled at runtime by `ColorMatchingWeb.ApiSpec` from the
  router (OpenApiSpex `Paths.from_routes`) and served at
  `GET /api/v1/openapi.json`. There is no static spec file upstream.
- Schema definitions live in `lib/color_matching_web/api_schemas.ex`;
  rendering in `test_sheet_json.ex` / `capture_controller.ex`.
- The vendored copy in this repo records the upstream commit SHA and the
  served URL in a header comment so regeneration is an explicit, reviewable
  diff. Vendoring the spec document (not Phoenix code) keeps the repo boundary
  rule from `docs/companion-ios-mvp-plan.md` intact — the document is the
  machine-readable contract issue #5 explicitly wants consumed here.

## Surfaces in scope (what the app uses today)

| # | Route | Normalized operation ID | Notes |
|---|-------|-------------------------|-------|
| 1 | `GET /api/v1/test_sheets/{sheet_id}/manifest` | `fetchManifest` | full sheet geometry |
| 2 | `GET /api/v1/test_sheets/recent` | `fetchRecentSheets` | discovery list |
| 3 | `POST /api/v1/test_sheets/{sheet_id}/captures` | `createCapture` | nested `metadata` + `quality` variant |
| 4 | `POST /api/v1/captures/{capture_id}/measurements` | `uploadMeasurements` | stats + pair scores |
| 5 | `POST /api/v1/captures/{capture_id}/judgments` | `uploadJudgments` | user judgments |
| 6 | `GET /api/v1/test_sheets/{sheet_id}/ranked_results` | `fetchRankedResults` | aggregate ranking |

OpenApiSpex derives operation IDs from controller module + action (e.g.
`ColorMatchingWeb.TestSheetController.manifest`); the vendored document renames
them to the stable client-facing IDs above, which are also the generated Swift
method names asserted in the tests. Palette/printer-profile/illuminant/multi-
image-mapping routes are out of scope for this client (not used by the app).

## Contract deltas: prose contract vs published spec

Verified against the served spec's schema modules and the controller/JSON
renderer behavior:

1. **Manifest schema is under-declared upstream.** The published
   `TestSheetManifest` component declares only `schema_version` (enum
   `lps-sheet-manifest/v1`), `sheet_id`, and `capture_profile`
   (itself declaring only `scoring_algorithm_version`). The renderer actually
   returns `sheet_version`, `manifest_url`, `created_at`, `page`,
   `registration_markers`, `printer_profile`, `patches`, `pairs`. A generated
   client built from the served spec verbatim would silently **drop** the
   geometry the whole app depends on (undeclared fields are discarded during
   decoding). The vendored document extends the manifest to the full rendered
   shape.
2. **Patch IDs differ.** Prose example: `patch_1`. Real API:
   `{pair_id}#{side}` (e.g. `pair_1#first`), produced by `patch_id/2` in
   `TestSheetJSON`. Generated tests pin the real format.
3. **Printer profile shape differs.** Prose: `{id, name, paper, ink,
   settings}`. Real API: `{printer_make_model, paper_type, ink_type,
   icc_profile, print_settings, driver_name, driver_version,
   calibration_date, calibration_version, notes}` — no `id`, no `name`, and
   several nullable fields the prose never mentioned.
4. **`manifest_url` is host-dependent.** Rendered with
   `Phoenix.VerifiedRoutes.url/1`, so it is an absolute URL derived from the
   endpoint config — the prose example shows `https://example.test/...`, but
   the host varies by deployment.
5. **Create-capture accepts two shapes.** The served spec's `CaptureRequest`
   has an `anyOf`: a legacy flattened form (whose key is
   `exposure_duration`, **not** `exposure_duration_seconds`) or the nested
   `{metadata, quality}` form the app sends (metadata key:
   `exposure_duration_seconds`). The app only uses the nested form; the
   vendored document keeps only `{metadata, quality}` and records the
   dropped flattened variant here.
6. **`iso` is an integer in the spec.** Prose shows a plain number; the app's
   client-side `CaptureMetadata.iso` is `Float?`. The generated type is
   `Int?`; the adapter converts (ISO values are integral in practice).
7. **Measurement upload responses changed from 204 to 200 + body.** The prose
   contract (and the hand-written client, which tolerates any 2xx) treats
   `POST .../measurements` and `POST .../judgments` as no-content; the real
   API returns `200` with `{capture_id, measurement_count,
   pair_score_count}` / `{capture_id, judgment_count}`. Generated types make
   this drift a compile-time fact.
8. **Measurement fields the app sends are undeclared upstream.** The served
   `MeasurementUploadRequest` does not declare the per-measurement `stats`
   object (`sample_count`, `clipping_fraction`, `mean`,
   `standard_deviation`) nor the top-level `scoring_algorithm_version` — both
   of which the app has always sent. A generated client from the served spec
   would silently strip them. The vendored document declares them
   (optional) so uploads keep the app's current payload fidelity.
9. **`normalized_linear_rgb_median` is over-required upstream.** The served
   spec lists it as required per measurement; the app treats it as optional
   (it is absent until reference normalization succeeds). Vendored copy
   relaxes it to optional.
10. **`RgbPayload` is polymorphic upstream.** anyOf number-array |
    `{r,g,b}` object | string. The app only ever uses the object form; the
    vendored document declares a plain `LinearRgb {r,g,b}` number object.
11. **Pair score payloads accept three keys upstream.** `score` |
    `similarity` | `distance` (anyOf). The app sends `distance` +
    `similarity` + `algorithm_version` + `pair_id`; vendored copy keeps all
    three score keys optional without the anyOf wrapper.
12. **Judgment strings are unconstrained upstream.** Prose lists
    `match|near_match|no_match`; the served spec leaves `judgment` a free
    string. Vendored copy keeps it a string (no client-side enum) to avoid
    inventing constraints the server does not enforce.
13. **Ranked results had no shape in prose at all** — only a one-line
    description. The real response is `lps-ranked-results/v1` with
    per-pair aggregate scores (`average/latest/minimum/maximum`,
    `capture_count`, `sample_count`, `algorithm_versions`), the user's
    current judgment (+ observed-at), observation counts, latest
    observation, per-pair capture windows, and printer provenance. Note
    `source_colors` is an **object** here (`{color_a_hex, color_b_hex}`) but
    an **array** in the manifest's `pairs` entries.
14. **Errors are structured.** `{"errors": ...}` where the served spec
    allows object or array; the controllers render objects (`{detail}` or
    per-field arrays) and `OpenApiSpex.CastAndValidate` renders
    detail/source-pointer objects. Vendored copy declares `errors` as an
    object with free-form keys. 401/404/422 responses are declared on every
    operation the app uses.
15. **Auth matches.** `bearerAuth` (HTTP bearer) security scheme, applied to
    all six operations, matching the prose shared-token story. The app
    supplies it via a client middleware at wiring time.

## Endpoint gaps discovered (feed back to `viamin/color_matching`)

- Manifest + ranked-results schemas are too under-declared for consumer code
  generation; upstream should declare the full rendered shapes (or trim the
  renderer).
- Measurement upload does not declare `stats` or top-level
  `scoring_algorithm_version` although the shipped iOS app sends them.
- `normalized_linear_rgb_median` requiredness contradicts the app's optional
  usage.
- Upload endpoints return JSON bodies that older prose documented as 204;
  upstream docs/spec should state the 200 body.
- `/api/illuminant_measurements`, `/api/illuminant_measurements/bulk`, and
  `/api/multi_image_mapping` are spec'd upstream but unused by this app —
  intentionally out of scope for the generated client.

## Vendored document contract (what the tests pin)

The implementation run authors `iOS/Sources/ColorMatchingOpenAPI/openapi.yaml`
from the served document (`GET /api/v1/openapi.json`) with exactly these
reviewed normalizations; the generated types the tests reference follow from
it. All structured schemas are top-level components so generated type names
are flat (`Components.Schemas.<Name>`), snake_case keys become lowerCamelCase
Swift properties, and `format: date-time` fields decode as `Date`.

Components and fields (required unless marked optional; `?` = nullable/optional):

- `TestSheetManifest`: `schemaVersion` (enum `lps-sheet-manifest/v1`),
  `sheetId`, `sheetVersion`, `manifestUrl`, `createdAt?`, `page`,
  `registrationMarkers`, `printerProfile`, `captureProfile`, `patches`,
  `pairs`.
- `Page`: `units`, `width`, `height` (numbers).
- `RegistrationMarker`: `role`, `shape`, `rect`.
- `Rect`: `x`, `y`, `width`, `height` (numbers).
- `PrinterProfile`: `printerMakeModel`, `paperType`, `inkType`, `iccProfile?`,
  `printSettings?`, `driverName?`, `driverVersion?`, `calibrationDate?`,
  `calibrationVersion?`, `notes?`.
- `CaptureProfile`: `expectedIlluminant`, `preferredCamera`,
  `scoringAlgorithmVersion` (enum `lps-distance-v1`).
- `Patch`: `id`, `role`, `pairId?`, `pairSide?`, `referenceRole?`,
  `sourceColor?`, `safeInsetMm`, `rect`.
- `PairManifest`: `id`, `firstPatchId`, `secondPatchId`, `sourceColors`,
  `gridRow`, `gridCol`.
- `RecentSheetsResponse`: `sheets` of `RecentSheet` (`sheetId`, `manifestUrl`,
  `title?`).
- `RankedResults`: `schemaVersion` (enum `lps-ranked-results/v1`), `sheetId`,
  `printerProfile`, `captureCount`, `latestCaptureAt?`, `earliestCaptureAt?`,
  `scoringAlgorithmVersions`, `results` of `RankedResult`.
- `RankedResult`: `rank`, `pairId`, `scoringAlgorithmVersion`, `row`, `col`,
  `sourceColors` (`RankedResultSourceColors`: `colorAHex`, `colorBHex`),
  `score` (`RankedScore`), `currentJudgment?`,
  `currentJudgmentObservedAt?`, `observationCount`, `latestObservation?`
  (`LatestObservation`: `judgment`, `observedAt?`), `captureCount`,
  `latestCaptureAt?`, `earliestCaptureAt?`.
- `RankedScore`: `average`, `latest?`, `minimum?`, `maximum?`,
  `captureCount`, `sampleCount`, `algorithmVersions`.
- `CaptureRequest`: `metadata` (`CaptureMetadata`), `quality`
  (`CaptureQuality`).
- `CaptureMetadata`: `deviceModel`, `lens`, `exposureDurationSeconds?`,
  `iso?` (integer), `focusLensPosition?`, `whiteBalanceGains?`
  (`WhiteBalanceGains`: `red`, `green`, `blue`), `imageWidth`, `imageHeight`,
  `appVersion`, `timestamp` (date-time).
- `CaptureQuality`: `detectedMarkerCount`, `blurScore`, `rejections` (string
  array).
- `CaptureCreatedResponse`: `captureId` (status 201).
- `MeasurementUploadRequest`: `scoringAlgorithmVersion?`, `measurements`,
  `pairScores`.
- `MeasurementUploadItem`: `patchId`, `linearRgbMedian` (`LinearRgb`),
  `normalizedLinearRgbMedian?` (`LinearRgb`), `stats?` (`MeasurementStats`).
- `LinearRgb`: `r`, `g`, `b` (numbers).
- `MeasurementStats`: `sampleCount`, `clippingFraction`, `mean`,
  `standardDeviation` (`LinearRgb`).
- `PairScoreRequest`: `pairId`, `algorithmVersion`, `score?`, `similarity?`,
  `distance?`.
- `MeasurementUploadResponse` (200): `captureId`, `measurementCount`,
  `pairScoreCount`.
- `JudgmentUploadRequest`: `judgments` of `PairJudgmentItem` (`pairId`,
  `judgment`).
- `JudgmentUploadResponse` (200): `captureId`, `judgmentCount`.
- `ApiErrorResponse` (401/404/422): `errors` (free-form object).

Generator config: `access: public` (tests import the module), client-only
generation. Package wiring: `swift-openapi-generator` plugin target
`ColorMatchingOpenAPI` depending on `swift-openapi-runtime`
(`OpenAPIRuntime`); `ColorMatchingLPSAppTests` gains a dependency on
`ColorMatchingOpenAPI`. Client-side-only models (e.g. `WhiteBalanceGains`,
`CaptureQuality` as used by `MeasurementCore`, analysis domain types) stay
hand-written; the adapter layer converts between them and generated types.

## Verification plan (acceptance criteria → evidence)

| AC | Verification | Kind | Where |
|----|--------------|------|-------|
| Generator + runtime added; spec vendored | Generated module compiles and the red tests link | permanent unit test | `GeneratedOpenAPIClientTests.swift` (builds only once `ColorMatchingOpenAPI` exists) |
| Client generated for all six surfaces | One test per operation (manifest, recent, capture, measurements, judgments, ranked results) against stubbed responses | permanent unit test | same file, 9 tests |
| Hand-written API models replaced; client-side models kept | Existing app-surface tests still pass after rewiring (paths, payloads, bearer header unchanged from the app's view) | permanent unit test (pre-existing, unchanged) | `APIClientTests.swift`; `MeasurementCoreTests.swift` |
| Tests exercise generated client against local stubs, no live server | `StubbedTransport` implements `ClientTransport`; zero network use | permanent unit test | `OpenAPIClientTestSupport.swift` |
| PR description records contract deltas + gaps | Delta table + gap list above, carried into the PR description | human/external evidence | this document |

Red-phase status at this commit: the two new test files fail to **build**
(`no such module 'ColorMatchingOpenAPI'` / `'OpenAPIRuntime'`), which is the
expected failure demonstrating the missing generated client; the remaining
targets are unaffected. CI runs `swift test` on macOS
(`.github/workflows/ci.yml`), where the suite must be green after the
implementation run lands the package wiring and the vendored spec.
