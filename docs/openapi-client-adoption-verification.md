# OpenAPI client adoption verification

This is the implementation handoff and PR evidence plan for issue #5. It
keeps the test-writing phase scoped to durable tests and documents the
external dependency that the implementation phase must resolve.

## Acceptance criteria and verification

| Criterion | Smallest credible verification | Initial status |
| --- | --- | --- |
| Generated client dependencies and a vendored OpenAPI document | `GeneratedOpenAPIClientConfigurationTests.testVendoredSpecificationAndPackageConfigurationCoverEveryAppOperation` checks the package configuration and every path used by the app. | Failing: neither dependency nor vendored spec is present. |
| Generated client covers manifest, recent sheets, capture creation, measurements, judgments, and ranked results | The same configuration test requires all six paths. The implementation must add transport tests that invoke the generated operations through `MockURLProtocol`. | Failing: no generated client or vendored spec is present. |
| Client-side models remain local while API models become generated | Implementation review: API response/request models must be imported from the generated target; `MeasurementCore` analysis and camera models remain local. | Not run: requires implementation. |
| Local stubbed Swift tests exercise the generated client | `APIClientTests` already supplies deterministic local URLProtocol responses and now covers manifest and recent-sheet responses as well as the existing write payloads. Implementation must migrate these tests to generated-operation calls and add ranked-results coverage. | Not run: generated target does not exist. |
| `swift test --disable-sandbox` is green | Run after generated types are wired in. | Not run: red-phase configuration test intentionally fails. |

## Upstream-spec evidence and contract deltas

On 2026-11-04, `viamin/color_matching#110` was closed, but its public GitHub
tree did not expose an OpenAPI document and the deployed API URL was not
available from this environment. Therefore there is no inspectable published
schema to vendor or compare during this test-writing run. The implementation
PR must record the source URL and pinned revision/digest of the fetched spec,
then replace this section with the actual prose-contract comparison.

The existing prose contract itself leaves ranked-results response fields
unspecified. That is already a consumer gap: the generated operation must be
validated against the published response schema before the app can adopt it.
