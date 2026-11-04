---
title: "OpenAPI Swift client adoption evidence for #5"
date: "2026-11-04"
module: "iOS"
problem_type: "contract_migration"
tags:
  - "openapi"
  - "swift"
  - "color-matching"
  - "api-client"
---

# OpenAPI Swift Client Adoption Evidence

This document is the proposed PR description and criterion-level test plan for #5. It is deliberately retained with the tests so the implementation PR can update its results from one reviewable place.

## Acceptance-criterion verification plan

| Criterion | Smallest credible verification | Evidence location | Current phase |
| --- | --- | --- | --- |
| `swift-openapi-generator` and `swift-openapi-runtime` are package dependencies | Focused build-contract test reads the Swift package manifest | `iOS/Tests/ColorMatchingLPSAppTests/OpenAPIClientBuildContractTests.swift` | Red: implementation required |
| Vendored or fetched document covers the six app surfaces | Focused build-contract test verifies the vendored OpenAPI paths | `iOS/Tests/ColorMatchingLPSAppTests/OpenAPIClientBuildContractTests.swift` | Red: document required |
| Generated client is exercised without a live server | Permanent local-`URLProtocol` tests send published manifest and recent-sheet stubs through the app boundary; implementation must route existing capture/measurement/judgment tests through generated operations | `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift` | Partial: manifest/recent pass today; generated wiring remains red |
| Hand-written wire types are replaced while client-only measurement types remain | Compile the app after generated types replace API request/response types; review the generated diff and the removal of wire models | implementation PR diff plus `swift test --disable-sandbox` | Not run in tests-only phase |
| Contract deltas and endpoint gaps are recorded | Human review of this section against the provider's published spec | this document | Recorded below |

The local-stub tests are permanent regression coverage: manifest selection and recent-sheet loading are recurring app flows. Capture creation, measurements, and judgments already have local-stub coverage in `APIClientTests`; the implementation must preserve those tests while changing their transport to generated operations. Ranked-results has no app call site today, so its typed operation is verified by the vendored-document coverage until product wiring is introduced.

## Provider evidence consulted

- `viamin/color_matching#110`, closed 2026-10-30, publishes the document at `GET /api/v1/openapi.json`.
- Provider `main` routes declare all six companion paths, including `GET /api/v1/test_sheets/:sheet_id/ranked_results`.
- Provider schema modules were inspected from `main` on 2026-11-04. The implementation must vendor the rendered document, not reconstruct it from these Elixir modules.

## Contract deltas and endpoint gaps

| Surface | Prose contract | Published provider contract | Migration consequence |
| --- | --- | --- | --- |
| Manifest | Full example includes page, markers, patches, pairs, printer profile, and capture profile | Declared schema guarantees only `schema_version`, `sheet_id`, and `capture_profile.scoring_algorithm_version` | The generated model may expose fewer fields than the app requires; this is a provider-spec gap that must be resolved before replacing `SheetManifest`. |
| Capture create | Nested `metadata` and `quality` request; response `{ "capture_id": ... }` | Supports nested request for compatibility, but also accepts a legacy flattened request | Generate the nested request operation used by iOS; do not migrate to the legacy shape. |
| Measurement upload | Includes top-level `scoring_algorithm_version`, stats, and returns `204` | No top-level scoring version or stats are declared; normalized RGB is required; pair score accepts `score`, `similarity`, or `distance`; response is JSON with counts | Current request has undocumented fields and assumes no response body. This is the principal wire-format delta. |
| Judgment upload | Assumes `204` | Returns JSON containing `capture_id` and `judgment_count` | Generated operation must decode and intentionally ignore the acknowledgement if app behavior remains unchanged. |
| Ranked results | Narrative-only response description | Schema declares only `schema_version` (`lps-ranked-results/v1`) and `sheet_id` | Endpoint exists, but the typed result payload is not sufficient for a useful app result view; retain no new product behavior and flag the schema gap. |
| Recent sheets | `title` may be null | `title` is required and nullable | Generated model must preserve nullable title; covered by local stub. |

## Implementation handoff

1. Fetch the rendered provider document from the deployed `/api/v1/openapi.json` endpoint, pin its source revision/checksum, and vendor it at `iOS/Sources/OpenAPIClient/openapi.json`.
2. Add generator and runtime package products; configure code generation only for the six named paths.
3. Adapt generated operations at the app boundary. Preserve `MeasurementCore` types (`RGB`, `PatchMeasurement`, `PairScore`, and capture analysis) as client-side domain models.
4. Resolve the manifest and ranked-results schema gaps with the provider before deleting the hand-written models that the app needs.
5. Make the two build-contract tests green, run `swift test --disable-sandbox`, and replace this phase status with actual command output in the implementation PR.
