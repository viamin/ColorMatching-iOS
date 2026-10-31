# Issue #5: Generated OpenAPI client verification plan

This test-writing change establishes the verification boundary for replacing
the hand-written `/api/v1` client. It deliberately does not claim the client
has been generated: the current package has neither the OpenAPI generator nor
runtime dependency.

## Acceptance-criterion map

| Criterion | Smallest credible verification | Current evidence/status |
| --- | --- | --- |
| Generator/runtime and server document are added | `APIClientTests.testPackageDeclaresGeneratedOpenAPIClientDependencies` reads the package manifest and requires both dependencies plus the generator plugin. The implementation run must add a checked-in server OpenAPI document and configure code generation. | Red: dependencies/plugin are absent. |
| Generated client covers manifest, recent sheets, capture creation, measurement upload, judgment upload, and ranked results | Local URL-protocol stubs in `APIClientTests` verify the currently used manifest/recent/capture/measurement/judgment request-response boundary. The implementation run must move these fixtures to generated-operation calls and add ranked-results coverage once the published operation name/schema is available. | Partial: five current surfaces covered; ranked results has no app method or published schema available locally. |
| Hand-written API models are replaced, while client-only models remain | Compile the app after removal of API transport models; keep `MeasurementCore` analysis types compiling unchanged. | Not yet runnable in this tests-only phase. |
| Generated client is exercised with local stubs | Permanent `ColorMatchingLPSAppTests/APIClientTests.swift` uses `MockURLProtocol`, never a live server. | Existing hand-written client coverage passes; generated-client coverage awaits implementation. |
| PR describes prose-contract deltas and endpoint gaps | Human/external review of the published `viamin/color_matching#110` document against `docs/color-matching-api-contract.md`. | Blocked: this repository's GitHub API proxy rejected cross-repository issue access with `{"error":"Repository mismatch"}`. |

## Contract-delta record

No OpenAPI document from `viamin/color_matching#110` is available in this
checkout, and the allowed GitHub API proxy cannot retrieve that other
repository. Therefore no prose-vs-spec delta can be asserted honestly in this
run. The implementation PR must replace this section with an itemized diff
against the vendored/fetched spec, including whether ranked results is present
and the exact response schema.

The prose contract itself identifies one current app gap: it specifies
`GET /api/v1/test_sheets/:sheet_id/ranked_results`, but `APIClient` has no
corresponding method or test. That endpoint must either be generated and wired
in, or recorded as absent from the published specification in the PR.
