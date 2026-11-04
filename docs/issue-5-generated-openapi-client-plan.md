# Issue #5: generated OpenAPI client verification plan

## Criterion map

| Criterion | Smallest credible verification | Phase |
| --- | --- | --- |
| The package uses `swift-openapi-generator` and `swift-openapi-runtime`, and carries the upstream document | `GeneratedClientAdoptionTests.testPackageAndVendoredSpecEnableGeneratedClient` verifies package declarations and a vendored `iOS/OpenAPI/color-matching.json` snapshot. | Red: currently absent. |
| The OpenAPI document covers every app surface | `GeneratedClientAdoptionTests.testVendoredSpecDescribesEverySurfaceUsedByTheApp` checks the six required paths in the snapshot. | Red: snapshot currently absent. |
| Manifest, recent sheets, capture creation, measurement upload, and judgment upload remain wire-compatible | `APIClientTests` uses `MockURLProtocol`, with no live service, to exercise the five existing flows. | Passing baseline; implementation must route these calls through generated operations. |
| Ranked results are generated and exposed | Add a local-stub response test when the generated operation and the app-facing adapter exist. The current app has no ranked-results client method, so a compile-safe red test cannot invoke it yet. | Not yet runnable. |
| Prose-contract deltas and endpoint gaps are recorded | Human review of this document and the implementation PR description against the fetched upstream `/api/v1/openapi.json` response. | External evidence required. |

## Upstream evidence and deltas found before implementation

`viamin/color_matching#110` is closed. Its controller serves the OpenAPI document dynamically from `GET /api/v1/openapi.json`; no static OpenAPI JSON/YAML file is tracked in that repository. This app should fetch that endpoint and vendor a pinned snapshot, recording its source revision and retrieval date.

The prose contract names the six app surfaces above. The upstream issue additionally says the actual API has two undocumented non-versioned POST endpoints (`/api/illuminant_measurements` and `/api/multi_image_mapping`). They are outside this app's stated scope and must not be generated as app-facing behavior in this issue. The prose document also leaves the ranked-results response shape unspecified; the vendored document is the authority and its schema must determine the generated model and adapter.

## PR description checklist for the implementation run

- State the exact upstream commit/SHA and retrieval date of the vendored OpenAPI snapshot.
- List every schema or wire-shape delta found by comparing the snapshot with `docs/color-matching-api-contract.md`, including nullability, enums, timestamps, and ranked-results fields.
- Record whether all six paths above are present. If any is missing, identify it as an endpoint gap and do not silently retain a hand-written contract for it.
- Run `swift test --disable-sandbox` after generation and report the exact result.
