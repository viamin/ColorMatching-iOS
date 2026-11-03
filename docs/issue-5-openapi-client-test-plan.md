# Issue #5: generated OpenAPI client test plan

This is the red-phase test plan for replacing the iOS hand-written API layer. The
permanent tests are deliberately written before the implementation so a generated
client cannot be claimed merely by adding a dependency.

## Acceptance criteria and verification

| Criterion | Smallest credible verification | Current status |
| --- | --- | --- |
| Add `swift-openapi-generator` and `swift-openapi-runtime`; vendor the published document | `GeneratedOpenAPIClientRequirementsTests.testPackageDeclaresGeneratedOpenAPIClientAndVendoredSpecification` asserts both package dependencies and the versioned vendored document. | Failing until implemented. |
| Generate and wire the manifest, recent sheets, capture, measurement, judgment, and ranked-results surfaces | Permanent URL-protocol tests in `APIClientTests` exercise local stub responses for the existing five surfaces. `GeneratedOpenAPIClientRequirementsTests.testAPILayerExposesRankedResultsOperation` is the red test for the absent sixth surface; the implementation phase must replace it with a typed ranked-results local-stub test once the generated operation name is known from the vendored document. | Partial: ranked results has no current API-layer call. |
| Remove hand-written server DTOs and transport | `GeneratedOpenAPIClientRequirementsTests.testAPILayerContainsNoHandWrittenServerDTOsOrTransport` rejects `URLSession` and the current server DTO declarations in the adapter. | Failing until implemented. |
| Record prose-contract deltas and endpoint gaps in the PR | Human/external evidence: compare the vendored response from `/api/v1/openapi.json` with `docs/color-matching-api-contract.md` and put the resulting delta list in the PR description. | Not runnable before the document is vendored. |

## Upstream-spec evidence and expected delta review

`viamin/color_matching#110` is closed. Its committed `ColorMatchingWeb.ApiSpec`
builds an OpenAPI 3 document from router routes and exposes the document at
`GET /api/v1/openapi.json`; it does not commit a static specification file.
Therefore the implementation must fetch that endpoint at a pinned revision (or
record its source revision/checksum) into `iOS/OpenAPI/color-matching-api-v1.json`
before generation.

The prose contract already describes these intended surfaces: manifest, recent
sheets, capture creation, measurements, judgments, and ranked results. Its
ranked-results response deliberately has no schema, so the PR must specifically
record the published response shape and any mismatch. No delta is asserted from
the prose alone: enum/nullable/date formats and response status codes must be
read from the vendored OpenAPI document.
