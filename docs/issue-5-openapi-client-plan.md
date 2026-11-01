# Issue #5: Generated OpenAPI client plan

## Acceptance criteria and verification

| Criterion | Smallest credible verification | Status in this test-writing PR |
| --- | --- | --- |
| Add the generator/runtime and vendor the OpenAPI document | Focused package/spec contract test checks the declared dependencies, generator plugin configuration, and vendored document. | Red test: `OpenAPIClientAdoptionTests.testPackageDeclaresGeneratedClientDependenciesAndVendoredSpec` |
| Generate the client for manifest, recent sheets, capture creation, measurement upload, judgment upload, and ranked results | Stubbed transport tests invoke the generated operations for each surface and assert request/response decoding. No live server is used. | Red test contract: `OpenAPIClientAdoptionTests.testGeneratedClientStubCoverageIncludesEveryConsumedSurface` |
| Replace hand-written API models without replacing client-only models | Focused source-boundary test verifies generated API types are used at the API boundary while `MeasurementCore` types remain client-side. | Red test: `OpenAPIClientAdoptionTests.testAPIBoundaryUsesGeneratedTypesAndPreservesClientOnlyModels` |
| Swift tests use local stubbed responses | The permanent `ColorMatchingLPSAppTests` target will use `MockURLProtocol`; the generated-client test asserts all six endpoint fixtures are registered there. | Red test: `OpenAPIClientAdoptionTests.testGeneratedClientStubCoverageIncludesEveryConsumedSurface` |
| PR records prose-contract/spec deltas and endpoint gaps | This document is the inspectable PR-head evidence; a reviewer must still validate it against the published `/api/v1/openapi.json`. | Human/external evidence below |

The generated-client transport tests are permanent focused integration tests: they exercise the recurring app-to-API boundary entirely in-process, with `URLProtocol` stubs. They are not ephemeral because contract drift is the reason for this work.

## Contract deltas found

Comparison source: this repository's [prose contract](color-matching-api-contract.md), plus the upstream #110 route/spec modules at `viamin/color_matching` main, inspected 2026-11-01. The published document is served dynamically at `GET /api/v1/openapi.json`; it was not reachable from this isolated environment because no deployed Phoenix base URL was supplied.

* The upstream OpenAPI schema for `TestSheetManifest` only requires `schema_version`, `sheet_id`, and `capture_profile.scoring_algorithm_version`. The prose contract and the current app consume the geometry, patch, pair, printer-profile, and capture-profile fields as well. Generating from the published document would make these fields optional/unknown, so this is an upstream schema-completeness gap that must be resolved before replacing `SheetManifest`.
* The real API includes ranked results (`lps-ranked-results/v1`), while the prose contract describes the endpoint but intentionally leaves its response shape unspecified. The current iOS API client also has no ranked-results call. This is an app integration gap, not a reason to change capture/scoring behavior in this issue.
* Capture creation accepts both the prose contract's nested `metadata`/`quality` body and a legacy flat body. In the published schema, the nested metadata form requires device model, lens, image dimensions, app version, and timestamp; quality is optional. The prose contract presents quality as required.
* Measurement upload differs materially: the real schema does not declare the prose contract's root `scoring_algorithm_version` or measurement `stats`; it requires `normalized_linear_rgb_median`; RGB accepts arrays, `{r,g,b}` objects, or JSON strings; and a pair score needs `pair_id`, `algorithm_version`, and exactly one of `score`, `similarity`, or `distance`. The prose contract sends object RGB, optional normalized RGB, stats, and both distance and similarity.
* Measurement and judgment uploads return documented `200` count responses upstream. The prose contract/current client expect `204` with no body.
* `recent` preserves the prose response shape, but `title` is explicitly required-and-nullable upstream rather than only described narratively as nullable.

## Endpoint coverage decision

The six requested endpoints are present upstream: manifest, recent sheets, capture creation, measurement upload, judgment upload, and ranked results. The generated client must include all six; the app should only call ranked results where the existing UI already needs it, preserving the issue's non-goal of behavior changes.

## Implementation handoff

Vendor a pinned response from the upstream `GET /api/v1/openapi.json` endpoint and record its source commit/checksum. Configure `swift-openapi-generator` and `swift-openapi-runtime` in `iOS/Package.swift`; give generated code its own target. Then update the API adapter and the conditional test branch in `OpenAPIClientAdoptionTests` to invoke the generated operations through `MockURLProtocol` for all six fixtures.
