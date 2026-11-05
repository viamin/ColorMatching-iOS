---
module: ios-api-client
tags: [openapi, swift, generated-client, issue-5]
problem_type: implementation-plan
---

# Issue #5: OpenAPI Client Acceptance Plan

## Verification map

| Criterion | Smallest credible verification | Status in this tests-only change |
| --- | --- | --- |
| Add `swift-openapi-generator` and `swift-openapi-runtime`; vendor or fetch the provider spec | Inspect `iOS/Package.swift`, the checked-in spec source, and a successful generated-client build. | Not run — implementation work. |
| Generate the manifest, recent sheets, capture, measurement, judgment, and ranked-results surfaces | Permanent local-stub tests for each generated operation. Existing tests cover create/upload operations; `APIClientTests.testFetchManifestDecodesPublishedManifestStub` and `APIClientTests.testFetchRecentSheetsDecodesPublishedResponseStub` cover reads. `APIClientTests.testGeneratedClientIncludesRankedResultsOperation` is deliberately red until the missing generated ranked-results operation exists. | Failed (expected red phase). |
| Replace hand-written API models while retaining client-only models | Inspect generated target imports and ensure app-only measurement/domain types remain in `MeasurementCore`; compile the app. | Not run — implementation work. |
| Swift tests use local stubs rather than a live server | `MockURLProtocol` stubs requests and responses in `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift`; execute `swift test --disable-sandbox`. | Pending full implementation; red phase has one intentional assertion failure. |
| PR description includes contract deltas and endpoint gaps | Copy the "Provider contract delta" section below into the implementation PR description and link provider PR #113. | Human/inspectable PR evidence required. |

## Provider contract delta

Evidence was inspected in `viamin/color_matching` PR [#113](https://github.com/viamin/color_matching/pull/113), which closed issue #110. The provider serves the spec dynamically at `GET /api/v1/openapi.json`; it does not commit a static JSON document. The implementation should fetch that endpoint during generation and commit the fetched document plus generated Swift so CI does not require a running Phoenix server.

Compared with `docs/color-matching-api-contract.md`:

- The spec permits both a nested `metadata`/`quality` capture payload and a legacy flattened capture payload. The prose contract documents only nested payloads.
- `CaptureMetadata` requires `image_width` and `image_height`; its optional camera fields retain validation constraints. The prose implies the complete metadata shape without machine-readable requiredness.
- Measurement uploads do not require `scoring_algorithm_version` in the provider schema. Each pair score requires `pair_id` and `algorithm_version`, plus exactly one compatible score representation (`score`, `similarity`, or `distance`). The prose requires the top-level scoring version and sends both `distance` and `similarity`.
- Provider write endpoints document response bodies: capture creation is `201`, and measurement/judgment uploads return `200` result bodies. The prose says measurement and judgment uploads are `204`.
- The ranked-results schema currently guarantees only `schema_version` (`lps-ranked-results/v1`) and `sheet_id`. The provenance, printer profile, source-color, label, and score detail promised by the prose are not typed in the published schema.

## Endpoint gap discovered

The app currently has no ranked-results request in `APIClient`, although the prose contract and provider spec both expose `GET /api/v1/test_sheets/{sheet_id}/ranked_results`. The red test makes that missing integration explicit. The implementation must wire this generated operation without changing capture or scoring behavior.
