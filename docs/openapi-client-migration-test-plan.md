# OpenAPI Client Migration Verification Plan

This test-writing change records the criterion-level verification planned for
issue #5. The upstream issue, `viamin/color_matching#110`, is closed, but its
repository tree does not publish a checked-in OpenAPI file. The implementation
change must vendor the document served by `GET /api/v1/openapi.json`, record the
source revision, and update the delta section below from the actual document.

| Criterion | Smallest credible verification | Evidence location |
| --- | --- | --- |
| Generator/runtime and published spec are wired in | Focused configuration test reads `Package.swift` and the vendored OpenAPI document, then checks both Swift OpenAPI dependencies, build plugin, runtime, and all six consumed operation paths. | `iOS/Tests/ColorMatchingLPSAppTests/OpenAPIClientConfigurationTests.swift` |
| Manifest and recent-sheet reads use the generated client | Permanent local-stub tests decode representative provider responses without a live server. The implementation must route these calls through generated operations. | `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift` |
| Capture, measurement, and judgment writes use the generated client | Permanent local-stub tests assert request paths, authorization, and representative payloads. The implementation must preserve these assertions while replacing handwritten transport models. | `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift` |
| Ranked results are generated and usable | Add a local-stub test once the published response schema is vendored; no response shape is specified by the prose contract. | Published spec and a new test in `APIClientTests.swift` |
| Contract deltas and endpoint gaps are visible to reviewers | Human inspection of the vendored OpenAPI document against `docs/color-matching-api-contract.md`, summarized in the PR description. | PR description |

## Initial external evidence

On 2026-11-03, GitHub issue `viamin/color_matching#110` was closed. Its issue
body says the spec is served at `GET /api/v1/openapi.json`; its default-branch
tree contained no filename matching `openapi` or `swagger`. The actual served
document was not reachable from this isolated environment, so schema-level
deltas and the ranked-results response shape remain external evidence to obtain
in the implementation run.
