# Issue #5: OpenAPI client test plan and contract review

This is the tests-only (red) change for #5. It records the smallest credible
verification for each acceptance criterion before the generated-client
implementation is started.

| Criterion | Verification | Current result |
| --- | --- | --- |
| Package uses `swift-openapi-generator` and `swift-openapi-runtime` | Permanent unit test in `APIClientTests.testPackageConfiguresOpenAPIGeneratorAndRuntime` inspects the package declaration. | Red: neither dependency nor generator plugin is configured. |
| The published document covers all app surfaces | Permanent unit test in `APIClientTests.testVendoredOpenAPISpecDeclaresEveryCompanionSurface` validates the vendored document's six required paths. | Red: no vendored document is present. |
| Generated client serves manifest, recent sheets, capture creation, measurement upload, and judgment upload against local stubs | Permanent API boundary tests use `MockURLProtocol`; the implementation must route these calls through generated operations while preserving the current app boundary. | Existing behavior is covered; generated-client wiring remains red under the package-config test. |
| Generated client serves ranked results against a local stub | The vendored-spec path test is red now; implementation must add a local-stub request/response test for the generated ranked-results operation when its published response schema is available. | Blocked on access to the published response schema. |
| Prose-contract deltas and endpoint gaps are visible to reviewers | This document provides inspectable external evidence and is to be completed in the implementation PR description. | See below. |

## Published-spec evidence and gaps

`viamin/color_matching#110` is closed. Its issue body states that the OpenAPI
document is served dynamically at `GET /api/v1/openapi.json`; its default-branch
tree contains no committed OpenAPI/Swagger document to vendor. The iOS repository
has no configured deployment base URL from which that endpoint can be fetched in
CI or this isolated test environment.

Consequently, no field-level delta between
`docs/color-matching-api-contract.md` and the published schema can honestly be
recorded yet. The implementation PR must fetch the concrete document from the
Phoenix deployment (or receive a versioned exported artifact), vendor it, and
update this section with a field-by-field comparison.

Known endpoint gap: the prose contract describes ranked results only as a
sentence and supplies neither a response JSON example nor a response schema.
The generated client cannot safely expose a typed ranked-results result until the
published OpenAPI response is inspected. The path-level test deliberately makes
that endpoint a required part of the vendored schema.
