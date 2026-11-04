# Issue #5: Generated OpenAPI Swift Client

## Criterion verification plan

| Criterion | Smallest credible verification | Status in this tests-only change |
| --- | --- | --- |
| Add `swift-openapi-generator` and `swift-openapi-runtime`, and vendor the published document | `GeneratedOpenAPIContractTests.testPackageDeclaresGeneratorAndRuntimeDependencies` and `testVendoredSpecificationDeclaresEveryAppAPIPath` | Red: the dependency has not yet published a specification into this repository. |
| Generate the six app surfaces | The vendored-document test asserts exactly the manifest, recent sheets, capture creation, measurement upload, judgment upload, and ranked-results paths. The implementation change must replace this contract guard with local-stub tests calling the generated operations. | Red. |
| Replace server API models with generated types | Compile the app target after migrating `APIClient`; retain only measurement-analysis models in `MeasurementCore`. | Not run in tests-only phase. |
| Exercise generated client with local stubs | `APIClientTests` uses `MockURLProtocol` and now covers manifest and recent-sheet reads in addition to the existing capture, measurement, and judgment writes. Add a ranked-results generated-operation stub test during implementation. | Partial: existing client tests pass; generated operation tests are blocked by the missing specification. |
| Describe contract deltas and endpoint gaps in the PR | Human review of the published `viamin/color_matching#110` document against `docs/color-matching-api-contract.md`, with the results copied into the PR body. | Blocked until the external specification is available. |

## Proposed PR description

### What changed

Replace the hand-written `/api/v1` Codable transport layer with an OpenAPI-generated Swift client. The package will vendor the published `viamin/color_matching#110` document and use `swift-openapi-generator` plus `swift-openapi-runtime`. Local `URLProtocol` stubs cover each generated operation; no test contacts a live Phoenix server.

### Contract deltas and endpoint gaps

The external OpenAPI document was not available in this checkout at test-authoring time, so no delta can be claimed yet. Before implementation is approved, compare the actual document to `docs/color-matching-api-contract.md` and record:

- schema/property/nullability changes for manifest, recent-sheet, capture, measurement, judgment, and ranked-result payloads;
- enum values and response status-code differences;
- auth/security-scheme differences; and
- whether every one of the six required paths is present. Missing paths are endpoint gaps and block generated-client adoption for that surface.

## Dependencies

Blocked by `viamin/color_matching#110` publishing an OpenAPI document that covers the sheet and capture endpoints.
