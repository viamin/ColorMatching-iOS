---
module: ios-api-client
tags: [openapi, swift, contract-testing]
problem_type: test-plan
---

# Issue #5 OpenAPI client verification plan

This is the acceptance-criterion map for the generated OpenAPI-client change.
It was prepared before implementation so its tests can be added before replacing
the existing hand-written transport.

| Criterion | Smallest credible verification | Current red-phase evidence |
| --- | --- | --- |
| Generated client covers manifest, recent sheets, capture creation, measurement upload, judgment upload, and ranked results | Permanent Swift stub tests invoke each generated operation through a local `URLProtocol` transport; assert route, request shape, and typed response. | `APIClientTests` now provides stubs for the first five current routes. Ranked-results has no current client operation, so its generated-client test remains for implementation. |
| Generated types replace API transport models | Compile the app after removing the hand-written transport DTOs; the app’s capture and sheet flows must type-check against generated models. | Not runnable in the test-writing phase. |
| No live server in CI | Every API test configures a local `URLProtocol` responder and asserts the request. | `APIClientTests.swift` uses `MockURLProtocol`; no network host is contacted. |
| Published contract deltas are recorded | Inspect the source OpenAPI implementation merged by `viamin/color_matching#113`, which closes #110, and compare it with `docs/color-matching-api-contract.md`. | This document records the observed deltas below. |

## Published-contract deltas and endpoint gaps

The published contract is served by `GET /api/v1/openapi.json` in
`viamin/color_matching` (merged PR #113).

- Capture creation accepts two request shapes: legacy flat capture attributes or
  nested `metadata`; the prose contract documents only the nested shape.
- The OpenAPI capture metadata schema requires image width and height, while the
  existing client models them as optional.
- Measurement and judgment uploads return `200` JSON acknowledgement objects
  (`capture_id` plus counts). The prose contract describes neither response and
  the current client expects an empty successful response.
- The measurement schema requires normalized RGB values and permits RGB values
  as an array, object, or JSON-encoded string. The prose contract documents only
  RGB objects and treats normalized RGB as an ordinary field.
- Pair scores require `algorithm_version` and one of `score`, `similarity`, or
  `distance`; the prose contract assumes both similarity and distance.
- The spec declares only minimal manifest and ranked-result response fields.
  It does not describe the full manifest geometry emitted by the server, nor the
  ranked-result rows and nested score objects. Generated models for those
  surfaces therefore need either a provider-spec expansion or carefully scoped
  additional-properties handling before the hand-written models can be removed.

These are external-contract observations, not a replacement for inspecting the
actual generated diff in the implementation PR.
