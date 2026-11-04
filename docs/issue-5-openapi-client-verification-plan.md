# Issue #5 OpenAPI client verification plan

## Criterion map

| Criterion | Smallest credible verification | Current evidence |
| --- | --- | --- |
| Add `swift-openapi-generator` and `swift-openapi-runtime`; vendor the upstream document | `OpenAPIContractTests.testPackageDeclaresGeneratorRuntimeAndGeneratedClientTarget` and `testVendoredSpecCoversEveryAppEndpoint` inspect the Swift package and vendored JSON | Red until the implementation run adds the package dependencies, generator plugin, and `Sources/ColorMatchingAPI/openapi.json`. |
| Generate all six app surfaces | `testVendoredSpecCoversEveryAppEndpoint` requires the manifest, recent sheets, create capture, measurement upload, judgment upload, and ranked results paths | Red until the vendored upstream spec contains all six paths. |
| Replace server-owned hand-written models | Human code review of the implementation diff: server schema models must come from `ColorMatchingAPI`; only app-domain types stay in `MeasurementCore` | Not yet run; this cannot be proven solely by an XCTest. |
| Exercise the client with local responses | `APIClientTests` uses `MockURLProtocol`; existing tests cover the three writes and implementation should extend these stubs to the generated client read and ranked-results operations | Existing write stubs pass before migration; generated-client coverage is pending implementation. |
| Record prose-contract deltas and endpoint gaps | This document is the PR-head evidence; implementation PR description must copy the final observed deltas after decoding the vendored spec | Pending the vendored document. |

## Upstream source and present gap

`viamin/color_matching#110` is closed and its accepted interface serves the machine-readable contract at `GET /api/v1/openapi.json`. As of this test-writing commit, this repository has no checked-in OpenAPI document, no `swift-openapi-generator` or `swift-openapi-runtime` dependency, and no generated target. The implementation run must fetch that endpoint from a reachable provider environment and vendor the exact document used for generation so CI remains offline and reproducible.

## Contract delta checklist for the implementation PR

Compare the vendored document, rather than assumptions, with `docs/color-matching-api-contract.md` and record:

- request/response requiredness, nullability, and enum wire values;
- authentication requirements and error response shapes;
- whether `ranked_results` has a concrete response schema (the prose contract deliberately leaves it narrative-only);
- any route, method, or operation-ID mismatch for the six iOS surfaces; and
- any server endpoints intentionally outside this app's scope.

No endpoint gap is asserted yet: the actual published document has not been vendored in this repository, so a claim of parity would not be inspectable evidence.
