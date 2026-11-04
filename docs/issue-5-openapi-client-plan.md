# Issue #5: generated OpenAPI client verification plan

This is the tests-first plan for replacing the companion app's hand-written
`/api/v1` Codable boundary with a client generated from the OpenAPI 3 document
published by `viamin/color_matching#110`. The upstream issue is closed and
serves its document at `GET /api/v1/openapi.json`.

## Acceptance criteria and verification

| Criterion | Smallest credible verification | Evidence at this PR head |
| --- | --- | --- |
| Vendor the published document and generate only the six app surfaces | Focused permanent contract test checks the vendored document contains all required operations. It intentionally fails until the document is vendored at the named location. | `iOS/Tests/ColorMatchingLPSAppTests/OpenAPIContractTests.swift:5` (red) |
| Wire manifest and recent-sheets reads through the generated boundary | Permanent local-stub tests verify request paths, bearer auth, and decoded app-facing values without a live server. | `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift:82`, `:103` (green) |
| Wire capture creation, measurement upload, and judgment upload through the generated boundary | Existing permanent local-stub tests verify the three write requests and payload mappings. The implementation run must preserve them while replacing the transport/models. | `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift:13`, `:47`, `:74` (green) |
| Wire ranked results through the generated boundary | The vendored-document test requires the ranked-results operation. Add a local-stub facade test when the generated operation is introduced. | `iOS/Tests/ColorMatchingLPSAppTests/OpenAPIContractTests.swift:17` (red) |
| Remove server-owned hand-written API models, retaining client-only measurement models | Source inspection in implementation review; this is a code-structure criterion and cannot be established by a broad test suite. | Human review of `iOS/Sources/ColorMatchingLPSAppCore/APIClient.swift` at the implementation PR head |
| `swift test --disable-sandbox` is green | Run the command after the generator, runtime, spec, and adapter are present. This red-phase PR deliberately leaves the contract test failing to expose the missing dependency. | Not run as a passing criterion in this tests-only phase |
| Record prose-contract deltas and endpoint gaps in the PR | Inspect the upstream OpenAPI implementation at `viamin/color_matching` main and compare it with the prose contract. | This document, “Published-spec deltas” below |

The local-stub tests are permanent regression coverage: the manifest-to-capture
flow is recurring companion-app behavior, while the request mappings prevent
future generated-client upgrades from silently changing the adapter's wire
contract. No live server is involved.

## Published-spec deltas

Comparison source: `viamin/color_matching` main at the revision available on
2026-11-04, specifically `ColorMatchingWeb.ApiSchemas`,
`TestSheetController`, `CaptureController`, and `TestSheetJSON`.

- The prose document specifies a detailed manifest shape. The published
  `TestSheetManifest` schema only requires `schema_version`, `sheet_id`, and
  `capture_profile.scoring_algorithm_version`; its remaining rendered fields
  are not machine-described. A generated type therefore cannot safely replace
  the current detailed `SheetManifest` model without upstream schema expansion
  or a deliberately retained client-side decoding adapter.
- The prose contract describes capture input solely as nested `metadata` plus
  `quality`. The published spec accepts that form *or* a legacy flattened form;
  the nested `quality` properties are not required. The current app's nested
  request is compatible.
- The prose measurement request includes `scoring_algorithm_version` and
  nested `stats`. The published `MeasurementUploadRequest` documents neither,
  and requires both median RGB fields while the prose treats normalized RGB as
  part of the payload but does not state requiredness. The adapter needs an
  upstream spec correction before those generated request types can express
  the app's full payload without extensions.
- The prose says measurement and judgment uploads return `204`; the published
  spec and controller return `200` JSON acknowledgement bodies containing
  capture and count fields.
- The prose only sketches ranked results. The published endpoint and renderer
  provide `lps-ranked-results/v1`, aggregate capture timestamps/counts,
  printer-profile details, source colors, score summaries, and judgment
  provenance. Its published OpenAPI schema currently requires only
  `schema_version` and `sheet_id`, so it is likewise too sparse for a useful
  fully generated response model.
- The real server uses numeric database capture IDs encoded as strings. The
  prose uses opaque `capture_123` identifiers, so test fixtures and any
  validation assumptions must use a numeric-string-compatible value.

## Endpoint gaps that block a full generated replacement

The six endpoint paths requested by the issue are present in the published
spec. The gaps are schema fidelity, not missing routes: manifest and ranked
results omit their rendered response fields, and measurement upload omits
fields emitted by the iOS client. The implementation PR should vendor the
exact upstream JSON, pin its source revision, generate the available typed
operations, and retain only narrow app-side adapters for the under-described
shapes until the provider spec is corrected.
