# OpenAPI Client Migration Plan and Contract Delta Record

Status: test-writing phase of issue #5 ("Replace hand-written API layer with a
generated OpenAPI Swift client"). This document is the normative record the
implementation phase must follow: it captures what the published API actually
says, how it differs from the prose contract, exactly which normalization the
generation-input spec applies, and which generated Swift names the permanent
tests in `iOS/Tests/ColorMatchingLPSAppTests/GeneratedClientContractTests.swift`
rely on.

## Provenance of the published spec

Upstream `viamin/color_matching` published a machine-readable OpenAPI 3.0
document in viamin/color_matching#113 (closes viamin/color_matching#110):

- Served at `GET /api/v1/openapi.json`
- Built with OpenApiSpex from the router: every `/api/v1` route plus the two
  `/api` POST routes, validated in CI by Schemathesis and gated by oasdiff
- Source of truth files (fetched 2026-11-01):
  - `lib/color_matching_web/api_spec.ex` — spec assembly, `bearerAuth` scheme,
    server URL `/`
  - `lib/color_matching_web/api_schemas.ex` — component schemas
  - `lib/color_matching_web/controllers/test_sheet_controller.ex`,
    `capture_controller.ex` — operation declarations
  - `lib/color_matching_web/controllers/test_sheet_json.ex` — actual response
    payloads for manifest/recent/ranked_results

The iOS package vendors the document and regenerates the client from it:

```bash
curl -fsSL "$COLOR_MATCHING_BASE/api/v1/openapi.json" \
  -o iOS/OpenAPI/published-openapi.json
# apply the normalizations in "Generation-input normalizations" below to
# produce iOS/OpenAPI/openapi.yaml (the file the generator plugin reads)
```

`published-openapi.json` is kept byte-as-fetched so upstream drift shows up as
a re-fetch diff; `openapi.yaml` is the generation input.

## Contract deltas: prose contract vs published spec vs actual payloads

The prose contract is `docs/color-matching-api-contract.md`. "Actual payload"
is what the Phoenix JSON views render today.

| # | Surface | Prose contract | Published spec / actual payload | Delta |
|---|---------|----------------|--------------------------------|-------|
| 1 | Manifest shape | Full manifest typed: page, registration_markers, printer_profile, capture_profile, patches, pairs, … | Spec types only `schema_version`, `sheet_id`, `capture_profile.scoring_algorithm_version`. Actual payload contains everything the prose documents | Spec under-types the manifest by ~11 fields; generated client needs normalization to cover the app surface |
| 2 | `printer_profile` in manifest | `{id, name, paper, ink, settings}` | No `id`; actual render is `{printer_make_model, paper_type, ink_type, icc_profile, print_settings, driver_name, driver_version, calibration_date, calibration_version, notes}` | Prose contract was wrong; palette `PrinterProfile` component (`{id, printer_make_model, paper_type, ink_type}`) is a different shape and must not be reused for manifests (its required `id` is absent from manifest renders) |
| 3 | Patch IDs | `patch_1` style | Actual IDs are `"<pair_id>#first"` / `"<pair_id>#second"` | Purely a naming delta; the app treats IDs as opaque strings |
| 4 | `manifest_url` | Absolute (`https://example.test/...`) | Relative path (`/api/v1/test_sheets/<code>/manifest`) | Generated model types it as a plain string; callers resolve against the base URL |
| 5 | Recent sheets `title` | "may be null" | Required but nullable; actual render is **always** `null` today | Consistent; generated type is `String?` |
| 6 | Ranked results | "latest or aggregate ranked results with source colors, scores, labels, capture provenance, printer profile, and scoring algorithm version" (untyped) | Spec types only `schema_version` (`lps-ranked-results/v1`) and `sheet_id`; actual payload is a rich aggregate (rank/pair_id/row/col/source_colors/score stats/current_judgment/latest_observation/…) | Spec under-types; normalization types the actual payload |
| 7 | Capture create request | `{metadata: {...}, quality: {...}}` | Spec's `CaptureRequest` is `anyOf` of a **flattened** variant (top-level fields, `exposure_duration` not `exposure_duration_seconds`) and the nested `{metadata}` variant, with sibling `properties` that OpenAPIKit drops when `anyOf` is present (see "Codegen blockers") | Spec is lossy for generated clients; normalization keeps only the nested form the app sends |
| 8 | `iso` type | Example shows integer | Spec types `integer, minimum 0, exclusiveMinimum 0`; hand-written model used `Float` | App converts to `Int` at the client boundary |
| 9 | `white_balance_gains` | `{red, green, blue}` numbers | Spec types it as a bare object (no properties) | Normalization types the three channels |
| 10 | Measurement upload request | Top-level `scoring_algorithm_version`; per-measurement `stats` `{sample_count, clipping_fraction, mean, standard_deviation}`; `normalized_linear_rgb_median` optional | Spec has none of `scoring_algorithm_version`/`stats`, and marks `normalized_linear_rgb_median` as **required** per measurement (the app may omit it); `linear_rgb_median` is `RgbPayload` = anyOf(array \| `{r,g,b}` \| string) | Normalization adds the top-level version + `stats`, makes `normalized_linear_rgb_median` optional, keeps `RgbPayload` as published; the app uses the `{r,g,b}` branch |
| 11 | Pair scores | `{pair_id, distance, similarity, algorithm_version}` | Spec's `PairScoreRequest` = `required: [pair_id, algorithm_version]` + `anyOf(required: score \| similarity \| distance)` — siblings dropped by OpenAPIKit, branches are `required`-only fragments | Normalization flattens to `{pair_id, algorithm_version, distance?, similarity?, score?}`; the app sends `distance` + `similarity` unchanged |
| 12 | Measurement/judgment upload responses | Untyped; hand-written client tolerated `204` with empty body | Spec (and actual server) return `200` with `{capture_id, measurement_count, pair_score_count}` / `{capture_id, judgment_count}` | Generated client types the 200 bodies; the 204 tolerance is dropped |
| 13 | Error responses | Undocumented | Typed `ApiErrorResponse` on 401/404/422 with `errors` payload | Improvement; surfaced as typed response cases |
| 14 | Auth | Shared bearer token | `bearerAuth` HTTP bearer scheme on all app-facing operations | Consistent; supplied via client middleware/`Configuration.auth` at the app layer |

## Endpoint gaps discovered

Covered by the spec but unused by the iOS app (left ungenerated or unused —
non-goal to add endpoints):

- `GET /api/v1/openapi.json` (spec itself)
- `GET /api/v1/printer_profiles`, `GET /api/v1/printer_profiles/{id}/colors`,
  `GET /api/v1/printer_profiles/{id}/metamer_pairs`
- `GET /api/v1/palettes`, `GET /api/v1/colors`
- `POST /api/illuminant_measurements`, `POST /api/illuminant_measurements/bulk`
- `POST /api/multi_image_mapping`

No route the app uses is missing from the spec. The gaps are under-typing
(rows 1, 6, 9, 10) and the two anyOf patterns that break codegen (rows 7, 11).

## Codegen blockers in the as-published document

1. OpenAPIKit (used by swift-openapi-generator) parses a schema containing
   `anyOf` as `.any(of:)` and **silently drops sibling keys** such as `type`/
   `properties`. Both `CaptureRequest` and `PairScoreRequest` rely on
   sibling properties, so a client generated verbatim from the published
   document cannot express `pair_id`, `metadata`, etc.
2. The `anyOf` branches in those two schemas are `required`-only fragments
   (no `type`, no `properties`); swift-openapi-generator emits no type
   declaration for fragment branches, so the generated struct would reference
   an undefined nested type and fail to compile.
3. `TestSheetManifest` and `RankedResults` type 2–3 fields of much larger
   actual payloads, so a verbatim client could not drive the capture flow at
   all.

These three findings go in the PR description of the implementation phase
(deliverable 5) and are worth raising upstream so the normalization can shrink
over time.

## Generation-input normalizations (normative)

`iOS/OpenAPI/openapi.yaml` is the published document with **only** the changes
below. Paths, methods, path parameters, `operationId`s, the `bearerAuth`
scheme, servers, and response status codes stay exactly as published.
Unchanged component schemas: `RgbPayload`, `RecentSheetsResponse`,
`CaptureCreatedResponse`, `MeasurementUploadResponse`,
`JudgmentUploadResponse`, `ApiErrorResponse`, and all palette-side schemas.

Property order matters: the generated memberwise initializers list parameters
in schema order, and the tests construct payloads positionally with labels.

```yaml
components:
  schemas:
    Rect:                                   # NEW shared component
      type: object
      required: [x, y, width, height]
      properties:
        x: {type: number}
        y: {type: number}
        width: {type: number}
        height: {type: number}

    SheetPrinterProfile:                    # NEW; manifest/ranked printer_profile
      type: object                          # (server also sends icc_profile,
      required: [printer_make_model, paper_type, ink_type]   # print_settings, driver_*, calibration_*, notes —
      properties:                           # intentionally undeclared; generated
        printer_make_model: {type: string}  # decoders ignore unknown fields)
        paper_type: {type: string}
        ink_type: {type: string}

    TestSheetManifest:                      # EXTENDED (published types 3 fields)
      type: object
      required: [schema_version, sheet_id, sheet_version, manifest_url,
                 created_at, page, registration_markers, printer_profile,
                 capture_profile, patches, pairs]
      properties:
        schema_version: {type: string, enum: ["lps-sheet-manifest/v1"]}
        sheet_id: {type: string}
        sheet_version: {type: string}
        manifest_url: {type: string}
        created_at: {type: string, format: date-time}
        page:
          type: object
          required: [units, width, height]
          properties:
            units: {type: string}
            width: {type: number}
            height: {type: number}
        registration_markers:
          type: array
          items:
            type: object
            required: [role, shape, rect]
            properties:
              role: {type: string}
              shape: {type: string}
              rect: {$ref: "#/components/schemas/Rect"}
        printer_profile: {$ref: "#/components/schemas/SheetPrinterProfile"}
        capture_profile:
          type: object
          required: [expected_illuminant, preferred_camera, scoring_algorithm_version]
          properties:
            expected_illuminant: {type: string}
            preferred_camera: {type: string}
            scoring_algorithm_version: {type: string, enum: ["lps-distance-v1"]}
        patches:
          type: array
          items:
            type: object
            required: [id, role, pair_id, pair_side, reference_role,
                       source_color, safe_inset_mm, rect]
            properties:
              id: {type: string}
              role: {type: string}          # pair_color | reference (untyped upstream)
              pair_id: {type: string, nullable: true}
              pair_side: {type: string, nullable: true}
              reference_role: {type: string, nullable: true}
              source_color: {type: string, nullable: true}
              safe_inset_mm: {type: number}
              rect: {$ref: "#/components/schemas/Rect"}
        pairs:
          type: array
          items:
            type: object
            required: [id, first_patch_id, second_patch_id, source_colors,
                       grid_row, grid_col]
            properties:
              id: {type: string}
              first_patch_id: {type: string}
              second_patch_id: {type: string}
              source_colors: {type: array, items: {type: string}}
              grid_row: {type: integer}
              grid_col: {type: integer}

    RankedResults:                          # EXTENDED (published types 2 fields)
      type: object
      required: [schema_version, sheet_id, printer_profile, capture_count,
                 latest_capture_at, earliest_capture_at,
                 scoring_algorithm_versions, results]
      properties:
        schema_version: {type: string, enum: ["lps-ranked-results/v1"]}
        sheet_id: {type: string}
        printer_profile: {$ref: "#/components/schemas/SheetPrinterProfile"}
        capture_count: {type: integer}
        latest_capture_at: {type: string, format: date-time, nullable: true}
        earliest_capture_at: {type: string, format: date-time, nullable: true}
        scoring_algorithm_versions: {type: array, items: {type: string}}
        results:
          type: array
          items:
            type: object
            required: [rank, pair_id, scoring_algorithm_version, row, col,
                       source_colors, score, current_judgment,
                       current_judgment_observed_at, observation_count,
                       latest_observation, capture_count, latest_capture_at,
                       earliest_capture_at]
            properties:
              rank: {type: integer}
              pair_id: {type: string}
              scoring_algorithm_version: {type: string}
              row: {type: integer}
              col: {type: integer}
              source_colors:
                type: object
                required: [color_a_hex, color_b_hex]
                properties:
                  color_a_hex: {type: string}
                  color_b_hex: {type: string}
              score:
                type: object
                required: [average, latest, minimum, maximum, capture_count,
                           sample_count, algorithm_versions]
                properties:
                  average: {type: number}
                  latest: {type: number}
                  minimum: {type: number}
                  maximum: {type: number}
                  capture_count: {type: integer}
                  sample_count: {type: integer}
                  algorithm_versions: {type: array, items: {type: string}}
              current_judgment: {type: string, nullable: true}
              current_judgment_observed_at: {type: string, format: date-time, nullable: true}
              observation_count: {type: integer}
              latest_observation:
                type: object
                nullable: true
                required: [judgment, observed_at]
                properties:
                  judgment: {type: string}
                  observed_at: {type: string, format: date-time}
              capture_count: {type: integer}
              latest_capture_at: {type: string, format: date-time, nullable: true}
              earliest_capture_at: {type: string, format: date-time, nullable: true}

    CaptureRequest:                         # NORMALIZED: nested form only
      type: object                          # (anyOf flattened variant dropped)
      required: [metadata, quality]
      properties:
        metadata: {$ref: "#/components/schemas/CaptureMetadata"}
        quality: {$ref: "#/components/schemas/CaptureQuality"}

    CaptureQuality:                         # NEW (was inline in CaptureRequest)
      type: object
      required: [detected_marker_count, blur_score, rejections]
      properties:
        detected_marker_count: {type: integer, minimum: 0}
        blur_score: {type: number, minimum: 0}
        rejections: {type: array, items: {type: string}}

    CaptureMetadata:                        # published + typed white_balance_gains
      type: object
      required: [device_model, lens, image_width, image_height, app_version, timestamp]
      properties:
        device_model: {type: string}
        lens: {type: string}
        exposure_duration_seconds: {type: number, minimum: 0, exclusiveMinimum: true}
        iso: {type: integer, minimum: 0, exclusiveMinimum: true}
        focus_lens_position: {type: number, minimum: 0}
        white_balance_gains:
          type: object
          required: [red, green, blue]
          properties:
            red: {type: number}
            green: {type: number}
            blue: {type: number}
        image_width: {type: integer, minimum: 0, exclusiveMinimum: true}
        image_height: {type: integer, minimum: 0, exclusiveMinimum: true}
        app_version: {type: string}
        timestamp: {type: string, format: date-time}

    MeasurementUploadRequest:               # NORMALIZED: adds top-level version + typed stats
      type: object
      required: [scoring_algorithm_version, measurements, pair_scores]
      properties:
        scoring_algorithm_version: {type: string}
        measurements:
          type: array
          items: {$ref: "#/components/schemas/MeasurementUploadItem"}
        pair_scores:
          type: array
          items: {$ref: "#/components/schemas/PairScoreRequest"}

    MeasurementUploadItem:                  # NEW (was inline; promoted for construction)
      type: object
      required: [patch_id, linear_rgb_median, stats]
      properties:
        patch_id: {type: string}
        linear_rgb_median: {$ref: "#/components/schemas/RgbPayload"}
        normalized_linear_rgb_median: {$ref: "#/components/schemas/RgbPayload"}
        stats: {$ref: "#/components/schemas/MeasurementStatsUpload"}

    MeasurementStatsUpload:                 # NEW
      type: object
      required: [sample_count, clipping_fraction, mean, standard_deviation]
      properties:
        sample_count: {type: integer}
        clipping_fraction: {type: number}
        mean: {$ref: "#/components/schemas/RgbPayload"}
        standard_deviation: {$ref: "#/components/schemas/RgbPayload"}

    PairScoreRequest:                       # NORMALIZED: flattened (anyOf dropped)
      type: object
      required: [pair_id, algorithm_version]
      properties:
        pair_id: {type: string}
        algorithm_version: {type: string}
        distance: {type: number}
        similarity: {type: number}
        score: {type: number}

    JudgmentUploadItem:                     # NEW (was inline; promoted for construction)
      type: object
      required: [pair_id, judgment]
      properties:
        pair_id: {type: string}
        judgment: {type: string}

    JudgmentUploadRequest:                  # published shape; items promoted to a named component
      type: object
      required: [judgments]
      properties:
        judgments:
          type: array
          items: {$ref: "#/components/schemas/JudgmentUploadItem"}
```

## Pinned naming and wiring decisions

These are derived from swift-openapi-generator 1.14.x behavior (verified
against `SafeNameGenerator.swift`, `HTTPStatusCodes.swift`,
`TypeAssigner.swift`, `translateAllAnyOneOf.swift`) and are load-bearing for
the tests. The implementation phase must not deviate.

- Generated target: `ColorMatchingOpenAPI`, from `iOS/OpenAPI/openapi.yaml`
  via the `OpenAPIGenerator` plugin.
- `iOS/OpenAPI/openapi-generator-config.yaml`:

  ```yaml
  generate:
    - types
    - client
  accessModifier: public
  namingStrategy: idiomatic
  ```

  `namingStrategy: idiomatic` is required — the default `defensive` strategy
  turns `.` in operation IDs into `_period_`.
- Operation IDs are preserved exactly as published, which yields these client
  methods (upstream renames will surface as regeneration diffs / compile
  errors — that is the point of this migration):

  | Operation ID | Swift method | Response enum |
  |---|---|---|
  | `ColorMatchingWeb.TestSheetController.manifest` | `colorMatchingWeb_TestSheetController_manifest` | `.ok` / `.unauthorized` / `.notFound` |
  | `ColorMatchingWeb.TestSheetController.recent` | `colorMatchingWeb_TestSheetController_recent` | `.ok` / `.unauthorized` |
  | `ColorMatchingWeb.TestSheetController.ranked_results` | `colorMatchingWeb_TestSheetController_rankedResults` | `.ok` / `.unauthorized` / `.notFound` |
  | `ColorMatchingWeb.CaptureController.create` | `colorMatchingWeb_CaptureController_create` | `.created` / `.unauthorized` / `.notFound` / `.unprocessableContent` |
  | `ColorMatchingWeb.CaptureController.upload_measurements` | `colorMatchingWeb_CaptureController_uploadMeasurements` | `.ok` / `.unauthorized` / `.notFound` / `.unprocessableContent` |
  | `ColorMatchingWeb.CaptureController.upload_judgments` | `colorMatchingWeb_CaptureController_uploadJudgments` | `.ok` / `.unauthorized` / `.notFound` / `.unprocessableContent` |

  Note 422 maps to `.unprocessableContent` (not `unprocessableEntity`).
- Path parameters: `sheet_id` → `sheetId`, `capture_id` → `captureId`;
  inputs are `.init(path: .init(sheetId:))` and bodies `.init(body: .json(...))`.
- Package versions: `swift-openapi-generator` 1.14.x,
  `swift-openapi-runtime` 1.13.x (HTTPTypes-based currency types),
  `swift-http-types` (direct product dependency so tests can `import HTTPTypes`).
  The `ColorMatchingOpenAPI` target depends on the `OpenAPIRuntime` product;
  the `ColorMatchingLPSAppTests` test target gains dependencies on
  `ColorMatchingOpenAPI`, `OpenAPIRuntime`, and `HTTPTypes`.
- Auth stays an app-layer concern (`ColorMatchingLPSAppCore.APIClient` wraps
  the generated `Client` and injects the bearer token), so the generated
  client tests deliberately assert only spec-level behavior: method, path,
  content type, request body JSON, response decoding, and typed error cases.

## Acceptance-criterion → verification mapping

| Deliverable (issue #5) | Verification | Where |
|---|---|---|
| D1 Add generator + runtime; vendor the OpenAPI document | Human/external (implementation phase wiring; instructions above) | This doc |
| D2 Generate client for all 6 surfaces | Permanent unit/service tests referencing every operation (compile-level contract; red until generated): `testManifestDecodesFullSheetManifest`, `testRecentSheetsDecodesSheetsWithNullableTitle`, `testRankedResultsDecodesAggregatePayload`, `testCreateCaptureSendsNestedMetadataAndQualityAndDecodesCaptureID`, `testUploadMeasurementsSendsChannelPayloadsStatsAndScores`, `testUploadJudgmentsSendsPairJudgmentsAndDecodesCounters` | `GeneratedClientContractTests.swift` |
| D3 Replace hand-written API models; keep client-side models | Implementation phase; covered by existing `APIClientTests` + `MeasurementCoreTests` staying green | Implementation PR |
| D4 Swift tests against local stubbed responses (no live server) | Permanent unit/service tests using a stubbed `ClientTransport` keyed by operation ID, including typed error cases (`testManifestSurfacesNotFoundAsTypedResponseCase`, `testRecentSheetsSurfacesUnauthorizedAsTypedResponseCase`, `testUploadJudgmentsSurfacesValidationErrorAsTypedResponseCase`) | `GeneratedClientContractTests.swift` |
| D5 PR description records contract deltas + endpoint gaps | Human/external evidence: this doc's delta table + endpoint-gap section feed the PR description | This doc |

Test-selection rationale: the generated-client contract is a recurring rule
(drift must fail compilation/tests on every future change), so it gets
**permanent** unit/service tests; no one-off system flow is involved, so no
`.ephemeral-tests/` entry is needed. During this test-writing phase the new
tests are expected to fail to build (`no such module 'ColorMatchingOpenAPI'`)
— that is the red signal for the implementation phase, which makes them green
without editing them.
