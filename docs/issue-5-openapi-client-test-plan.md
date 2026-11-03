# Issue #5 OpenAPI client verification plan

This red-phase change records the smallest credible verification for each
acceptance criterion before the generated-client implementation begins.

| Criterion | Verification | Initial state |
| --- | --- | --- |
| Add generator/runtime and vendor or fetch the published document | Build the iOS package after generation; inspect `Package.swift`, the pinned OpenAPI document, and generated target. | Not run: implementation phase. |
| Generate all app-used surfaces | Permanent stub-transport tests cover manifest, recent sheets, create capture, measurements, judgments, and ranked results. Each test asserts the generated operation's path, request body, and typed response. | Red: ranked-results operation and generated target do not exist. |
| Replace handwritten API models | Compile the app and tests against the generated module; inspect that API wire models no longer live in `APIClient.swift`, while `MeasurementCore` remains client-side. | Not run: implementation phase. |
| Generated client against local stubs | `APIClientTests` uses `MockURLProtocol`, never a live server. The tests are permanent because these six API calls are the recurring capture flow. | Red: measurement payload shape is still handwritten and differs from the published schema. |
| PR contract-delta record | Human inspection of this document and the PR description against upstream `viamin/color_matching#110` and its served `/api/v1/openapi.json`. | Recorded below; final confirmation waits for vendoring the served document. |
| `swift test --disable-sandbox` | Run from `iOS/` after the generated client is wired in. | Not run: `swift` is unavailable in this container. |

## Published-spec deltas discovered

Evidence was taken from `viamin/color_matching` main at the closed dependency
issue [#110](https://github.com/viamin/color_matching/issues/110), specifically
`ColorMatchingWeb.Router`, `CaptureController`, and `ApiSchemas`.

- The prose contract says capture metadata and quality are nested. The published
  `CaptureRequest` accepts that compatibility shape but also supports a flattened
  payload; a generated client must select one explicitly.
- The prose contract requires a top-level `scoring_algorithm_version` and sends
  measurement `stats`. Published `MeasurementUploadRequest` defines neither;
  it requires measurement RGB payloads and defines per-pair
  `algorithm_version` plus a `score`, `similarity`, or `distance`. The
  red-phase test locks the generated request to those documented fields.
- The prose contract documents upload responses as empty. Published endpoints
  return typed acknowledgement bodies with `capture_id` and counts.
- The prose contract leaves ranked-results response contents informal. The
  published `RankedResults` schema currently guarantees only `schema_version`
  (`lps-ranked-results/v1`) and `sheet_id`; it does not yet model the claimed
  ranked entries, provenance, printer profile, or scoring fields.
- The published manifest schema currently guarantees only `schema_version`,
  `sheet_id`, and `capture_profile.scoring_algorithm_version`, while the prose
  contract describes a fuller manifest. The implementation must preserve the
  local analysis fields as client-side models or request an upstream schema
  expansion before replacing that model wholesale.

## Endpoint gaps requiring resolution in implementation

The router exposes all requested paths, so there is no missing route. The two
schema gaps above are material: generated manifest and ranked-results types do
not contain enough fields for the current capture analysis and ranked UI. The
implementation PR must either retain explicit client-side projection models at
that boundary or coordinate an upstream schema expansion; it must not invent
generated fields absent from the document.
