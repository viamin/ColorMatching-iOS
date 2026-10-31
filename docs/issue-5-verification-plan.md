---
module: "iOS API client"
tags:
  - openapi
  - swift
  - api-client
problem_type: "verification-plan"
---

# Issue #5 verification plan

This test-writing change establishes the local-stub seam that the generated
OpenAPI client must retain. No test contacts a live Phoenix server.

| Acceptance criterion | Smallest credible verification | Status in this test-writing change |
| --- | --- | --- |
| Generated dependency and checked-in/fetched document | Package-resolution and generation check after the spec is vendored | Not implementable in the tests-only phase |
| Generated client covers manifest, recent sheets, capture creation, measurement upload, judgment upload, and ranked results | Local `URLProtocol` stubs for every generated operation; compile-time use of generated operation and schema types | Manifest, recent sheets, capture creation, measurement upload, and judgment upload have local stub coverage. Ranked-results has no client call yet and needs its red test when generated operation names are available. |
| Hand-written API models replaced while client-only models remain | Compile the app against generated schema types; keep `MeasurementCore` types only where they describe local image analysis | Implementation-phase compile check |
| Generated client Swift tests use local stubs | `APIClientTests` uses `MockURLProtocol` and asserts decoded response and request shape | Covered for the five existing operations |
| PR records prose-contract deltas and endpoint gaps | Inspect the published `/api/v1/openapi.json` at the dependency commit and compare it to `docs/color-matching-api-contract.md` | Requires the vendored document; route inspection confirms ranked results exists upstream but is absent from the current iOS client. |

The implementation PR must update its description with the exact schema deltas
from the vendored OpenAPI document. The upstream issue is closed, but its
specification is served dynamically, so an unavailable deployment must not be
mistaken for evidence that the document has no deltas.
