# Issue #5 OpenAPI Client Verification Plan

This tests-only change records the smallest credible verification for each
acceptance criterion before the generated-client implementation begins.

| Criterion | Verification | Current status |
| --- | --- | --- |
| Add the OpenAPI generator/runtime and document | Package resolution plus generated-source compile check | Not run: viamin/color_matching#110's published document is not present in this checkout. |
| Generate all app-used API surfaces | `APIClientTests` uses local `URLProtocol` stubs for manifest, recent sheets, capture creation, measurement upload, judgment upload, and ranked results | Blocked: the existing client has no ranked-results operation. The red test at `APIClientTests.swift` records this gap. |
| Replace hand-written API models | Compile check that imports generated types and excludes legacy transport types | Not run: generated types do not exist yet. Client-side measurement models remain out of scope. |
| Test generated client without a live server | Permanent `URLProtocol` tests in `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift` | Partially covered now; the tests run against local stubs, but exercise the legacy client until generation is wired in. |
| Record prose-contract deltas and endpoint gaps | Human/external comparison of `docs/color-matching-api-contract.md` against the OpenAPI document from viamin/color_matching#110 | Not run: no published OpenAPI document was available in this checkout. Known endpoint gap: ranked results is described by the prose contract but absent from `APIClient`. |

## Contract-delta review checklist for the implementation PR

Compare the published OpenAPI document with the prose contract and put concrete
findings in the PR description. In particular, verify request/response field
names, optionality, date formats, status codes, authentication requirements,
and the declared schemas for all six surfaces. Do not claim that a prose field
is supported merely because the current handwritten Codable type accepts it.
