# OpenAPI Swift Client Migration — Test Plan and PR Notes

This is the implementation handoff for issue #5. It records the acceptance-criterion evidence plan before implementation and the externally observed contract deltas for the eventual PR description.

## Criterion-level verification plan

| Criterion | Smallest credible verification | Status in this tests-only PR |
| --- | --- | --- |
| Package contains `swift-openapi-generator` and `swift-openapi-runtime`; published specification is vendored | `APIClientTests.testOpenAPIClientGenerationPrerequisitesAreConfigured` reads `iOS/Package.swift` and requires `iOS/OpenAPI/openapi.json`. | Red: package dependencies, generator target, and vendored document do not yet exist. |
| Generated client covers manifest, recent sheets, capture creation, measurement upload, judgment upload, and ranked results | Permanent `APIClientTests` local-`URLProtocol` stubs will invoke each generated operation and assert decoded output/request shape. | Partial red: manifest/recent and three write operations have stubs; ranked-results operation has no app API yet. The implementation PR must replace the manual-client calls in these tests with generated operations and add the ranked-results stub. |
| App uses generated API types while client-only analysis types remain local | Compile the app and the focused test target after replacing server DTOs; inspect the generated target and the absence of duplicated transport DTOs. | Not run: requires generated source and app migration. |
| Contract deltas and endpoint gaps are recorded in the PR description | Human review of the checked-in source spec and this comparison. | Recorded below; validate once against the exact vendored spec revision. |

The HTTP tests are permanent unit/service tests: `URLProtocol` provides deterministic local stubs and exercises the consumer transport boundary without a live Phoenix server. No ephemeral test is needed.

## Published-spec source and deltas

On 2026-11-03, `viamin/color_matching#110` is closed and its `main` branch exposes the specification dynamically at `GET /api/v1/openapi.json`; there is no checked-in JSON/YAML document to pin directly. The implementation must download that endpoint from the selected server environment, validate it as OpenAPI 3, and vendor the exact bytes at `iOS/OpenAPI/openapi.json` with the source URL and revision/date recorded beside it.

The router and controller operation declarations show these differences from the prose contract:

- The published API describes success payloads for measurement and judgment uploads (`capture_id` plus accepted counts). The prose contract only specifies their request bodies and the current hand-written client discards those payloads.
- Error responses are typed and documented for 401, 404, and 422 on the capture routes; the prose contract only implies successful responses.
- `/api/v1/openapi.json` itself is public; all six companion endpoints require bearer authentication. The prose contract allows unauthenticated development requests, which is an environment policy rather than a published operation contract.
- The router exposes additional `/api/v1` palette/printer-profile routes and `/api` illuminant/multi-image routes. They are outside this app’s requested generated surface and are not endpoint gaps for this issue.
- `/api/v1/test_sheets/:sheet_id/ranked_results` is present in the published router/spec source but absent from the current `APIClient` and its tests. It is the known app-side endpoint gap that must be added.

Before merge, regenerate against the vendored document and update this section if the emitted schema differs from these source-level observations.
