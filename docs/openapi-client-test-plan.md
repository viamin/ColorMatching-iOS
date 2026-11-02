# OpenAPI Generated Client — Test Plan & Contract Deltas (issue #5)

Red-phase test plan for replacing the hand-written API layer
(`iOS/Sources/ColorMatchingLPSAppCore/APIClient.swift`) with a generated
OpenAPI Swift client (`swift-openapi-generator` + `swift-openapi-runtime`).
This document is the source material for the implementation PR description:
it records what the tests pin, the deltas between
`docs/color-matching-api-contract.md` (prose) and any machine-readable spec,
and the endpoint gaps found.

## Phase note

This changeset is **tests + documentation only** (TDD red phase). The tests
below compile against the current package and fail until the implementation
run lands the generated client. Expected red suite:

- `OpenAPIClientGenerationContractTests` (15 tests) — fail because
  `iOS/Sources/ColorMatchingOpenAPI/openapi.json`,
  `openapi-generator.yml`, and the package wiring do not exist yet.
- `GeneratedClientNotYetWiredTests` (7 tests) — the `#else` branch of
  `#if canImport(ColorMatchingOpenAPI)`; fail with an explicit message until
  the generated module is importable from the test target.

## What the tests pin (the artifact contract)

These are deliberate decisions the implementation must follow (tests enforce
them; adjust the tests only together with the spec):

1. **Vendored spec location/format**: `iOS/Sources/ColorMatchingOpenAPI/openapi.json`
   — JSON (not YAML) so tests can parse it with `JSONSerialization` and diffs
   stay deterministic. OpenAPI 3.x, non-empty `info.title`, ≥1 `servers` entry.
2. **Generated module name**: `ColorMatchingOpenAPI`, its own SwiftPM target
   with `OpenAPIGeneratorPlugin` applied, generated `types` + `client`, wired
   into `ColorMatchingLPSAppCore` and importable from tests.
3. **Surfaces + operationIds + status codes** (status codes match what the
   app's existing `MockURLProtocol` tests assume):

   | Surface | Path | Method | operationId | Success |
   |---|---|---|---|---|
   | Sheet manifest | `/api/v1/test_sheets/{sheet_id}/manifest` | GET | `getSheetManifest` | 200 |
   | Recent sheets | `/api/v1/test_sheets/recent` | GET | `listRecentSheets` | 200 |
   | Create capture | `/api/v1/test_sheets/{sheet_id}/captures` | POST | `createCaptureSession` | 201 |
   | Upload measurements | `/api/v1/captures/{capture_id}/measurements` | POST | `uploadMeasurements` | 204 |
   | Upload judgments | `/api/v1/captures/{capture_id}/judgments` | POST | `uploadJudgments` | 204 |
   | Ranked results | `/api/v1/test_sheets/{sheet_id}/ranked_results` | GET | `getRankedResults` | 200 |

4. **Schemas**: required properties per prose contract (manifest fields the
   app consumes, capture metadata incl. `timestamp` as `format: date-time`,
   measurement/pair-score payloads, judgment enum
   `match|near_match|no_match`, nullable recent-sheet `title`), and an
   `http bearer` security scheme.

## Runtime stub tests design

`GeneratedClientStubbedTransportTests` exercises the generated `Client`
against an in-memory `ClientTransport` (no live server, no URLProtocol):
each test returns canned JSON taken verbatim from the prose contract,
asserts decoded generated types, and asserts the request the generated
client produced (method, templated path, operationID, snake_case JSON body).

Assumptions about `swift-openapi-runtime` API (implementation run may adjust
these call sites minimally if the pinned version differs — assertions must
survive): `Client(serverURL:transport:)`, `ClientTransport.send(_:body:baseURL:operationID:)`,
`HTTPResponse(statusCode:headerFields:)`, `HeaderField(name:value:)`,
`HTTPBody(Data)`, `HTTPBody.collected()`.

## Criterion → verification map

| Criterion (issue #5) | Verification (smallest credible) |
|---|---|
| Generator + runtime in package; OpenAPI doc vendored | Unit tests: `testVendoredOpenAPIDocumentExistsAndParses`, `testPackageManifestDeclaresOpenAPIGeneratorToolchain`, `testGeneratorConfigGeneratesTypesAndClient` |
| Client generated for the 6 surfaces | Unit tests: the six `testSpecDeclares…Surface` tests (spec-side) + stubbed-transport tests (runtime-side) |
| Hand-written API models replaced; client-side models kept | Unit tests: `GeneratedClientStubbedTransportTests` prove generated types decode/encode; model-disposition table below is `human_or_external_evidence` at implementation review |
| Swift tests vs stubbed responses, no live server | `GeneratedClientStubbedTransportTests` (in-memory transport; CI has no color_matching server) |
| PR description records contract deltas + gaps | This document, "Contract deltas" + "Endpoint gaps" below — PR body should quote them |
| Exit: `swift test --disable-sandbox` green with generated types | CI (`macos-latest`, `.github/workflows/ci.yml`) after implementation; locally blocked in this container (no Swift toolchain) |

Model disposition (implementation guidance): API-facing hand-written types to
be replaced by generated types — `CaptureMetadata`, `WhiteBalanceGains`,
`CaptureSessionResponse`, `RecentSheet`, `PairJudgment`, upload payload
structs in `APIClient.swift`. Purely client-side types stay — `RGB`, `Point`,
`Rect`, `Page`, `RegistrationMarker`, `Patch`, `PairManifest`, `SheetManifest`
(domain value types; map from generated manifest types),
`ChannelStats.median/min/max` (never uploaded), `SheetAnalysis`,
`DetectedMarker`, `SampleOverlayRegion`.

## Contract deltas: prose vs machine-readable spec

Things a published spec must decide that the prose contract leaves open
(each is now pinned by a test where the app has a stake):

1. **Path templating**: prose writes `:sheet_id`; OpenAPI requires `{sheet_id}`.
2. **Status codes are unspecified in prose** for every endpoint. The
   hand-written client accepts any 2xx (`200..<300`); the tests pin 200/201/204
   because the generated client only models *declared* codes and returns
   `.undocumented` otherwise — a real behavior change for the app.
3. **Auth optionality**: prose says bearer "can be" used and dev may allow
   unauthenticated. The spec must declare the bearer scheme (test-pinned) and
   decide whether it is optional per-operation; if required, the generated
   client exposes a typed Authorization header parameter the app must set.
4. **`ranked_results` has no response schema in prose** — see endpoint gaps.
5. **`timestamp` encoding**: prose examples use ISO-8601 without fractional
   seconds (`2026-07-25T12:00:00Z`); spec pins `format: date-time` (RFC 3339,
   which permits fractional seconds). Swift's `.iso8601` strategy rejects
   fractional seconds — the generated runtime's date transcoding must be
   verified against the server's actual encoding (stub tests avoid asserting
   timestamp wire format for this reason).
6. **Nullability**: prose marks `title`, `pair_id`, `pair_side`,
   `reference_role`, `source_color` nullable in examples only; the spec must
   declare them (OpenAPI 3.0 `nullable: true` vs 3.1 `type: [string, "null"]`)
   or generated types will make them non-optional.
7. **`manifest_url`**: URL-shaped string; tests accept any string, recommend
   `format: uri`.
8. **Enum casing inconsistency**: capture rejection strings are camelCase
   (`missingRegistrationMarks`) while every other field is snake_case — the
   spec must carry them verbatim; generated Swift cases will be lower-camel.
9. **Free-form objects**: `printer_profile.settings: {}` needs
   `additionalProperties: true` (or a schema); the app ignores it today.
10. **Upload request/response schemas for measurements/judgments** are
    request-only in prose; the spec must also declare the 204 (no body).

## Endpoint gaps found

1. **`GET /api/v1/test_sheets/{sheet_id}/ranked_results` response schema is
   undefined in the prose contract** ("latest or aggregate ranked results
   with source colors, scores, labels, capture provenance, printer profile,
   and scoring algorithm version" — no JSON shape). The spec author must
   define it; the stub test intentionally only asserts transport-level
   behavior (path/operationID/`.ok` mapping), not payload fields.
2. **`GET /api/v1/test_sheets/recent` vs `/api/v1/test_sheets/{sheet_id}/…`
   routing collision**: a Phoenix route like `get "/:sheet_id/manifest"` does
   not collide with `/recent` (different suffix), but any future
   `GET /api/v1/test_sheets/:sheet_id` would; worth flagging upstream.
3. **Upstream dependency unmet**: viamin/color_matching#110 is not merged and
   the repo's `main` tree (207 entries, checked 2026-11-02) contains **no
   OpenAPI/Swagger artifacts**. Until it publishes a spec, this repo must
   vendor one authored from the prose contract (the tests define its required
   shape) and re-sync when #110 lands — that re-sync is exactly the
   "regeneration diff" drift detection this issue wants.
4. **`iso` numeric type**: prose example is integer `100`; the app sends
   `Float`. Spec should use `number` (not `integer`) or generated types will
   reject fractional ISO values.

## Local verification limits

- No Swift toolchain exists in this container (`swift`/`xcrun` absent), so
  `swift test --disable-sandbox` cannot run here; no lint command is
  configured. CI (macos-latest) is the executor of record.
- The red suite is by design (see "Phase note"); previously-passing tests
  (`APIClientTests`, `MeasurementCoreTests`) are untouched and must stay
  green — if the implementation deletes `APIClient.swift`, those tests move
  to the generated client in the same change.
