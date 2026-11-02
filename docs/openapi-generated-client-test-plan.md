---
module: iOS
tags: [openapi, api-client, code-generation, testing]
problem_type: feature_plan
---

# Generated OpenAPI Swift client: test plan and implementation contract

Status: **tests-only (red) phase** for issue #5. This document is the normative
reference for the implementation run that wires the generated client into the
package. The tests under `iOS/Tests/ColorMatchingLPSAPITests/` are the
acceptance harness; they compile and run once the implementation run performs
the wiring described below.

## Phase scope

This run (test-writing) may only commit test paths and docs. Therefore:

- The new test target directory `iOS/Tests/ColorMatchingLPSAPITests/` is
  committed but **not registered in `iOS/Package.swift`** (implementation
  file). SwiftPM ignores unregistered directories under `Tests/`, so the
  existing `swift test` suite is unaffected by this commit.
- The OpenAPI document and generator config below must be vendored verbatim by
  the implementation run. Property order inside schemas is normative: the tests
  construct generated payloads with labeled, declaration-ordered arguments
  (`Components.Schemas.CaptureMetadata(...)`), which requires the property
  order below.

## Acceptance criteria mapping

| # | Issue deliverable | Verification | Where |
|---|---|---|---|
| AC-1 | `swift-openapi-generator` + `swift-openapi-runtime` added; OpenAPI document vendored | Wiring diff + vendor doc (implementation phase); normative document provided below | `docs/openapi-generated-client-test-plan.md` |
| AC-2 | Client generated for all 6 surfaces (manifest, recent sheets, create capture, measurements, judgments, ranked results) | Focused unit tests per operation against stubbed transports | `iOS/Tests/ColorMatchingLPSAPITests/SheetSurfaceTests.swift`, `CaptureFlowTests.swift`, `RankedResultsTests.swift` |
| AC-3 | Hand-written API models replaced by generated types; client-side models kept | Existing `APIClientTests`/`MeasurementCoreTests` stay green after swap (implementation phase) | `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift` |
| AC-4 | Swift tests exercising the generated client against local stubbed responses, no live server | `StubTransport` conforms to `ClientTransport`; every response is a canned `HTTPResponse` + `HTTPBody`; no network | `iOS/Tests/ColorMatchingLPSAPITests/TestSupport.swift` |
| AC-5 | PR description records contract deltas and endpoint gaps | Delta analysis below, to be copied into the PR description | section "Contract deltas" |

Recurring-rule choices (per testing style guide): drift visibility (unknown
enum value, undocumented status) is a permanent unit test because it is the
core regression the issue exists to prevent; each API surface gets a focused
unit test suite because the flows are library calls, not UI journeys.

## Package wiring (implementation run)

Add to `iOS/Package.swift` dependencies:

```swift
.package(url: "https://github.com/apple/swift-openapi-generator", from: "1.6.0"),
.package(url: "https://github.com/apple/swift-openapi-runtime", from: "1.7.0"),
```

Add targets:

```swift
.target(
    name: "ColorMatchingLPSAPI",
    dependencies: [
        .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime")
    ],
    plugins: [
        .plugin(name: "OpenAPIGenerator", package: "swift-openapi-generator")
    ]
),
```

and register the already-committed test target:

```swift
.testTarget(
    name: "ColorMatchingLPSAPITests",
    dependencies: [
        "ColorMatchingLPSAPI",
        .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
    ]
),
```

`HTTPTypes` is imported by `TestSupport.swift` and resolves transitively via
`OpenAPIRuntime`.

## Generator config

`iOS/Sources/ColorMatchingLPSAPI/openapi-generator-config.yaml`:

```yaml
generate:
  - clients
accessModifier: public
```

`accessModifier: public` is required so the test target (a separate module) can
see `Client` and `Components.Schemas.*`. The naming strategy must remain the
default (`defensive`): the tests rely on snake_case OpenAPI identifiers passing
through verbatim (`sheet_id`, `near_match`), which is the documented default
behavior of every released 1.x generator.

## OpenAPI document

`iOS/Sources/ColorMatchingLPSAPI/openapi.yaml` — vendor verbatim:

```yaml
openapi: "3.1.0"
info:
  title: Color Matching API
  version: "1.0.0"
security:
  - bearerAuth: []
paths:
  /api/v1/test_sheets/recent:
    get:
      operationId: listRecentTestSheets
      responses:
        "200":
          description: A list of recently created test sheets.
          content:
            application/json:
              schema:
                $ref: "#/components/schemas/RecentSheetsResponse"
  /api/v1/test_sheets/{sheet_id}/manifest:
    get:
      operationId: getTestSheetManifest
      parameters:
        - $ref: "#/components/parameters/SheetID"
      responses:
        "200":
          description: The test sheet manifest.
          content:
            application/json:
              schema:
                $ref: "#/components/schemas/TestSheetManifest"
  /api/v1/test_sheets/{sheet_id}/captures:
    post:
      operationId: createCaptureSession
      parameters:
        - $ref: "#/components/parameters/SheetID"
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: "#/components/schemas/CreateCaptureSessionRequest"
      responses:
        "201":
          description: The capture session was created.
          content:
            application/json:
              schema:
                $ref: "#/components/schemas/CaptureSessionResponse"
  /api/v1/test_sheets/{sheet_id}/ranked_results:
    get:
      operationId: getRankedResults
      parameters:
        - $ref: "#/components/parameters/SheetID"
      responses:
        "200":
          description: The latest ranked results for the sheet.
          content:
            application/json:
              schema:
                $ref: "#/components/schemas/RankedResultsResponse"
  /api/v1/captures/{capture_id}/measurements:
    post:
      operationId: uploadMeasurements
      parameters:
        - $ref: "#/components/parameters/CaptureID"
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: "#/components/schemas/MeasurementUploadRequest"
      responses:
        "204":
          description: The measurements and scores were stored.
  /api/v1/captures/{capture_id}/judgments:
    post:
      operationId: uploadJudgments
      parameters:
        - $ref: "#/components/parameters/CaptureID"
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: "#/components/schemas/JudgmentUploadRequest"
      responses:
        "204":
          description: The judgments were stored.
components:
  securitySchemes:
    bearerAuth:
      type: http
      scheme: bearer
  parameters:
    SheetID:
      name: sheet_id
      in: path
      required: true
      schema:
        type: string
    CaptureID:
      name: capture_id
      in: path
      required: true
      schema:
        type: string
  schemas:
    TestSheetManifest:
      type: object
      required: [schema_version, sheet_version, sheet_id, manifest_url, created_at, page, registration_markers, patches, pairs]
      properties:
        schema_version:
          type: string
        sheet_version:
          type: string
        sheet_id:
          type: string
        manifest_url:
          type: string
        created_at:
          type: string
          format: date-time
        page:
          $ref: "#/components/schemas/PageGeometry"
        registration_markers:
          type: array
          items:
            $ref: "#/components/schemas/RegistrationMarker"
        printer_profile:
          $ref: "#/components/schemas/PrinterProfile"
        capture_profile:
          $ref: "#/components/schemas/CaptureProfile"
        patches:
          type: array
          items:
            $ref: "#/components/schemas/Patch"
        pairs:
          type: array
          items:
            $ref: "#/components/schemas/SheetPair"
    PageGeometry:
      type: object
      required: [units, width, height]
      properties:
        units:
          type: string
        width:
          type: number
        height:
          type: number
    RegistrationMarker:
      type: object
      required: [role, shape, rect]
      properties:
        role:
          type: string
        shape:
          type: string
        rect:
          $ref: "#/components/schemas/Rect"
    Rect:
      type: object
      required: [x, y, width, height]
      properties:
        x:
          type: number
        y:
          type: number
        width:
          type: number
        height:
          type: number
    PrinterProfile:
      type: object
      required: [id, name]
      properties:
        id:
          type: string
        name:
          type: string
        paper:
          type: string
        ink:
          type: string
        settings:
          type: object
          additionalProperties: true
    CaptureProfile:
      type: object
      required: [expected_illuminant, preferred_camera, scoring_algorithm_version]
      properties:
        expected_illuminant:
          type: string
        preferred_camera:
          type: string
        scoring_algorithm_version:
          type: string
    PatchRole:
      type: string
      enum: [pair_color, reference]
    ReferenceRole:
      type: string
      enum: [white, gray, black, blank_paper]
    Patch:
      type: object
      required: [id, role, safe_inset_mm, rect]
      properties:
        id:
          type: string
        role:
          $ref: "#/components/schemas/PatchRole"
        pair_id:
          type: ["string", "null"]
        pair_side:
          type: ["string", "null"]
        reference_role:
          oneOf:
            - $ref: "#/components/schemas/ReferenceRole"
            - type: "null"
        source_color:
          type: ["string", "null"]
        safe_inset_mm:
          type: number
        rect:
          $ref: "#/components/schemas/Rect"
    SheetPair:
      type: object
      required: [id, first_patch_id, second_patch_id, source_colors, grid_row, grid_col]
      properties:
        id:
          type: string
        first_patch_id:
          type: string
        second_patch_id:
          type: string
        source_colors:
          type: array
          items:
            type: string
        grid_row:
          type: integer
        grid_col:
          type: integer
    RecentSheetsResponse:
      type: object
      required: [sheets]
      properties:
        sheets:
          type: array
          items:
            $ref: "#/components/schemas/RecentSheet"
    RecentSheet:
      type: object
      required: [sheet_id, manifest_url]
      properties:
        sheet_id:
          type: string
        manifest_url:
          type: string
        title:
          type: ["string", "null"]
    CreateCaptureSessionRequest:
      type: object
      required: [metadata, quality]
      properties:
        metadata:
          $ref: "#/components/schemas/CaptureMetadata"
        quality:
          $ref: "#/components/schemas/CaptureQuality"
    CaptureMetadata:
      type: object
      required: [device_model, lens, app_version, timestamp]
      properties:
        device_model:
          type: string
        lens:
          type: string
        exposure_duration_seconds:
          type: number
        iso:
          type: number
        focus_lens_position:
          type: number
        white_balance_gains:
          $ref: "#/components/schemas/WhiteBalanceGains"
        image_width:
          type: integer
        image_height:
          type: integer
        app_version:
          type: string
        timestamp:
          type: string
          format: date-time
    WhiteBalanceGains:
      type: object
      required: [red, green, blue]
      properties:
        red:
          type: number
        green:
          type: number
        blue:
          type: number
    CaptureRejection:
      type: string
      enum: [missingRegistrationMarks, incompleteSheetCoverage, clipping, excessiveBlur, glare, poorReferencePatch]
    CaptureQuality:
      type: object
      required: [detected_marker_count, blur_score, rejections]
      properties:
        detected_marker_count:
          type: integer
        blur_score:
          type: number
        rejections:
          type: array
          items:
            $ref: "#/components/schemas/CaptureRejection"
    CaptureSessionResponse:
      type: object
      required: [capture_id]
      properties:
        capture_id:
          type: string
    MeasurementUploadRequest:
      type: object
      required: [scoring_algorithm_version, measurements, pair_scores]
      properties:
        scoring_algorithm_version:
          type: string
        measurements:
          type: array
          items:
            $ref: "#/components/schemas/PatchMeasurementUpload"
        pair_scores:
          type: array
          items:
            $ref: "#/components/schemas/PairScoreUpload"
    PatchMeasurementUpload:
      type: object
      required: [patch_id, linear_rgb_median, stats]
      properties:
        patch_id:
          type: string
        linear_rgb_median:
          $ref: "#/components/schemas/RGBValue"
        normalized_linear_rgb_median:
          $ref: "#/components/schemas/RGBValue"
        stats:
          $ref: "#/components/schemas/MeasurementStats"
    RGBValue:
      type: object
      required: [r, g, b]
      properties:
        r:
          type: number
        g:
          type: number
        b:
          type: number
    MeasurementStats:
      type: object
      required: [sample_count, clipping_fraction, mean, standard_deviation]
      properties:
        sample_count:
          type: integer
        clipping_fraction:
          type: number
        mean:
          $ref: "#/components/schemas/RGBValue"
        standard_deviation:
          $ref: "#/components/schemas/RGBValue"
    PairScoreUpload:
      type: object
      required: [pair_id, distance, similarity, algorithm_version]
      properties:
        pair_id:
          type: string
        distance:
          type: number
        similarity:
          type: number
        algorithm_version:
          type: string
    Judgment:
      type: string
      enum: [match, near_match, no_match]
    PairJudgment:
      type: object
      required: [pair_id, judgment]
      properties:
        pair_id:
          type: string
        judgment:
          $ref: "#/components/schemas/Judgment"
    JudgmentUploadRequest:
      type: object
      required: [judgments]
      properties:
        judgments:
          type: array
          items:
            $ref: "#/components/schemas/PairJudgment"
    RankedResultsResponse:
      type: object
      required: [sheet_id, scoring_algorithm_version, results]
      properties:
        sheet_id:
          type: string
        scoring_algorithm_version:
          type: string
        printer_profile:
          $ref: "#/components/schemas/PrinterProfile"
        results:
          type: array
          items:
            $ref: "#/components/schemas/RankedPairResult"
    RankedPairResult:
      type: object
      required: [pair_id, source_colors, distance, similarity, algorithm_version, capture_id]
      properties:
        pair_id:
          type: string
        source_colors:
          type: array
          items:
            type: string
        distance:
          type: number
        similarity:
          type: number
        algorithm_version:
          type: string
        capture_id:
          type: string
        judgment:
          $ref: "#/components/schemas/Judgment"
```

### Expected generated surface

| OpenAPI | Generated Swift |
|---|---|
| operationId `getTestSheetManifest` | `client.getTestSheetManifest(.init(path: .init(sheet_id:)))` |
| operationId `listRecentTestSheets` | `client.listRecentTestSheets(.init())` |
| operationId `createCaptureSession` | `client.createCaptureSession(.init(path:body: .json(...)))` → `.created` |
| operationId `uploadMeasurements` | `client.uploadMeasurements(...)` → `.noContent` |
| operationId `uploadJudgments` | `client.uploadJudgments(...)` → `.noContent` |
| operationId `getRankedResults` | `client.getRankedResults(...)` → `.ok` |
| schema `Judgment` enum | `Components.Schemas.Judgment` cases `.match`, `.near_match`, `.no_match` |
| any undocumented status | `.undocumented(statusCode:_:)` on the output enum |

## Contract deltas: prose contract vs. published spec

The upstream dependency is **not yet published**: `viamin/color_matching#110`
returns 404 as of this writing, so the vendored document above is derived from
`docs/color-matching-api-contract.md`. When the real spec lands, re-vendor it
and record the diff here. Deltas introduced while deriving the document:

1. **Ranked results response shape is absent from the prose contract.** The
   prose describes intent ("source colors, scores, labels, capture provenance,
   printer profile, and scoring algorithm version") but no schema. The spec
   proposes `RankedResultsResponse` (`sheet_id`, `scoring_algorithm_version`,
   optional `printer_profile`, `results[]` of `RankedPairResult` with
   `pair_id`, `source_colors`, `distance`, `similarity`, `algorithm_version`,
   `capture_id`, optional `judgment`). This is the largest open item to
   reconcile against the real spec.
2. **Status codes were unspecified in prose.** Pinned: 200 for manifests,
   recent sheets, and ranked results; 201 for capture creation (matches the
   hand-written client's accepted 201); 204 for the two uploads.
3. **Prose string vocabularies became closed enums** (patch roles, reference
   roles, capture rejections, judgments). Server-side additions now surface as
   Swift decoding errors (visible drift) instead of silently passed-through
   strings — covered by `testUnknownPatchRoleSurfacesAsDecodingError`.
4. **`manifest_url` is `type: string`, not a URL type.** swift-openapi-
   generator maps uri-format strings to `String`; the app layer must convert
   to `URL` where needed (the hand-written model decoded straight to `URL`).
5. **Nullable-by-omission fields.** The prose sends explicit `null`s for
   `pair_id`/`pair_side`/`reference_role`/`source_color` on reference patches.
   The spec marks them optional; generated decoding treats `null` and absence
   identically. On upload, Swift `nil` omits the key rather than sending
   explicit `null`.
6. **`created_at`/`timestamp` are RFC 3339 `date-time`** and decode to Swift
   `Date` (runtime `ISO8601DateTranscoder`, no fractional seconds) — same wire
   format the hand-written ISO8601 Codable client used.
7. **Auth is declared but not generated.** `securitySchemes` (HTTP bearer) is
   documented in the spec; swift-openapi-generator 1.x does not emit auth
   plumbing, so the bearer token is injected app-side via a `ClientMiddleware`
   that sets the `Authorization` header before the transport.
8. **Endpoint gaps found:** `ranked_results` had no client implementation at
   all in the hand-written `APIClient` (the surface existed only in the prose
   contract); the generated client adds it. `recent` is a literal path segment
   that must not be captured by `{sheet_id}` routing.

## Running the tests

```bash
cd iOS && swift test --disable-sandbox
```

`--disable-sandbox` lets the build-time generator plugin invoke the generator
binary. The tests never touch the network: every response comes from
`StubTransport` in `TestSupport.swift`.
