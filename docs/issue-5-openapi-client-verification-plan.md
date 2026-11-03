# Issue #5 OpenAPI client verification plan

This is the tests-only (red) phase for #5. The published provider contract is
[`viamin/color_matching#110`](https://github.com/viamin/color_matching/issues/110),
which serves its OpenAPI document at `/api/v1/openapi.json`.

## Acceptance-criterion map

| Criterion | Smallest credible verification | Current red-phase state |
| --- | --- | --- |
| Generator/runtime dependency and vendored provider document | `GeneratedOpenAPIClientConfigurationTests.testPackageWiresTheGeneratorRuntimeAndVendoredPublishedSpec` verifies package wiring and the vendored document path. | Fails until the implementation phase wires Swift OpenAPI Generator and vendors the document. |
| Typed client for manifest, recent sheets, capture creation, measurements, judgments, and ranked results | The same configuration guard ensures generated sources are possible; implementation must add local-stub tests for all six generated operations, including ranked results. | Not implemented; ranked-results has no client operation today. |
| Replace hand-written transport models while retaining client-only models | Compilation of the generated client and `swift test --disable-sandbox`. | Not run; implementation work required. |
| Local-stub request/response behavior | `APIClientTests` uses `URLProtocol` stubs (no live provider) for manifest, recent sheets, capture creation, measurement upload, and judgment upload. The implementation phase must retarget these tests to generated operations and add ranked-results coverage. | Fixtures are in place; execution is blocked because this container has no Swift executable. |
| PR description records contract deltas and endpoint gaps | This document’s delta record plus upstream source/spec inspection. | Human review of the eventual PR description remains required. |

## Provider-contract deltas found

- `POST /captures/:capture_id/measurements` and `POST /captures/:capture_id/judgments`
  respond with `200` JSON acknowledgment bodies containing the capture ID and
  counts. The prose contract documented `204` with no body. The local stubs now
  use the provider response shape.
- Ranked results are not a vague future endpoint: the provider specifies
  `schema_version: "lps-ranked-results/v1"` and `sheet_id`, with ranked rows,
  score aggregates, judgment information, capture provenance, and printer
  profile in its rendered response. The app currently has no corresponding
  operation.
- The manifest’s provider schema formally requires only `schema_version`,
  `sheet_id`, and a `capture_profile.scoring_algorithm_version`; the app needs
  the richer geometry payload it actually consumes. This is an endpoint/schema
  precision gap to confirm while generating the client.
- The provider accepts both nested `metadata` capture payloads and a legacy
  flattened shape. The app uses the nested shape. Pair scores similarly accept
  `score`, `similarity`, or `distance`; the app currently emits the latter two.

## Implementation-phase evidence to add

- Record the vendored OpenAPI document URL and immutable revision in the PR
  description.
- Replace the red configuration failure with generated-operation tests using
  local `URLProtocol` stubs, including a ranked-results fixture.
- Run `swift test --disable-sandbox`; attach the exact result to the PR/run
  evidence. Do not use a live provider in CI.
