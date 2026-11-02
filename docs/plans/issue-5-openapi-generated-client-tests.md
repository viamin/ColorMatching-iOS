---
module: iOS
issue: 5
tags: [openapi, codegen, api-client, tests, red-phase]
problem_type: test_plan
---

# Issue #5 — Generated OpenAPI Swift client: test plan and contract deltas (tests-only phase)

## Status

- Phase: **test-writing (red)**. This changeset adds tests and this document only; the
  implementation run (after `paid-tests-approved`) wires the generator and makes the new
  suite compile and pass.
- Upstream dependency is satisfied: viamin/color_matching#110 was merged as
  viamin/color_matching#113. The machine-readable document is served at
  `GET /api/v1/openapi.json` with `servers: [{url: "/"}]`, `bearerAuth`
  (`type: http, scheme: bearer`) on every operation, and controller-derived
  operationIds such as `ColorMatchingWeb.TestSheetController.manifest`.

## What this changeset contains

| File | Role |
| ---- | ---- |
| `iOS/Tests/ColorMatchingAPITests/OpenAPISpecVendoringTests.swift` | Spec-vendoring invariants for `iOS/Sources/ColorMatchingAPI/openapi.json` (red until the document is vendored) |
| `iOS/Tests/ColorMatchingAPITests/GeneratedClientTests.swift` | Generated-client behavior against a stubbed in-memory `ClientTransport` (red until the target exists and generates) |
| `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift` | Three added permanent app-level behavior tests that pin the wire contract through the migration (green before and after the swap) |

The new `ColorMatchingAPITests` directory is intentionally **not** referenced by
`Package.swift` in this phase (implementation files are out of scope), so `swift test`
still compiles only the existing targets. The new tests become active — and red — the
moment the implementation run declares the target; that is the intended failure exposure
for the missing generator wiring.

## Acceptance criteria → verification map

| AC (issue) | Verification kind | Locator |
| ---------- | ----------------- | ------- |
| Add swift-openapi-generator/runtime; vendor the OpenAPI document | `unit_or_service_test` | `iOS/Tests/ColorMatchingAPITests/OpenAPISpecVendoringTests.swift` (existence, paths, operationIds, params, auth, servers, schemas, normalizations) |
| Generate the client for manifest + recent sheets, capture creation, measurement upload, judgment upload, ranked results | `unit_or_service_test` | `GeneratedClientTests.swift` — one test per surface plus a 404 mapping test |
| Replace hand-written API models with generated types; keep client-side models | `unit_or_service_test` (behavior pinning) | `APIClientTests.swift` — the full file must stay green through the swap; the added tests pin manifest decode, nullable titles, and 200-with-body upload acceptance |
| Swift tests against local stubbed responses, no live server in CI | `unit_or_service_test` | `GeneratedClientTests` uses `RecordingTransport` (an in-memory `ClientTransport`); `APIClientTests` uses `MockURLProtocol`; no network access anywhere |
| PR description records prose-vs-spec deltas and endpoint gaps | `human_or_external_evidence` | The "Contract deltas" and "Endpoint gaps" sections below are the canonical source the implementation PR body must reproduce |
| Exit criterion: `swift test --disable-sandbox` green | external (CI) | Not executable in this container — no Swift toolchain is installed. Deferred to the macOS CI job (`.github/workflows/ci.yml`) at the implementation PR head |

No `.ephemeral-tests/` entry is used: the flows under test are recurring (every app/API
interaction), so they get permanent suite coverage instead.

## Package wiring expected from the implementation run

`iOS/Package.swift` adds:

```swift
.package(url: "https://github.com/apple/swift-openapi-generator", from: "1.14.0"),
.package(url: "https://github.com/apple/swift-openapi-runtime", from: "1.13.0"),
```

```swift
.target(
    name: "ColorMatchingAPI",
    dependencies: [.product(name: "OpenAPIRuntime", package: "swift-openapi-runtime")],
    plugins: [.plugin(name: "OpenAPIGenerator", package: "swift-openapi-generator")]
),
.testTarget(
    name: "ColorMatchingAPITests",
    dependencies: [
        "ColorMatchingAPI",
        .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime")
    ]
),
```

The OpenAPI document lives at `iOS/Sources/ColorMatchingAPI/openapi.json`. The app target
then swaps `APIClient`'s internals to the generated `Client` (bearer token via a
`ClientMiddleware` or transport decorator, keeping the app-facing methods unchanged so the
behavior tests stay green).

## Vendored document normalization contract

Vendor the document served by `GET /api/v1/openapi.json` (color_matching `main`) and apply
exactly these normalizations, all of which `OpenAPISpecVendoringTests` asserts:

1. **OperationIds** renamed from controller-qualified to clean names:

   | Upstream operationId | Vendored operationId |
   | -------------------- | --------------------- |
   | `ColorMatchingWeb.TestSheetController.manifest` | `getTestSheetManifest` |
   | `ColorMatchingWeb.TestSheetController.recent` | `listRecentTestSheets` |
   | `ColorMatchingWeb.TestSheetController.ranked_results` | `getRankedResults` |
   | `ColorMatchingWeb.CaptureController.create` | `createCapture` |
   | `ColorMatchingWeb.CaptureController.upload_measurements` | `uploadMeasurements` |
   | `ColorMatchingWeb.CaptureController.upload_judgments` | `uploadJudgments` |

2. **`CaptureRequest`**: drop the top-level `anyOf`. `properties` + `anyOf` in one schema
   object is not consumable by swift-openapi-generator — OpenAPIKit keeps only the
   `anyOf` branch (whose children carry only `required` lists), which would erase every
   property and generate an unusable wrapper. Keep the nested
   `{metadata: CaptureMetadata, quality: {detected_marker_count, blur_score, rejections}}`
   shape from the prose contract (satisfies the server's `metadata` anyOf branch).
3. **`PairScoreRequest`**: drop `anyOf` for the same reason; keep `pair_id` and
   `algorithm_version` required, `score`/`similarity`/`distance` optional.
4. **`CaptureMetadata.white_balance_gains`**: replace the bare `type: object` with
   `{red, green, blue}` number properties (the prose contract's shape; a bare object
   generates an empty struct that would silently drop the gains from the wire payload).
5. Everything else stays as published: paths, response codes
   (200/201/401/404/422), schema titles, `bearerAuth`, `servers: [{url: "/"}]`.

## Contract deltas: `docs/color-matching-api-contract.md` vs the published spec

These must be carried into the implementation PR description (issue deliverable 5):

1. **Manifest response is drastically smaller in the spec.** The published
   `TestSheetManifest` types only `schema_version` (enum `lps-sheet-manifest/v1`),
   `sheet_id`, and `capture_profile.scoring_algorithm_version` (enum `lps-distance-v1`).
   The prose contract documents `sheet_version`, `manifest_url`, `created_at`, `page`,
   `registration_markers`, `printer_profile`, richer `capture_profile`, `patches`, and
   `pairs` — none are typed in the spec. The server does render the extra keys today, and
   the generated decoder tolerates them, but they are invisible to generated types.
2. **Ranked results is an envelope only.** `RankedResults` types `schema_version`
   (enum `lps-ranked-results/v1`) and `sheet_id`. The prose contract promises source
   colors, scores, labels, capture provenance, printer profile, and scoring algorithm
   version — none typed upstream.
3. **Capture creation returns 201** with `{"capture_id": ...}`; the prose contract does
   not state a status code. The request schema accepts either a flat capture payload or
   the nested `{metadata, quality}` form via `anyOf`; the app uses the nested form.
4. **Measurement upload returns 200 with a JSON body**
   `{"capture_id", "measurement_count", "pair_score_count"}` where the prose contract
   implies an empty 2xx (the hand-written client ignores bodies).
5. **Judgment upload returns 200 with a JSON body** `{"capture_id", "judgment_count"}` —
   same prose gap as (4).
6. **Measurement upload payload:** the published schema has no top-level
   `scoring_algorithm_version` (the prose contract has it; per-score
   `algorithm_version` covers it), no per-measurement `stats`
   (`sample_count`, `clipping_fraction`, `mean`, `standard_deviation` are untyped
   upstream), requires `normalized_linear_rgb_median` (optional in the prose contract),
   and types RGB values as `RgbPayload` = `anyOf` [array, `{r,g,b}`, string] where the
   prose contract uses only the `{r,g,b}` object.
7. **Capture metadata field shape:** `exposure_duration_seconds` (number) and `iso`
   (integer) in the published spec; `white_balance_gains` untyped upstream (see
   normalization 4). The flat compatibility variant of `CaptureRequest` uses
   `exposure_duration`, not `exposure_duration_seconds` — a naming inconsistency between
   the two anyOf branches upstream.
8. **OperationIds are controller-qualified upstream** (`ColorMatchingWeb.*`) and are
   normalized at vendor time (normalization 1).
9. **Recent sheets matches the prose contract** (`sheets[]` of
   `{sheet_id, manifest_url, title?}` with nullable `title`), and bearer auth matches the
   prose contract's shared-token model.

## Endpoint gaps discovered (follow-ups)

- Upstream issue needed: publish the full manifest schema (page, registration markers,
  patches, pairs, printer profile) — until then the iOS app cannot hold generated types
  for the fields its geometry pipeline consumes.
- Upstream issue needed: publish the ranked-results rows (scores, judgments, provenance).
- Per-measurement `stats` are spec-invisible while the app sends them; either type them
  upstream or stop sending them from iOS.
- `normalized_linear_rgb_median` is required upstream but optional in the app
  (`PatchMeasurement.normalizedLinearRGBMedian`); the app-side adapter must always
  provide it or request an upstream change, otherwise the server's
  `CastAndValidate` will 422.

## Generated-shape assumptions (verified against generator/runtime sources)

The generated-client tests were written against swift-openapi-generator `main`/1.14.x
behavior, verified in source:

- snake_case schema properties become lowerCamelCase Swift properties
  (`SafeNameGenerator` treats `_`, `-`, `/` as word separators): `sheetId`, `pairScores`,
  `deviceModel`, etc. Wire keys stay snake_case via generated `CodingKeys`.
- String enums become raw-value enums; `lps-sheet-manifest/v1` → case
  `lpsSheetManifestV1`, `lps-distance-v1` → `lpsDistanceV1`,
  `lps-ranked-results/v1` → `lpsRankedResultsV1`.
- A pure `anyOf` schema generates a struct with optional `case1`/`case2`/`case3`
  properties (`RgbPayload`; the `{r,g,b}` object is `case2`).
- `Client(serverURL:transport:)`; one method per operationId; path arguments
  `.init(sheetId:)`; request bodies `.json(...)`; responses `.ok`/`.created`/`.notFound`
  with throwing `.body.json` accessors (swift-openapi-runtime 1.5+ signature: optional
  request/response bodies in `ClientTransport.send`).
- Security schemes do not add method parameters; bearer injection belongs to a
  middleware/transport decorator, which the existing app-level
  `Authorization: Bearer` assertions cover.

If the resolved generator version produces different names (for example an older release
that preserves snake_case property names), adjust the generated-client tests in the same
implementation PR with justification — the wire-format assertions (JSON bodies, paths,
methods, statuses) must not change.

## Local verification status

- No Swift toolchain exists in this container (`swift`/`swiftc` unavailable), so
  `swift test --disable-sandbox` and even compile-checking could not be run here. All
  Swift test code was desk-checked against the generator/runtime sources cited above, and
  every embedded JSON fixture was machine-validated (`json.loads`).
- The three added app-level tests were designed against the current `APIClient`
  implementation and existing suite conventions; they must stay green after the model
  swap, and the exit criterion is CI `swift test` at the implementation PR head.
