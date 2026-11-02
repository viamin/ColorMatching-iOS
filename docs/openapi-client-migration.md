# OpenAPI Generated Client Migration (issue #5)

Status: **test-writing phase complete**. This document records (1) the
verification plan mapping each acceptance criterion to its smallest credible
verification, (2) the contract deltas found between
`docs/color-matching-api-contract.md` and the real published spec, and (3) the
checklist the implementation run must follow. The PR description for issue #5
should lift sections 2–3 verbatim, per the issue's deliverable.

The published spec exists upstream: viamin/color_matching#110 landed
`open_api_spex` coverage served at `GET /api/v1/openapi.json`, with CI
Schemathesis + oasdiff enforcement. The upstream conformance test pins the
exact path set (see `test/color_matching_web/controllers/open_api_controller_test.exs`
in viamin/color_matching).

## 1. Acceptance criteria → verification mapping

| # | Deliverable (from issue #5) | Verification | Kind | Locator |
| --- | --- | --- | --- | --- |
| AC-1 | `swift-openapi-generator` + `swift-openapi-runtime` in the iOS package; vendored OpenAPI document | Conformance tests read the vendored `iOS/Sources/ColorMatchingOpenAPI/openapi.json` and assert it parses as OpenAPI 3, declares all six app operations with stable operation ids, and carries the compatibility enums (`lps-sheet-manifest/v1`, `lps-distance-v1`, `lps-ranked-results/v1`). They fail while the document is absent (red phase). Dependency additions are verified by the package building in CI. | permanent unit test + build | `iOS/Tests/ColorMatchingLPSAppTests/OpenAPISpecConformanceTests.swift` |
| AC-2 | Generated client for the surfaces the app uses today (manifest, recent sheets, capture creation, measurement upload, judgment upload, ranked results) | Stub-transport tests drive the generated `Client` for each of the six operations, asserting operation id, HTTP method, path, request wire shape, and typed response decoding. | permanent unit test | `iOS/Tests/ColorMatchingOpenAPITests/GeneratedClientTests.swift` |
| AC-3 | Replace hand-written API models with generated types; keep purely client-side models | Existing behavior tests (`APIClientTests`) keep the facade honest during the swap; the generated-client tests pin the new wire contract. Model removal is compile-verified. | permanent unit test + build | `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift`, `iOS/Tests/ColorMatchingOpenAPITests/GeneratedClientTests.swift` |
| AC-4 | Swift tests exercising the generated client against local stubbed responses | `StubTransport` (a `ClientTransport`) serves canned responses; no live server is contacted. | permanent unit test | `iOS/Tests/ColorMatchingOpenAPITests/StubTransport.swift` |
| AC-5 | PR description records prose-contract vs published-spec deltas and endpoint gaps | Section 2 and 3 below, derived from the upstream sources of truth (linked inline). | external evidence (upstream repo) + doc | this file |
| AC-6 | `swift test --disable-sandbox` green with generated types wired in | CI (`swift test` on macOS runner) once the implementation run wires `ColorMatchingOpenAPITests` into `Package.swift`. | CI build | `.github/workflows/ci.yml` |

## 2. Contract deltas: prose contract vs published spec

Sources: `lib/color_matching_web/api_schemas.ex`, `router.ex`,
`controllers/capture_controller.ex`, `controllers/test_sheet_controller.ex`,
`controllers/test_sheet_json.ex` at viamin/color_matching `main`.

1. **The manifest schema is much weaker than the prose contract.** The spec's
   `TestSheetManifest` only declares and requires `schema_version`, `sheet_id`,
   and `capture_profile` (with `scoring_algorithm_version`). The prose
   contract documents `sheet_version`, `manifest_url`, `created_at`, `page`,
   `registration_markers`, `printer_profile`, `patches`, and `pairs` — all of
   which the server *renders* (`TestSheetJSON.manifest/1`) but none of which
   the spec types. Generated client code therefore gives typed access to only
   the three declared fields; the rest ride on undeclared additional
   properties. **Action for implementation/PR: request the upstream spec
   fully type the manifest, or treat the untyped remainder as
   `JSONValue`-level data.**
2. **`printer_profile` shape differs.** Prose: `{id, name, paper, ink,
   settings}`. Actual rendering: `{printer_make_model, paper_type, ink_type,
   icc_profile, print_settings, driver_name, driver_version,
   calibration_date, calibration_version, notes}` — no `id`, no `name`.
3. **Patch ids are `"<pair_id>#<side>"`** (e.g. `pair_1#first`), not the
   prose example's `patch_1`. Compatible with the prose contract (which never
   pinned a format) but worth recording.
4. **Capture creation accepts two shapes.** The spec's `CaptureRequest` is
   the prose contract's nested `{metadata, quality}` form **plus** a flat
   form via `anyOf` with `exposure_duration` (not
   `exposure_duration_seconds`), `rejection_reasons` (not `rejections`), and
   `detected_marker_count`/`blur_score` at top level. The app sends the
   nested form.
5. **`iso` is an integer** in the spec (and `image_width`/`image_height`,
   `focus_lens_position` numeric bounds are declared). The hand-written model
   used `Float?` for `iso`; the generated type is `Int?`.
6. **Measurement upload loses fields.** The spec's
   `MeasurementUploadRequest` has **no** top-level `scoring_algorithm_version`
   and **no** per-measurement `stats` object — both of which the prose
   contract documents and the hand-written client sends. Also
   `normalized_linear_rgb_median` is **required** (the app model treated it
   as optional). `linear_rgb_median` is a `RgbPayload` `anyOf`
   (number array | `{r,g,b}` object | JSON-encoded string); the app sends the
   object form.
7. **Pair scores accept `score | similarity | distance`.** The prose contract
   sent `distance` + `similarity`; the spec requires `pair_id` +
   `algorithm_version` and at least one of the three score fields.
8. **Uploads answer `200` with bodies, not bare 2xx.** Measurement upload →
   `{capture_id, measurement_count, pair_score_count}`; judgment upload →
   `{capture_id, judgment_count}`; capture creation → `201` with
   `{capture_id}`. The hand-written client tolerated any 2xx including empty
   `204` (its tests stub `204`); a generated client will reject an
   undocumented `204`. The old tests must be updated to the spec'd statuses
   during the implementation swap.
9. **Judgments are free-form strings** in the spec; the prose contract's
   `match | near_match | no_match` enum is not enforced server-side.
10. **Ranked results now have a concrete envelope** —
    `lps-ranked-results/v1` with `schema_version`, `sheet_id`,
    `printer_profile`, `capture_count`, `latest_capture_at`,
    `earliest_capture_at`, `scoring_algorithm_versions`, and `results[]`
    (rank, pair_id, scoring_algorithm_version, row, col, source_colors,
    score aggregates, current_judgment, observation_count,
    latest_observation, capture provenance). The prose contract never
    specified this shape. As with the manifest, the spec only *types* the
    `schema_version` + `sheet_id` envelope.
11. **Auth is a declared `bearerAuth` HTTP scheme** on each operation. The
    generated client applies no credentials itself; the app adds a
    `ClientMiddleware` (or URLSession-level header) for the bearer token.
    The hand-written client attached the header inline — behavior parity is
    covered by the existing `APIClientTests` auth assertion.
12. **Error responses are declared** (`401`, `404`, `422` with an
    `ApiErrorResponse` `{errors}` shape). Generated clients surface these as
    typed output cases (e.g. `.notFound`) instead of the hand-written
    client's generic `.badStatus`.

## 3. Endpoint gaps discovered (spec ⊃ prose contract)

The published spec documents 14 paths; the prose contract documents 6.
Surfaces in the spec that the app does not use (and the prose contract never
mentioned):

- `GET /api/v1/printer_profiles`
- `GET /api/v1/printer_profiles/{printer_profile_id}/colors`
- `GET /api/v1/printer_profiles/{printer_profile_id}/metamer_pairs`
- `GET /api/v1/palettes`
- `GET /api/v1/colors`
- `POST /api/illuminant_measurements` and `POST /api/illuminant_measurements/bulk`
- `POST /api/multi_image_mapping` (PNG body; macOS app surface)

No gaps in the reverse direction: every endpoint the app uses today is in
the published spec. `GET /api/v1/openapi.json` serves the spec itself, and
undocumented methods on read-only endpoints return `405` with an `Allow`
header (upstream `MethodNotAllowedController`, excluded from the spec).

## 4. Implementation-run checklist

1. `iOS/Package.swift`: add `apple/swift-openapi-generator` (plugin),
   `apple/swift-openapi-runtime`, `apple/swift-openapi-urlsession-transport`;
   create target `ColorMatchingOpenAPI` vendoring the document at
   `Sources/ColorMatchingOpenAPI/openapi.json` (fetch from a running Phoenix
   app: `curl $BASE/api/v1/openapi.json`); add the
   `ColorMatchingOpenAPITests` test target (see the directory README).
2. Re-point `ColorMatchingLPSAppCore`'s `APIClient` at the generated client
   (bearer token via middleware); delete hand-written wire models that the
   generated types replace (`CaptureMetadata` wire encoding,
   `CaptureSessionResponse`, `RecentSheet` wire decoding, upload request
   structs). Keep purely client-side models in `MeasurementCore` untouched.
3. Update `APIClientTests` expectations that encode the *prose* wire shape
   (`204` stubs, `scoring_algorithm_version`, `stats`) to the spec'd shape
   from section 2; keep its auth-header assertion.
4. Resolve red flags if the generator mishandles schemas combining
   `properties` with `anyOf` (`CaptureRequest`, `PairScoreRequest`): if the
   generated types lose the named properties, raise the spec fix upstream
   (e.g. drop the flat anyOf variant) rather than hand-patching generated
   code. `GeneratedClientTests` is written to surface exactly this.
5. Regeneration drill: change the vendored document (e.g. next upstream spec
   revision), rerun `swift test --disable-sandbox`, and show drift arriving
   as compile errors/diff — include the result in the PR description.

## 5. Red-phase notes (this commit)

- `OpenAPISpecConformanceTests` compiles against the existing package
  (Foundation-only) and fails while the vendored document is absent — the
  expected red signal for deliverable AC-1.
- `ColorMatchingOpenAPITests` cannot build until the implementation run adds
  the generated target; see its README for the wiring contract.
- No Swift toolchain exists in this container (and the executable target
  uses SwiftUI/AVFoundation, so Linux builds are not viable); local test
  execution was not possible. CI's macOS runner is the execution
  environment.
