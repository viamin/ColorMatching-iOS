# OpenAPI Client Migration Verification

This is the criterion-level test plan for #5. It is deliberately kept with
the code so the implementation PR has an inspectable audit trail.

| Criterion | Smallest credible verification | Current evidence |
| --- | --- | --- |
| Generated dependencies and a checked-in OpenAPI input | `OpenAPIClientMigrationTests.testPackageConfiguresGeneratedClientDependencies` and `testVendoredSpecDefinesEveryAppOperation` | Red: the package has no OpenAPI dependencies or spec input. |
| All app-used surfaces are generated | `testVendoredSpecDefinesEveryAppOperation` verifies manifest, recent sheets, create capture, measurement upload, judgment upload, and ranked results paths. | Red: no vendored spec exists. |
| Server-owned Codable models are replaced | `testTransportDoesNotDeclareServerOwnedModels` | Red: `APIClient.swift` declares the server request/response models. |
| Generated client behavior against local stubs | `APIClientTests` uses `MockURLProtocol`, never a live service. New manifest and recent-sheet cases cover stubbed response decoding; existing cases cover create capture, uploads, authorization, and payloads. The implementation must convert these to use the generated client's types/transport and add ranked-results coverage. | Characterization tests are green; generated-client wiring is red. |
| Contract deltas and endpoint gaps | Human inspection of the fetched OpenAPI document against `docs/color-matching-api-contract.md`, recorded in the implementation PR description. | Not yet possible: viamin/color_matching#110 is closed, but its default-branch tree did not contain an OpenAPI document on 2026-11-03. |

## Initial delta/gap audit

The prose contract describes six app surfaces, including ranked results. The
current hand-written `APIClient` implements only five: it has no ranked-results
operation. It also decodes a reduced sheet manifest, ignoring the prose
contract's `created_at`, `printer_profile`, and `capture_profile` fields.

The upstream issue says the runtime spec is served at `/api/v1/openapi.json`.
Before implementation, fetch that published document, vendor it at
`iOS/Sources/ColorMatchingAPI/openapi.json`, and replace this preliminary audit
with a field-by-field comparison in the PR description. The checked-in input
makes regeneration and CI deterministic without a live server.
