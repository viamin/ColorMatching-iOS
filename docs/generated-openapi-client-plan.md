# Generated OpenAPI Client Plan (issue #5, tests-first run)

Status: **red-phase test plan.** The tests in
`iOS/Tests/ColorMatchingLPSAppTests/GeneratedClientTests.swift` pin the surface
that the generated client must expose. They intentionally fail to build until
the implementation run adds the `OpenAPIGenerated` target (no such module
today). `swift test` is expected to be red at this commit and green after the
implementation run lands.

Dependency: **met.** viamin/color_matching#110 was closed by
viamin/color_matching#113 (merged 2026-10-30). The spec source lives in
`lib/color_matching_web/api_spec.ex` + `lib/color_matching_web/api_schemas.ex`
on `main`, and is served at `GET /api/v1/openapi.json`. No static spec file is
committed upstream, so this repo must vendor a document derived from those
modules (skeleton below).

## Contract deltas: prose contract vs published spec

Sources: `docs/color-matching-api-contract.md` (prose) vs
`viamin/color_matching@main` `api_schemas.ex`, `router.ex`,
`capture_controller.ex`, `test_sheet_controller.ex`, `test_sheet_json.ex`.

1. **Upload responses now carry JSON receipts.** The prose contract documents
   no response for measurement/judgment upload (the app's tests assumed
   `204 No Content`). The real API returns `200 OK` with
   `{"capture_id", "measurement_count", "pair_score_count"}` for measurements
   and `{"capture_id", "judgment_count"}` for judgments
   (`MeasurementUploadResponse`, `JudgmentUploadResponse`).
2. **`printer_profile` shape differs.** Prose: `{id, name, paper, ink,
   settings}`. Served manifest/ranked-results render
   `{printer_make_model, paper_type, ink_type, icc_profile, print_settings,
   driver_name, driver_version, calibration_date, calibration_version, notes}`.
   The published `PrinterProfile` schema only documents the simpler palette
   endpoint shape (`{id, printer_make_model, paper_type, ink_type}`).
3. **`CaptureRequest` accepts a second, flat shape** via `anyOf` (top-level
   `device_model`, `lens`, `exposure_duration`, `rejection_reasons`, ...). Note
   the flat variant renames keys: `exposure_duration` (vs nested
   `exposure_duration_seconds`) and `rejection_reasons` (vs nested
   `rejections`). The app's nested `metadata` + `quality` form remains valid.
4. **Per-measurement `stats` is not in the spec.** The app uploads
   `stats {sample_count, clipping_fraction, mean, standard_deviation}`; the
   published `MeasurementUploadRequest` items only document `patch_id`,
   `linear_rgb_median`, `normalized_linear_rgb_median`. Extra keys are
   tolerated at runtime (open objects) but are not guaranteed by the contract.
5. **Top-level `scoring_algorithm_version` on measurement upload is not in the
   spec** (the app sends it; tolerated, undocumented).
6. **`normalized_linear_rgb_median` is required** per measurement item in the
   spec; the prose example implies it but does not require it.
7. **`iso` is an integer** in `CaptureMetadata` (the app model uses `Float`).
8. **`capture_profile.scoring_algorithm_version` is required** (enum
   `lps-distance-v1`) — the prose presents it as descriptive metadata.
9. **Patch IDs embed the pair and side**: the server renders
   `"{pair_id}#first"` / `"{pair_id}#second"` (prose examples show opaque
   `patch_1`). IDs must stay opaque to the app.
10. **Recent sheets always render `title: null`** today; the spec keeps it
    required-but-nullable.
11. **`capture_id` is the string form of a numeric id**
    (`Integer.to_string(capture.id)`); path params for captures are numeric
    strings.
12. **`schema_version` enums are machine-enforced**: manifest responses must be
    `lps-sheet-manifest/v1`; ranked results `lps-ranked-results/v1`.
13. **Errors are documented**: `401` on all endpoints, `404` for unknown
    sheet/capture, `422` with `{"errors": ...}` for invalid payloads, plus
    `405` catch-all routes on read endpoints.

## Endpoint gaps discovered

- **Ranked results schema is a stub.** The published `RankedResults` schema
  documents only `{schema_version, sheet_id}`, but the served payload is rich
  (printer profile, capture counts/timestamps, per-pair rows with rank, source
  colors, aggregate scores, current judgment, observation counts). Everything
  beyond the two documented fields is de facto (open-object) and invisible to
  a generated client.
- **Manifest schema is a stub for the app's needs.** Only `schema_version`,
  `sheet_id`, `capture_profile.scoring_algorithm_version` are documented. The
  app's sampler depends on `page`, `registration_markers`, `patches`, `pairs`,
  `sheet_version`, `manifest_url` — all undocumented-but-served.
- **Endpoints absent from the prose contract**: `GET /api/v1/openapi.json`,
  `GET /api/v1/printer_profiles[...]`, `GET /api/v1/palettes`,
  `GET /api/v1/colors`, `POST /api/illuminant_measurements[/bulk]`,
  `POST /api/multi_image_mapping`.
- Follow-up to file upstream: publish the served manifest/ranked-results
  fields in open_api_spex so the vendored enrichment below can be dropped.

Because of the two stub schemas, the vendored document (below) **enriches**
`TestSheetManifest` and `RankedResults` with the fields the server actually
renders (derived from `test_sheet_json.ex`), kept optional except where
upstream requires them. Enriched fields stay optional so the vendored doc does
not over-promise beyond what open_api_spex enforces.

## Implementation contract (for the follow-up run)

`iOS/Package.swift` adds:

- `.package(url: "https://github.com/apple/swift-openapi-generator", from: "1.7.0")`
- `.package(url: "https://github.com/apple/swift-openapi-runtime", from: "1.7.0")`
- `.package(url: "https://github.com/apple/swift-openapi-urlsession", from: "1.0.0")`
- target `OpenAPIGenerated`: depends on `OpenAPIRuntime`, plugin
  `OpenAPIGenerator` (client mode), with the vendored document at
  `iOS/Sources/OpenAPIGenerated/openapi.yaml`.
- `ColorMatchingLPSAppCore` depends on `OpenAPIGenerated`;
  `ColorMatchingLPSAppTests` depends on `OpenAPIGenerated` +
  `OpenAPIURLSession`.
- `APIClient` keeps its public surface (existing `APIClientTests` stay green)
  and is reimplemented on top of the generated `Client` with a bearer-token
  `ClientMiddleware`. `MeasurementCore` models stay as-is (pure client-side);
  hand-written Codable API models (`CaptureMetadata`, `WhiteBalanceGains`,
  `CaptureSessionResponse`, `RecentSheet`, upload request types) are replaced
  by generated `Components.Schemas` types.

Operation IDs (the generator derives client method names from these; the tests
call exactly these): `getTestSheetManifest`, `listRecentTestSheets`,
`createCapture`, `uploadMeasurements`, `uploadJudgments`, `getRankedResults`.
Path parameter names must stay `sheet_id` / `capture_id`.

### Vendored openapi.yaml skeleton

```yaml
openapi: 3.0.3
info:
  title: Color Matching API
  version: v1
servers:
  - url: /
security:
  - bearerAuth: []
paths:
  /api/v1/test_sheets/{sheet_id}/manifest:
    get:
      operationId: getTestSheetManifest
      parameters:
        - name: sheet_id
          in: path
          required: true
          schema: { type: string }
      responses:
        '200':
          description: Sheet manifest
          content:
            application/json:
              schema: { $ref: '#/components/schemas/TestSheetManifest' }
        '401': { $ref: '#/components/responses/Unauthorized' }
        '404': { $ref: '#/components/responses/NotFound' }
  /api/v1/test_sheets/recent:
    get:
      operationId: listRecentTestSheets
      responses:
        '200':
          description: Recent sheets
          content:
            application/json:
              schema: { $ref: '#/components/schemas/RecentSheetsResponse' }
        '401': { $ref: '#/components/responses/Unauthorized' }
  /api/v1/test_sheets/{sheet_id}/ranked_results:
    get:
      operationId: getRankedResults
      parameters:
        - name: sheet_id
          in: path
          required: true
          schema: { type: string }
      responses:
        '200':
          description: Ranked results
          content:
            application/json:
              schema: { $ref: '#/components/schemas/RankedResults' }
        '401': { $ref: '#/components/responses/Unauthorized' }
        '404': { $ref: '#/components/responses/NotFound' }
  /api/v1/test_sheets/{sheet_id}/captures:
    post:
      operationId: createCapture
      parameters:
        - name: sheet_id
          in: path
          required: true
          schema: { type: string }
      requestBody:
        required: true
        content:
          application/json:
            schema: { $ref: '#/components/schemas/CaptureRequest' }
      responses:
        '201':
          description: Capture created
          content:
            application/json:
              schema: { $ref: '#/components/schemas/CaptureCreatedResponse' }
        '401': { $ref: '#/components/responses/Unauthorized' }
        '404': { $ref: '#/components/responses/NotFound' }
        '422': { $ref: '#/components/responses/UnprocessableContent' }
  /api/v1/captures/{capture_id}/measurements:
    post:
      operationId: uploadMeasurements
      parameters:
        - name: capture_id
          in: path
          required: true
          schema: { type: string }
      requestBody:
        required: true
        content:
          application/json:
            schema: { $ref: '#/components/schemas/MeasurementUploadRequest' }
      responses:
        '200':
          description: Measurements accepted
          content:
            application/json:
              schema: { $ref: '#/components/schemas/MeasurementUploadResponse' }
        '401': { $ref: '#/components/responses/Unauthorized' }
        '404': { $ref: '#/components/responses/NotFound' }
        '422': { $ref: '#/components/responses/UnprocessableContent' }
  /api/v1/captures/{capture_id}/judgments:
    post:
      operationId: uploadJudgments
      parameters:
        - name: capture_id
          in: path
          required: true
          schema: { type: string }
      requestBody:
        required: true
        content:
          application/json:
            schema: { $ref: '#/components/schemas/JudgmentUploadRequest' }
      responses:
        '200':
          description: Judgments accepted
          content:
            application/json:
              schema: { $ref: '#/components/schemas/JudgmentUploadResponse' }
        '401': { $ref: '#/components/responses/Unauthorized' }
        '404': { $ref: '#/components/responses/NotFound' }
        '422': { $ref: '#/components/responses/UnprocessableContent' }
components:
  securitySchemes:
    bearerAuth: { type: http, scheme: bearer, bearerFormat: API token }
  responses:
    Unauthorized:
      description: Unauthorized
      content:
        application/json:
          schema: { $ref: '#/components/schemas/ApiErrorResponse' }
    NotFound:
      description: Resource not found
      content:
        application/json:
          schema: { $ref: '#/components/schemas/ApiErrorResponse' }
    UnprocessableContent:
      description: Invalid payload
      content:
        application/json:
          schema: { $ref: '#/components/schemas/ApiErrorResponse' }
  schemas:
    TestSheetManifest:
      type: object
      required: [schema_version, sheet_id, capture_profile]
      properties:
        schema_version:
          type: string
          enum: [lps-sheet-manifest/v1]
        sheet_id: { type: string }
        sheet_version: { type: string }
        manifest_url: { type: string }
        created_at: { type: string, format: date-time, nullable: true }
        page:
          type: object
          required: [units, width, height]
          properties:
            units: { type: string }
            width: { type: number }
            height: { type: number }
        registration_markers:
          type: array
          items: { $ref: '#/components/schemas/RegistrationMarker' }
        printer_profile: { type: object, additionalProperties: true }
        capture_profile:
          type: object
          required: [scoring_algorithm_version]
          properties:
            expected_illuminant: { type: string }
            preferred_camera: { type: string }
            scoring_algorithm_version:
              type: string
              enum: [lps-distance-v1]
        patches:
          type: array
          items: { $ref: '#/components/schemas/Patch' }
        pairs:
          type: array
          items: { $ref: '#/components/schemas/PairManifest' }
    RegistrationMarker:
      type: object
      required: [role, shape, rect]
      properties:
        role: { type: string }
        shape: { type: string }
        rect: { $ref: '#/components/schemas/Rect' }
    Rect:
      type: object
      required: [x, y, width, height]
      properties:
        x: { type: number }
        y: { type: number }
        width: { type: number }
        height: { type: number }
    Patch:
      type: object
      required: [id, role, pair_id, pair_side, source_color, safe_inset_mm, rect]
      properties:
        id: { type: string }
        role: { type: string }
        pair_id: { type: string }
        pair_side: { type: string }
        reference_role: { type: string, nullable: true }
        source_color: { type: string }
        safe_inset_mm: { type: number }
        rect: { $ref: '#/components/schemas/Rect' }
    PairManifest:
      type: object
      required: [id, first_patch_id, second_patch_id, source_colors, grid_row, grid_col]
      properties:
        id: { type: string }
        first_patch_id: { type: string }
        second_patch_id: { type: string }
        source_colors:
          type: array
          items: { type: string }
        grid_row: { type: integer }
        grid_col: { type: integer }
    RecentSheetsResponse:
      type: object
      required: [sheets]
      properties:
        sheets:
          type: array
          items:
            type: object
            required: [sheet_id, manifest_url, title]
            properties:
              sheet_id: { type: string }
              manifest_url: { type: string }
              title: { type: string, nullable: true }
    CaptureMetadata:
      type: object
      required: [device_model, lens, image_width, image_height, app_version, timestamp]
      properties:
        device_model: { type: string }
        lens: { type: string }
        exposure_duration_seconds: { type: number, exclusiveMinimum: 0 }
        iso: { type: integer, exclusiveMinimum: 0 }
        focus_lens_position: { type: number, minimum: 0 }
        white_balance_gains: { type: object }
        image_width: { type: integer, exclusiveMinimum: 0 }
        image_height: { type: integer, exclusiveMinimum: 0 }
        app_version: { type: string }
        timestamp: { type: string, format: date-time }
    CaptureRequest:
      type: object
      properties:
        device_model: { type: string }
        lens: { type: string }
        exposure_duration: { type: number, exclusiveMinimum: 0 }
        iso: { type: integer, exclusiveMinimum: 0 }
        focus_lens_position: { type: number, minimum: 0 }
        white_balance_gains: { type: object }
        image_width: { type: integer, exclusiveMinimum: 0 }
        image_height: { type: integer, exclusiveMinimum: 0 }
        app_version: { type: string }
        timestamp: { type: string, format: date-time }
        detected_marker_count: { type: integer, minimum: 0 }
        blur_score: { type: number, minimum: 0 }
        rejection_reasons:
          type: array
          items: { type: string }
        metadata: { $ref: '#/components/schemas/CaptureMetadata' }
        quality:
          type: object
          properties:
            detected_marker_count: { type: integer, minimum: 0 }
            blur_score: { type: number, minimum: 0 }
            rejections:
              type: array
              items: { type: string }
      anyOf:
        - required: [device_model, lens, image_width, image_height, app_version, timestamp]
        - required: [metadata]
    CaptureCreatedResponse:
      type: object
      required: [capture_id]
      properties:
        capture_id: { type: string }
    RgbPayload:
      description: >-
        An RGB array, an object with r/g/b channels, or a JSON-encoded
        representation.
      anyOf:
        - type: array
          items: { type: number }
        - type: object
          required: [r, g, b]
          properties:
            r: { type: number }
            g: { type: number }
            b: { type: number }
        - type: string
    PairScoreRequest:
      type: object
      required: [pair_id, algorithm_version]
      properties:
        pair_id: { type: string }
        algorithm_version: { type: string }
        score: { type: number }
        similarity: { type: number }
        distance: { type: number }
      anyOf:
        - required: [score]
        - required: [similarity]
        - required: [distance]
    MeasurementUploadRequest:
      type: object
      properties:
        measurements:
          type: array
          items:
            type: object
            required: [patch_id, linear_rgb_median, normalized_linear_rgb_median]
            properties:
              patch_id: { type: string }
              linear_rgb_median: { $ref: '#/components/schemas/RgbPayload' }
              normalized_linear_rgb_median: { $ref: '#/components/schemas/RgbPayload' }
        pair_scores:
          type: array
          items: { $ref: '#/components/schemas/PairScoreRequest' }
    MeasurementUploadResponse:
      type: object
      required: [capture_id, measurement_count, pair_score_count]
      properties:
        capture_id: { type: string }
        measurement_count: { type: integer }
        pair_score_count: { type: integer }
    JudgmentUploadRequest:
      type: object
      required: [judgments]
      properties:
        judgments:
          type: array
          items:
            type: object
            required: [pair_id, judgment]
            properties:
              pair_id: { type: string }
              judgment: { type: string }
    JudgmentUploadResponse:
      type: object
      required: [capture_id, judgment_count]
      properties:
        capture_id: { type: string }
        judgment_count: { type: integer }
    RankedResults:
      type: object
      required: [schema_version, sheet_id]
      properties:
        schema_version:
          type: string
          enum: [lps-ranked-results/v1]
        sheet_id: { type: string }
        capture_count: { type: integer }
        latest_capture_at: { type: string, format: date-time, nullable: true }
        earliest_capture_at: { type: string, format: date-time, nullable: true }
        scoring_algorithm_versions:
          type: array
          items: { type: string }
        results:
          type: array
          items: { $ref: '#/components/schemas/RankedPairResult' }
    RankedPairResult:
      type: object
      required: [rank, pair_id, scoring_algorithm_version, row, col]
      properties:
        rank: { type: integer }
        pair_id: { type: string }
        scoring_algorithm_version: { type: string }
        row: { type: integer }
        col: { type: integer }
        source_colors:
          type: object
          required: [color_a_hex, color_b_hex]
          properties:
            color_a_hex: { type: string }
            color_b_hex: { type: string }
        score:
          type: object
          required: [average, latest, minimum, maximum]
          properties:
            average: { type: number }
            latest: { type: number }
            minimum: { type: number }
            maximum: { type: number }
        current_judgment: { type: string, nullable: true }
        observation_count: { type: integer }
    ApiErrorResponse:
      type: object
      required: [errors]
      properties:
        errors:
          oneOf:
            - type: object
              additionalProperties: true
            - type: array
              items:
                type: object
                required: [detail, source]
                properties:
                  detail: { type: string }
                  source:
                    type: object
                    required: [pointer]
                    properties:
                      pointer: { type: string }
```

## Acceptance criteria to verification map

| Deliverable | Verification | Where |
| --- | --- | --- |
| Generator + runtime deps; vendored spec | `swift build` resolves deps; `OpenAPIGenerated` target exists | Implementation run; blocked here (tests-only phase) |
| Client for manifest, recent sheets, capture creation, measurement upload, judgment upload, ranked results | Unit tests against stubbed URLProtocol responses (paths, methods, bodies, decoded types, status-case mapping) | `GeneratedClientTests.swift` (9 tests) |
| Hand-written API models replaced; client-side models kept | Existing facade tests must stay green while internals swap | `APIClientTests.swift` (unchanged except real-API response fixtures) |
| Tests use local stubs, no live server | All requests served by `StubAPIURLProtocol`; no network | `GeneratedClientTestSupport.swift` |
| PR records contract deltas + gaps | Delta list + gap list above, carried into the PR description | this document |
| `swift test --disable-sandbox` green with generated types | CI on macOS after implementation run | `.github/workflows/ci.yml` |

These are permanent unit tests in the Swift package (recurring regression
coverage for the API surface), not one-off flows, so no `.ephemeral-tests/`
entry is warranted.

## Red-phase expectations

- `iOS/Tests/ColorMatchingLPSAppTests/GeneratedClientTests.swift` fails to
  build with "no such module 'OpenAPIGenerated'" until the vendored spec and
  target exist. This is the intended missing-behavior signal.
- `APIClientTests` remain green before and after the implementation swap (they
  now stub the real `200` + receipt responses).
- The generated-client tests rely on documented swift-openapi-generator naming
  rules (operationId-derived method names; `ok`/`created`/`unauthorized`/
  `notFound`/`unprocessableContent` status cases; `valueN` for `anyOf`;
  `Payload` suffix for inline schemas; `rawValue` string enums). If a
  generator version emits a different spelling, adjust the vendored spec
  operation IDs or the test call sites in the implementation run — the
  asserted wire contract (paths, JSON keys, decoded values) must not change.
