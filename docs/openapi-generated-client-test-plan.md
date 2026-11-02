# Generated OpenAPI Swift Client — Test Plan & Contract Deltas (#5)

Status: **red phase (tests-only PR)**. This document maps every acceptance
criterion of issue #5 to its verification, records the contract deltas found
between `docs/color-matching-api-contract.md` (the prose contract) and the
published OpenAPI spec of viamin/color_matching (`GET /api/v1/openapi.json`,
issue #110), and captures the generator integration decisions the tests pin.

## Acceptance criteria → verification map

| AC | Verification (permanent tests) | Status at this PR head |
|----|--------------------------------|------------------------|
| `swift-openapi-generator` + `swift-openapi-runtime` (+ URLSession transport) in the iOS package; OpenAPI document vendored from viamin/color_matching#110 | `OpenAPIGeneratedClientPackageTests` (Package.swift deps, plugin, generated target, `accessModifier: public`, vendored doc + config) and `OpenAPISpecContractTests.testVendoredSpecExistsAndParsesAsOpenAPI3` | **failed (expected red)** — deliverables not yet implemented |
| Client generated for all six surfaces (manifest, recent sheets, capture creation, measurement upload, judgment upload, ranked results) | `OpenAPISpecContractTests` operation tests (paths, methods, operationIds, request/response schema names) + `GeneratedClientStubbedResponseTests` (one test per surface) | spec tests: **failed (expected red)**; stubbed tests: **skipped** until the `ColorMatchingOpenAPI` target exists (`#if canImport` gate) |
| Hand-written API models replaced by generated types; client-side models kept | `OpenAPIGeneratedClientPackageTests.testGeneratedClientTargetIsWiredIntoAppCore` (AppCore depends on the generated module); existing `APIClientTests` keep pinning the wire behavior through the migration | **failed (expected red)** |
| Swift tests exercising the generated client against local stubbed responses (no live server) | `GeneratedClientStubbedResponseTests` — stubbed via `URLProtocol` + `URLSessionTransport`, including a `.undocumented(statusCode:)` drift case | **skipped** (module missing); verified green in a reference harness during this run (below) |
| PR description records prose-vs-published deltas and endpoint gaps | This document (below) feeds the PR description | **passed** (evidence below) |

Exit criterion "`swift test --disable-sandbox` green with generated types wired
in" is demonstrated green in the reference harness during this run and must hold
on macOS CI after the implementation PR.

## Contract deltas: prose contract vs published spec

The published spec was reconstructed from viamin/color_matching `main`
(`lib/color_matching_web/api_spec.ex`, `api_schemas.ex`, and the
`TestSheetController`/`CaptureController` operation declarations, inspected
2026-10-31):

1. **Manifest schema is far thinner than the prose contract.** The published
   `TestSheetManifest` only types `schema_version`, `sheet_id`, and
   `capture_profile.scoring_algorithm_version`. The prose fields the app decodes
   (`sheet_version`, `manifest_url`, `created_at`, `page`,
   `registration_markers`, `printer_profile`, `patches`, `pairs`) are absent —
   generated types would drop them. The vendored copy must re-expand the
   manifest to the prose shape.
2. **`CaptureRequest` anyOf is field-hostile.** Upstream combines sibling
   `properties` with `anyOf(required-only branches)`; OpenAPIKit (and therefore
   swift-openapi-generator) drops sibling properties of `anyOf`, so generated
   Swift types would silently serialize `{}`. The vendored copy must keep the
   nested `{metadata: CaptureMetadata, quality: {...}}` object the app sends.
   Note the upstream *flat* branch also uses `exposure_duration` (not
   `exposure_duration_seconds`) and `rejection_reasons` (not `quality.rejections`).
3. **`PairScoreRequest` has the same anyOf problem** (`score`/`similarity`/
   `distance` variants). The app sends `pair_id`, `distance`, `similarity`,
   `algorithm_version` — the vendored copy keeps those as plain properties.
4. **Measurement upload deltas.** Upstream omits the top-level
   `scoring_algorithm_version` the app sends today, omits `stats`
   (`sample_count`, `clipping_fraction`, `mean`, `standard_deviation`), requires
   `normalized_linear_rgb_median`, and types `linear_rgb_median` as
   `RgbPayload` (anyOf array | {r,g,b} | string) while the prose contract only
   documents the `{r,g,b}` object. The vendored copy keeps
   `scoring_algorithm_version` (optional) and `stats`, and types RGB as a plain
   `{r, g, b}` number object.
5. **Upload responses now have bodies.** The prose contract documents no
   response payloads; the published spec returns
   `{"capture_id","measurement_count","pair_score_count"}` (HTTP 200) for
   measurements and `{"capture_id","judgment_count"}` (HTTP 200) for judgments;
   capture creation returns HTTP 201 with `{"capture_id"}`. The tests pin these
   typed responses.
6. **Ranked results gap.** The prose contract promises a rich payload (source
   colors, scores, labels, capture provenance, printer profile, scoring
   algorithm version) but defines no schema; the published spec declares only a
   `{"schema_version": "lps-ranked-results/v1", "sheet_id"}` envelope. The app
   does not consume this surface yet, so the tests pin the versioned envelope
   only — the richer payload is an endpoint gap for the Phoenix app to fill.
7. **`iso` is typed `integer` upstream** while the app captures a Float; the
   vendored copy types it as `number`.
8. **Endpoints in the published spec but not in the prose contract** (out of
   scope for the app's generated client): `GET /api/v1/openapi.json`,
   `printer_profiles`/`palettes`/`colors`/`metamer_pairs` surfaces,
   `POST /api/illuminant_measurements` (+ `/bulk`), `POST /api/multi_image_mapping`.
9. **Security matches** (`bearerAuth`, http/bearer) and `title` on recent sheets
   is required-but-nullable, consistent with the prose "title may be null".

## Vendoring & normalization decisions (what the tests enforce)

The vendored document lives at `Sources/ColorMatchingOpenAPI/openapi.json` —
the file name and location the `OpenAPIGenerator` build plugin discovers — and
must carry, relative to the served spec:

- friendly `operationId`s: `fetchManifest`, `fetchRecentSheets`,
  `createCapture`, `uploadMeasurements`, `uploadJudgments`, `fetchRankedResults`
  (upstream ids are `ColorMatchingWeb.TestSheetController.manifest`-style,
  which generate as unwieldy Swift method names);
- JSON format (Foundation-parseable, so the contract tests can read it without
  a YAML dependency);
- the manifest/`CaptureRequest`/`PairScoreRequest`/measurement normalizations
  from the delta list above;
- `schema_version` and `scoring_algorithm_version` kept as plain strings
  (not enums) so the generated surface stays `String`-typed;
- `reference_role` (manifest patches) and `title` (recent sheets) nullable.

## Generator integration notes (verified during this run)

- The generated target needs a placeholder `.swift` file or SwiftPM rejects it
  as empty.
- `openapi-generator-config.yaml` must set `accessModifier: public` — the
  generator's default is `internal`, which hides the client from app/test
  targets (asserted by the package tests).
- The generator maps `format: date-time` strings to Foundation `Date`.
- Resolved toolchain during verification: swift-openapi-generator 1.13.1,
  swift-openapi-runtime 1.12.2, swift-openapi-urlsession 1.4.0 (Swift 6.1.2).

## How these tests were verified (red and green)

The repo's CI (macOS) is authoritative for `swift test`; this run used a local
Linux Swift 6.1.2 toolchain with a scratch harness under `/tmp` (not committed)
that compiles the same three test files:

- **Red** (package without the generated target — mirrors the repo today):
  all `OpenAPIGeneratedClientPackageTests` + `OpenAPISpecContractTests` fail on
  the missing deliverables; `GeneratedClientStubbedResponseTests` records an
  `XCTSkip`.
- **Green** (scratch package with a `ColorMatchingOpenAPI` target generated
  from the normalized reference spec): 19/19 spec-contract tests and 7/7
  stubbed-response tests pass, proving the `canImport`-gated suite compiles
  against real generated code and is satisfied by a faithful vendored spec.

Linux cannot build the full repo package (`ColorMatchingLPSApp` uses
SwiftUI/UIKit; `ColorMatchingLPSAppCore` lacks `FoundationNetworking` imports —
pre-existing, macOS-first). `MeasurementCoreTests` builds green on Linux with
this PR's changes.
