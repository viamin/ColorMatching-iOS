# OpenAPI Generated Client Migration Plan (#5)

Status: test-writing phase complete; implementation phase pending. This document
is the authoritative plan for the implementation run and the source material
for the PR description deliverables ("what changed between the prose contract
and the published spec" and "endpoint gaps discovered").

## Dependency status

viamin/color_matching#110 ("Publish OpenAPI 3 spec for the /api/v1 API and
enforce it in CI") is **closed as completed** by viamin/color_matching#113
(merged). The spec is not committed as a static file: it is generated from
OpenApiSpex (`lib/color_matching_web/api_spec.ex` + `api_schemas.ex`) and
served at `GET /api/v1/openapi.json`. The iOS app therefore **vendors** a
reconstructed document (below) restricted to the surfaces the app uses, typed
to the JSON the server actually renders.

## Acceptance criteria → verification map

| # | Criterion | Smallest credible verification | Where |
|---|---|---|---|
| AC-1 | `swift-openapi-generator` + `swift-openapi-runtime` added; OpenAPI document vendored | Structural unit test asserting the vendored document exists and covers the 6 operation IDs + paths | `iOS/Tests/ColorMatchingLPSAppTests/VendoredOpenAPIDocumentTests.swift` |
| AC-2 | Client generated for manifest, recent sheets, capture creation, measurement upload, judgment upload, ranked results | Unit tests exercising each generated operation against a stubbed `ClientTransport` (request shape + typed decode) | `iOS/Tests/ColorMatchingLPSAppTests/GeneratedClientContractTests.swift` |
| AC-3 | Hand-written API models replaced with generated types; client-side models kept | Wrapper tests asserting generated types surface at the app boundary and `MeasurementCore` domain models are mapped, not re-declared | `iOS/Tests/ColorMatchingLPSAppTests/ColorMatchingAPIClientTests.swift` |
| AC-4 | Swift tests against local stubbed responses, no live server | All tests above run against `StubTransport` / stubbed `ClientTransport`; zero network | same files |
| AC-5 | PR description records contract deltas + endpoint gaps | Delta table below, to be copied into the PR body | `docs/openapi-client-migration-plan.md` (this file) |
| AC-6 | `swift test --disable-sandbox` green with generated types wired in | CI (macOS) after implementation; not runnable in the Linux container (no Swift toolchain) — recorded as pending | CI run at PR head |

## Target architecture (pinned names)

The tests committed in this phase compile only once the implementation run
lands exactly this shape. Names are pinned here so tests and implementation
agree:

```
iOS/
  Package.swift                      # tools-version 6.2; deps below
  Sources/ColorMatchingAPI/
    openapi.yaml                     # vendored document (full text below)
  Sources/ColorMatchingLPSAppCore/
    ColorMatchingAPIClient.swift     # wrapper replacing APIClient.swift
```

Package changes:

- Bump `swift-tools-version` to `6.2` (required by swift-openapi-generator
  1.14.x / swift-openapi-runtime 1.13.x; Xcode 16.2+ on `macos-latest`).
- Dependencies:
  - `https://github.com/apple/swift-openapi-generator`, `from: "1.14.0"`
    (plugin product `OpenAPIGenerator`)
  - `https://github.com/apple/swift-openapi-runtime`, `from: "1.13.0"`
    (library product `OpenAPIRuntime`)
  - `https://github.com/apple/swift-openapi-urlsession`, `from: "1.0.0"`
    (library product `URLSessionTransport`) for the production transport.
- New target `ColorMatchingAPI` (module `ColorMatchingAPI`), depends on
  `OpenAPIRuntime`, applies the `OpenAPIGenerator` build tool plugin. The
  plugin reads `openapi.yaml` from the target directory by default.
- `ColorMatchingLPSAppCore` depends on `ColorMatchingAPI`.
- `ColorMatchingLPSAppTests` depends on `ColorMatchingLPSAppCore`,
  `MeasurementCore`, `ColorMatchingAPI`, and `OpenAPIRuntime`.
- Delete `iOS/Sources/ColorMatchingLPSAppCore/APIClient.swift` (hand-written
  DTOs `CaptureMetadata`, `WhiteBalanceGains`, `CaptureSessionResponse`,
  `RecentSheet`, `PairJudgment`, `APIError` are replaced by generated types;
  `MeasurementCore` stays untouched — those models are purely client-side).

### Generated naming contract

Derived from the vendored document by swift-openapi-generator:

| OpenAPI | Generated Swift |
|---|---|
| operationId `getTestSheetManifest` | `ColorMatchingAPI.Client.getTestSheetManifest(_:)`, `Operations.getTestSheetManifest` |
| operationId `listRecentTestSheets` | `Operations.listRecentTestSheets` |
| operationId `getRankedResults` | `Operations.getRankedResults` |
| operationId `createCapture` | `Operations.createCapture` |
| operationId `uploadMeasurements` | `Operations.uploadMeasurements` |
| operationId `uploadJudgments` | `Operations.uploadJudgments` |
| path param `sheet_id` / `capture_id` | `Input.Path.sheetId` / `captureId` |
| status 200/201/401/404/422 | output cases `.ok` / `.created` / `.unauthorized` / `.notFound` / `.unprocessableEntity` |
| JSON request body | `Input(body: .json(Components.Schemas.X))` |
| JSON response body | `case .ok(let p)` then `case .json(let v) = p.body` |
| `*_id`/`*_url` snake_case properties | camelCase (`captureId`, `manifestUrl`, …) |
| `type: string, format: date-time` | `Foundation.Date` |
| `nullable: true` | Optional property |
| component schema `X` | `Components.Schemas.X` |

Component schemas defined (exact names used by tests): `Rect`,
`RgbChannelValues`, `PageSpec`, `RegistrationMarker`, `PrinterProfile`,
`CaptureProfile`, `Patch`, `PairManifestEntry`, `TestSheetManifest`,
`RecentSheet`, `RecentSheetsResponse`, `WhiteBalanceGains`, `CaptureMetadata`,
`CaptureQuality`, `CaptureRequest`, `CaptureCreatedResponse`,
`MeasurementStats`, `MeasurementEntry`, `PairScoreEntry`,
`MeasurementUploadRequest`, `MeasurementUploadResponse`, `PairJudgmentEntry`,
`JudgmentUploadRequest`, `JudgmentUploadResponse`, `SourceColorPair`,
`AggregateScore`, `RankedResultEntry`, `RankedResultsResponse`,
`ApiErrorResponse`.

### Wrapper API (replaces `APIClient`)

```swift
public enum ColorMatchingAPIError: Error, Equatable {
    case unexpectedStatusCode(Int)
}

public struct ColorMatchingAPIClient {
    public init(token: String? = nil, transport: (any ClientTransport)? = nil)
    // transport defaults to URLSessionTransport(); token applied via a
    // ClientMiddleware that sets `Authorization: Bearer <token>` when non-empty

    public func fetchManifest(from url: URL) async throws -> SheetManifest
    public func fetchManifest(baseURL: URL, sheetCode: String) async throws -> SheetManifest
    public func fetchRecentSheets(baseURL: URL) async throws -> [Components.Schemas.RecentSheet]
    public func createCapture(
        sheetID: String, baseURL: URL,
        metadata: Components.Schemas.CaptureMetadata,
        quality: CaptureQuality
    ) async throws -> String
    public func uploadMeasurements(
        captureID: String, baseURL: URL,
        measurements: [PatchMeasurement], scores: [PairScore]
    ) async throws -> Components.Schemas.MeasurementUploadResponse
    public func uploadJudgments(
        captureID: String, baseURL: URL,
        judgments: [Components.Schemas.PairJudgmentEntry]
    ) async throws -> Components.Schemas.JudgmentUploadResponse
    public func fetchRankedResults(
        sheetID: String, baseURL: URL
    ) async throws -> Components.Schemas.RankedResultsResponse
}
```

Mapping rules pinned by the wrapper tests:

- Generated manifest → `MeasurementCore.SheetManifest` (sheetID, page,
  registrationMarkers, patches, pairs; `manifestURL` parsed to `URL`).
- `PatchMeasurement` → generated `MeasurementEntry` with `stats` mapped from
  `ChannelStats` (sample_count, clipping_fraction, mean, standard_deviation;
  min/max/median dropped — the server does not store them).
- `PairScore` → generated `PairScoreEntry` (`pairId`, `algorithmVersion`,
  `similarity`, `distance`). No top-level `scoring_algorithm_version` — the
  published schema dropped it and the server ignores it.
- `normalized_linear_rgb_median` is sent when the measurement has one
  (published schema marks it required; server accepts absence — recorded as a
  delta, vendored document keeps it optional).
- Non-2xx responses throw `ColorMatchingAPIError.unexpectedStatusCode(code)`.

## Vendored OpenAPI document

Copy verbatim to `iOS/Sources/ColorMatchingAPI/openapi.yaml`:

```yaml
openapi: 3.0.3
info:
  title: Color Matching API
  version: v1
  description: >
    Vendored subset of the OpenAPI document published by viamin/color_matching
    at /api/v1/openapi.json (issue #110, PR #113), restricted to the surfaces
    used by the iOS companion app and typed to the JSON the server actually
    renders. Deltas vs the published document are recorded in
    docs/openapi-client-migration-plan.md in the companion-app repository.
servers:
  - url: /
security:
  - bearerAuth: []
paths:
  /api/v1/test_sheets/recent:
    get:
      operationId: listRecentTestSheets
      summary: List recent test sheets
      security:
        - bearerAuth: []
      responses:
        '200':
          description: Recent sheets
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/RecentSheetsResponse'
        '401':
          $ref: '#/components/responses/Unauthorized'
  /api/v1/test_sheets/{sheet_id}/manifest:
    get:
      operationId: getTestSheetManifest
      summary: Fetch a test sheet manifest
      security:
        - bearerAuth: []
      parameters:
        - name: sheet_id
          in: path
          required: true
          description: Lookup code of the test sheet.
          schema:
            type: string
      responses:
        '200':
          description: Sheet manifest
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/TestSheetManifest'
        '401':
          $ref: '#/components/responses/Unauthorized'
        '404':
          $ref: '#/components/responses/NotFound'
  /api/v1/test_sheets/{sheet_id}/ranked_results:
    get:
      operationId: getRankedResults
      summary: Fetch ranked results for a test sheet
      security:
        - bearerAuth: []
      parameters:
        - name: sheet_id
          in: path
          required: true
          description: Lookup code of the test sheet.
          schema:
            type: string
      responses:
        '200':
          description: Ranked results
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/RankedResultsResponse'
        '401':
          $ref: '#/components/responses/Unauthorized'
        '404':
          $ref: '#/components/responses/NotFound'
  /api/v1/test_sheets/{sheet_id}/captures:
    post:
      operationId: createCapture
      summary: Create a capture for a test sheet
      security:
        - bearerAuth: []
      parameters:
        - name: sheet_id
          in: path
          required: true
          description: Lookup code of the test sheet.
          schema:
            type: string
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/CaptureRequest'
      responses:
        '201':
          description: Capture created
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/CaptureCreatedResponse'
        '401':
          $ref: '#/components/responses/Unauthorized'
        '404':
          $ref: '#/components/responses/NotFound'
        '422':
          $ref: '#/components/responses/UnprocessableEntity'
  /api/v1/captures/{capture_id}/measurements:
    post:
      operationId: uploadMeasurements
      summary: Upload capture measurements
      security:
        - bearerAuth: []
      parameters:
        - name: capture_id
          in: path
          required: true
          description: Identifier returned by createCapture.
          schema:
            type: string
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/MeasurementUploadRequest'
      responses:
        '200':
          description: Measurements accepted
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/MeasurementUploadResponse'
        '401':
          $ref: '#/components/responses/Unauthorized'
        '404':
          $ref: '#/components/responses/NotFound'
        '422':
          $ref: '#/components/responses/UnprocessableEntity'
  /api/v1/captures/{capture_id}/judgments:
    post:
      operationId: uploadJudgments
      summary: Upload capture judgments
      security:
        - bearerAuth: []
      parameters:
        - name: capture_id
          in: path
          required: true
          description: Identifier returned by createCapture.
          schema:
            type: string
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/JudgmentUploadRequest'
      responses:
        '200':
          description: Judgments accepted
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/JudgmentUploadResponse'
        '401':
          $ref: '#/components/responses/Unauthorized'
        '404':
          $ref: '#/components/responses/NotFound'
        '422':
          $ref: '#/components/responses/UnprocessableEntity'
components:
  securitySchemes:
    bearerAuth:
      type: http
      scheme: bearer
      bearerFormat: API token
  responses:
    Unauthorized:
      description: Unauthorized
      content:
        application/json:
          schema:
            $ref: '#/components/schemas/ApiErrorResponse'
    NotFound:
      description: Not found
      content:
        application/json:
          schema:
            $ref: '#/components/schemas/ApiErrorResponse'
    UnprocessableEntity:
      description: Invalid request payload
      content:
        application/json:
          schema:
            $ref: '#/components/schemas/ApiErrorResponse'
  schemas:
    Rect:
      type: object
      required: [x, y, width, height]
      properties:
        x: { type: number }
        y: { type: number }
        width: { type: number }
        height: { type: number }
    RgbChannelValues:
      type: object
      description: >-
        Linear RGB channel values. The server also accepts arrays and
        JSON-encoded strings (published RgbPayload anyOf); the app sends and
        receives the object form only.
      required: [r, g, b]
      properties:
        r: { type: number }
        g: { type: number }
        b: { type: number }
    PageSpec:
      type: object
      required: [units, width, height]
      properties:
        units: { type: string }
        width: { type: number }
        height: { type: number }
    RegistrationMarker:
      type: object
      required: [role, shape, rect]
      properties:
        role: { type: string }
        shape: { type: string }
        rect:
          $ref: '#/components/schemas/Rect'
    PrinterProfile:
      type: object
      description: >-
        Typed for the fields the app consumes. The server also emits
        icc_profile, print_settings, driver_name, driver_version,
        calibration_date, calibration_version, and notes; undocumented
        properties are ignored by the generated decoder.
      required: [printer_make_model, paper_type, ink_type]
      properties:
        printer_make_model: { type: string }
        paper_type: { type: string }
        ink_type: { type: string }
    CaptureProfile:
      type: object
      required: [expected_illuminant, preferred_camera, scoring_algorithm_version]
      properties:
        expected_illuminant: { type: string }
        preferred_camera: { type: string }
        scoring_algorithm_version: { type: string }
    Patch:
      type: object
      required: [id, role, pair_id, pair_side, reference_role, source_color, safe_inset_mm, rect]
      properties:
        id: { type: string }
        role: { type: string }
        pair_id: { type: string, nullable: true }
        pair_side: { type: string, nullable: true }
        reference_role: { type: string, nullable: true }
        source_color: { type: string, nullable: true }
        safe_inset_mm: { type: number }
        rect:
          $ref: '#/components/schemas/Rect'
    PairManifestEntry:
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
    TestSheetManifest:
      type: object
      description: >-
        Full manifest as rendered by the server. The published document only
        types schema_version, sheet_id, and
        capture_profile.scoring_algorithm_version; the fields below match the
        server's actual JSON rendering.
      required:
        - schema_version
        - sheet_version
        - sheet_id
        - manifest_url
        - created_at
        - page
        - registration_markers
        - printer_profile
        - capture_profile
        - patches
        - pairs
      properties:
        schema_version: { type: string }
        sheet_version: { type: string }
        sheet_id: { type: string }
        manifest_url: { type: string }
        created_at: { type: string, format: date-time, nullable: true }
        page:
          $ref: '#/components/schemas/PageSpec'
        registration_markers:
          type: array
          items:
            $ref: '#/components/schemas/RegistrationMarker'
        printer_profile:
          $ref: '#/components/schemas/PrinterProfile'
        capture_profile:
          $ref: '#/components/schemas/CaptureProfile'
        patches:
          type: array
          items:
            $ref: '#/components/schemas/Patch'
        pairs:
          type: array
          items:
            $ref: '#/components/schemas/PairManifestEntry'
    RecentSheet:
      type: object
      required: [sheet_id, manifest_url, title]
      properties:
        sheet_id: { type: string }
        manifest_url: { type: string }
        title: { type: string, nullable: true }
    RecentSheetsResponse:
      type: object
      required: [sheets]
      properties:
        sheets:
          type: array
          items:
            $ref: '#/components/schemas/RecentSheet'
    WhiteBalanceGains:
      type: object
      required: [red, green, blue]
      properties:
        red: { type: number }
        green: { type: number }
        blue: { type: number }
    CaptureMetadata:
      type: object
      required: [device_model, lens, image_width, image_height, app_version, timestamp]
      properties:
        device_model: { type: string }
        lens: { type: string }
        exposure_duration_seconds: { type: number }
        iso: { type: integer }
        focus_lens_position: { type: number }
        white_balance_gains:
          $ref: '#/components/schemas/WhiteBalanceGains'
        image_width: { type: integer }
        image_height: { type: integer }
        app_version: { type: string }
        timestamp: { type: string, format: date-time }
    CaptureQuality:
      type: object
      required: [detected_marker_count, blur_score, rejections]
      properties:
        detected_marker_count: { type: integer }
        blur_score: { type: number }
        rejections:
          type: array
          items: { type: string }
    CaptureRequest:
      type: object
      description: >-
        Nested form only. The published document also accepts a flat form via
        anyOf (device_model/lens/exposure_duration/rejection_reasons at the
        top level); the app uses the nested form exclusively.
      required: [metadata, quality]
      properties:
        metadata:
          $ref: '#/components/schemas/CaptureMetadata'
        quality:
          $ref: '#/components/schemas/CaptureQuality'
    CaptureCreatedResponse:
      type: object
      required: [capture_id]
      properties:
        capture_id: { type: string }
    MeasurementStats:
      type: object
      description: >-
        Robustness stats. The server accepts these nested under stats (or
        flat) and stores them, but the published MeasurementUploadRequest
        schema omits them entirely.
      required: [sample_count, clipping_fraction, mean, standard_deviation]
      properties:
        sample_count: { type: integer }
        clipping_fraction: { type: number }
        mean:
          $ref: '#/components/schemas/RgbChannelValues'
        standard_deviation:
          $ref: '#/components/schemas/RgbChannelValues'
    MeasurementEntry:
      type: object
      required: [patch_id, linear_rgb_median]
      properties:
        patch_id: { type: string }
        linear_rgb_median:
          $ref: '#/components/schemas/RgbChannelValues'
        normalized_linear_rgb_median:
          $ref: '#/components/schemas/RgbChannelValues'
        stats:
          $ref: '#/components/schemas/MeasurementStats'
    PairScoreEntry:
      type: object
      description: >-
        The published schema requires anyOf(score, similarity, distance); the
        app sends similarity and distance. The server stores similarity as the
        score, or 1 - distance.
      required: [pair_id, algorithm_version]
      properties:
        pair_id: { type: string }
        algorithm_version: { type: string }
        similarity: { type: number }
        distance: { type: number }
    MeasurementUploadRequest:
      type: object
      required: [measurements, pair_scores]
      properties:
        measurements:
          type: array
          items:
            $ref: '#/components/schemas/MeasurementEntry'
        pair_scores:
          type: array
          items:
            $ref: '#/components/schemas/PairScoreEntry'
    MeasurementUploadResponse:
      type: object
      required: [capture_id, measurement_count, pair_score_count]
      properties:
        capture_id: { type: string }
        measurement_count: { type: integer }
        pair_score_count: { type: integer }
    PairJudgmentEntry:
      type: object
      required: [pair_id, judgment]
      properties:
        pair_id: { type: string }
        judgment: { type: string }
    JudgmentUploadRequest:
      type: object
      required: [judgments]
      properties:
        judgments:
          type: array
          items:
            $ref: '#/components/schemas/PairJudgmentEntry'
    JudgmentUploadResponse:
      type: object
      required: [capture_id, judgment_count]
      properties:
        capture_id: { type: string }
        judgment_count: { type: integer }
    SourceColorPair:
      type: object
      required: [color_a_hex, color_b_hex]
      properties:
        color_a_hex: { type: string }
        color_b_hex: { type: string }
    AggregateScore:
      type: object
      required: [average, latest, minimum, maximum, capture_count, sample_count, algorithm_versions]
      properties:
        average: { type: number }
        latest: { type: number }
        minimum: { type: number }
        maximum: { type: number }
        capture_count: { type: integer }
        sample_count: { type: integer }
        algorithm_versions:
          type: array
          items: { type: string }
    RankedResultEntry:
      type: object
      description: >-
        The server also emits latest_observation {judgment, observed_at};
        deliberately omitted here (current_judgment covers the app's need)
        and ignored on decode.
      required:
        - rank
        - pair_id
        - scoring_algorithm_version
        - row
        - col
        - source_colors
        - score
        - current_judgment
        - current_judgment_observed_at
        - observation_count
        - capture_count
        - latest_capture_at
        - earliest_capture_at
      properties:
        rank: { type: integer }
        pair_id: { type: string }
        scoring_algorithm_version: { type: string }
        row: { type: integer }
        col: { type: integer }
        source_colors:
          $ref: '#/components/schemas/SourceColorPair'
        score:
          $ref: '#/components/schemas/AggregateScore'
        current_judgment: { type: string, nullable: true }
        current_judgment_observed_at: { type: string, format: date-time, nullable: true }
        observation_count: { type: integer }
        capture_count: { type: integer }
        latest_capture_at: { type: string, format: date-time, nullable: true }
        earliest_capture_at: { type: string, format: date-time, nullable: true }
    RankedResultsResponse:
      type: object
      description: >-
        Full aggregate payload as rendered by the server. The published
        document only types schema_version and sheet_id.
      required:
        - schema_version
        - sheet_id
        - printer_profile
        - capture_count
        - latest_capture_at
        - earliest_capture_at
        - scoring_algorithm_versions
        - results
      properties:
        schema_version: { type: string }
        sheet_id: { type: string }
        printer_profile:
          $ref: '#/components/schemas/PrinterProfile'
        capture_count: { type: integer }
        latest_capture_at: { type: string, format: date-time, nullable: true }
        earliest_capture_at: { type: string, format: date-time, nullable: true }
        scoring_algorithm_versions:
          type: array
          items: { type: string }
        results:
          type: array
          items:
            $ref: '#/components/schemas/RankedResultEntry'
    ApiErrorResponse:
      type: object
      required: [errors]
      properties:
        errors:
          type: object
          description: Error details; shape varies (detail string or field-keyed messages).
```

## Contract deltas: prose contract vs published spec vs actual server

Sources: `docs/color-matching-api-contract.md` (prose),
`viamin/color_matching@main` `lib/color_matching_web/api_schemas.ex` +
controllers + `test_sheet_json.ex` (published spec and actual rendering),
`lib/color_matching/persistence/capture_upload.ex` (actual validation).

| Surface | Prose contract | Published spec | Actual server | Client impact |
|---|---|---|---|---|
| Spec document | — | `GET /api/v1/openapi.json` (unauthenticated) | ✓ | none (vendor target) |
| Manifest shape | rich manifest | only `schema_version`, `sheet_id`, `capture_profile.scoring_algorithm_version` typed | full rich JSON | vendored doc types the full payload; spec under-documents |
| Patch IDs | `patch_1` style | untyped | `{pair_id}#first` / `{pair_id}#second` | tests pin the real format |
| `printer_profile` | `{id, name, paper, ink, settings}` | not typed | `{printer_make_model, paper_type, ink_type, icc_profile, print_settings, driver_name, driver_version, calibration_date, calibration_version, notes}` | prose fields `id`/`name` do not exist; vendored types the 3 required |
| Recent sheets | `sheets[]`, `title` nullable | same | always emits `title: null` today | no change |
| Capture creation | nested `metadata`+`quality` only | flat **or** nested (`anyOf`); flat uses `exposure_duration` and `rejection_reasons` (different key names) | accepts both | app keeps nested form |
| Measurement upload: stats | `stats` block documented | **omitted from schema** | accepted (nested or flat) and stored | endpoint gap: spec drift; vendored keeps `stats` |
| Measurement upload: top-level `scoring_algorithm_version` | documented | **omitted** | silently ignored | dropped from client (per-pair `algorithm_version` only) |
| Measurement upload: `normalized_linear_rgb_median` | example shows it | **required** | accepted when absent | vendored keeps optional |
| Measurement upload: rgb shape | `{r,g,b}` object | `anyOf` array / object / string | accepts all three | vendored uses object form only |
| Measurement upload: response | no body documented | **200 with `{capture_id, measurement_count, pair_score_count}`** | 200 JSON body | client previously tolerated 204; generated client expects 200 |
| Judgment values | `match`, `near_match`, `no_match` | plain string, unvalidated | same | unchanged |
| Judgment upload: response | no body documented | **200 with `{capture_id, judgment_count}`** | 200 JSON body | same as above |
| Ranked results | prose only ("source colors, scores, labels, capture provenance…") | only `schema_version`, `sheet_id` typed | full payload with per-pair `score` aggregates, `current_judgment`, capture provenance | endpoint gap: spec under-documents; vendored types the payload |
| Auth | bearer shared token, optional in dev | `bearerAuth` on every operation | `ApiAuth` plug (dev may allow unauthenticated) | client sends bearer when token set |

## Endpoint gaps discovered (PR-description checklist)

1. `MeasurementUploadRequest` in the published spec omits the `stats` block
   the server actually accepts and stores (sample_count, clipping_fraction,
   mean, standard_deviation). Regenerating from the published doc alone would
   drop robustness data the app uploads today.
2. The published spec drops the prose contract's top-level
   `scoring_algorithm_version` on measurement upload; only per-pair-score
   `algorithm_version` survives.
3. Measurement and judgment uploads return `200` JSON bodies that the prose
   contract never documented; the hand-written client treated them as
   fire-and-forget 2xx.
4. The published `TestSheetManifest` and `RankedResults` schemas type almost
   none of the payload the server renders — the generated client would see
   mostly untyped data if vendored as-is.
5. The published `CaptureRequest` accepts a flat alternative form with
   different key names (`exposure_duration`, `rejection_reasons`) that the
   prose contract never mentions.
6. `printer_profile` in the prose contract (`id`, `name`, `paper`, `ink`,
   `settings`) does not match the server (`printer_make_model`, `paper_type`,
   `ink_type`, …).

## Test suite (this phase)

Permanent tests, no live server:

- `iOS/Tests/ColorMatchingLPSAppTests/OpenAPIClientTestSupport.swift` —
  `StubTransport` (records `HTTPRequest`/body, returns queued
  `HTTPResponse`s) + server-faithful JSON fixtures.
- `iOS/Tests/ColorMatchingLPSAppTests/GeneratedClientContractTests.swift` —
  all six operations against stubbed responses: request path/method/body and
  typed response decoding, including 404 handling and tolerance of
  undocumented response properties.
- `iOS/Tests/ColorMatchingLPSAppTests/ColorMatchingAPIClientTests.swift` —
  wrapper: bearer auth header, manifest→domain mapping, measurement/judgment
  upload JSON shape, ranked-results decode, non-2xx error mapping.
- `iOS/Tests/ColorMatchingLPSAppTests/VendoredOpenAPIDocumentTests.swift` —
  vendored document exists and covers the required operations.

Red-phase status: the first three files reference the not-yet-generated
`ColorMatchingAPI` module, so `swift test` fails at build until the
implementation run lands; `VendoredOpenAPIDocumentTests` compiles today and
fails at runtime because the vendored document does not exist yet. The Linux
container has no Swift toolchain, so no tests were executed locally in this
phase; verification is deferred to CI (macOS) at the PR head.
