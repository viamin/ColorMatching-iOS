---
module: "iOS generated API client"
tags:
  - openapi
  - swift
  - api-client
problem_type: "test_plan"
---

# Issue #5 OpenAPI client acceptance plan

This is the red-phase test plan for replacing the hand-written iOS API layer. The
implementation run must fetch `viamin/color_matching`'s published OpenAPI document
from `GET /api/v1/openapi.json`, pin or vendor the fetched document and its source
revision, add `swift-openapi-generator` and `swift-openapi-runtime`, generate the
client, and replace transport DTOs with generated operation input/output types.

## Criterion-to-verification mapping

| Criterion | Smallest credible verification | Evidence location | Current status |
| --- | --- | --- | --- |
| Generated package dependencies and vendored/fetched OpenAPI document | Inspect `iOS/Package.swift`, generator configuration, and pinned document revision in the implementation PR | Implementation diff and package resolution output | Not run: test-writing phase cannot modify implementation files. |
| Generated client covers manifest, recent sheets, capture creation, measurement upload, and judgment upload | Permanent local-`URLProtocol` Swift tests exercise each operation with a fixture response or captured request | `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift` | Ready: existing write tests plus added manifest/recent tests. |
| Generated client covers ranked results | Permanent local-stub Swift test decoding a real-spec fixture and checking the generated operation | `APIClientTests.swift:testFetchRankedResultsIsImplementedByTheGeneratedClient` | Failing intentionally: no ranked-results client operation exists today. |
| Hand-written transport models are removed while client-only measurement models remain | Inspect implementation diff and compile the app target | Implementation diff and `swift test --disable-sandbox` | Not run: implementation phase required. |
| No live server in CI | Tests inject `URLProtocol` responses and never open a network listener | `APIClientTests.swift` | Ready. |
| Contract deltas and endpoint gaps are recorded in the PR description | Human inspection of the PR description against the fetched, pinned OpenAPI document | PR description | Not run: no PR is opened in this run. |

## Upstream-spec evidence and deltas to resolve

`viamin/color_matching#110` is closed. Its source defines the OpenAPI document
dynamically via `ColorMatchingWeb.OpenApiController` and `OpenApiSpex.Plug.RenderSpec`;
the issue identifies `GET /api/v1/openapi.json` as the public endpoint. There is no
committed static `priv/static/openapi.json` to vendor directly. The implementation
must fetch the live document once, record its commit/SHA and checksum, and commit the
result under the iOS package so regeneration is repeatable.

The prose contract declares ranked-results retrieval but omits its response schema.
That is a material gap: a generated Swift client cannot offer a useful typed ranked
results result until the published OpenAPI operation supplies a 2xx response schema.
The deliberately failing ranked-results test is the acceptance guard for this gap.

The prose manifest example contains `created_at`, `printer_profile`, and
`capture_profile`, while the current app-side `SheetManifest` model ignores them.
The implementation must compare requiredness, nullability, enum values, and response
schemas in the fetched document before finalizing the generated-type adapters. Those
findings belong in the implementation PR description; they cannot be inferred from
the prose contract alone.
