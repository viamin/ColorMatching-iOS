---
module: ios-api-client
tags: [openapi, swift, contract]
problem_type: implementation-plan
---

# Issue #5: Generated OpenAPI client acceptance evidence

This document is the PR-description source for issue #5. It records the
criterion-level verification plan before implementation, and the contract
differences discovered from the published server work.

## Acceptance criteria and verification

| Criterion | Smallest credible verification | Status in this tests-only PR |
| --- | --- | --- |
| Generator and runtime dependencies plus a vendored/fetched spec | Package resolution and a checked-in spec provenance/refresh check | Not run: implementation work |
| Generated client covers manifest, recent sheets, capture creation, measurement upload, judgment upload, and ranked results | `APIClientTests` stubs each endpoint and checks decoded values or request payloads | Red: ranked-results operation is not present yet |
| Hand-written API models replaced, while client-only models remain | Compile the app target after deleting obsolete hand-written model declarations | Not run: implementation work |
| Generated client works against local responses | `swift test --disable-sandbox --filter APIClientTests`, using `MockURLProtocol` only | Red until the ranked-results operation is generated and wired in |
| PR records prose/spec deltas and endpoint gaps | This document, updated with the pinned spec revision and generated diff | Partially recorded below; needs final spec revision |

The normal recurring capture flow is covered by permanent unit/service tests:
manifest discovery, recent sheets, capture creation, measurement upload, and
judgment upload are all stubbed in
`iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift`. Ranked results has
an explicit red test because it is a user-visible API surface absent from the
current client; it must become a local-stub generated-client test in the
implementation PR.

## Contract deltas found before generation

The server issue is closed and its router serves the OpenAPI document at
`GET /api/v1/openapi.json`. Its implementation shows the same six sheet and
capture routes required by this issue.

Compared with `docs/color-matching-api-contract.md`, server rendering makes
these differences visible:

- Ranked results are now concretely versioned as `lps-ranked-results/v1` and
  include rank, current judgment, score aggregates, source-color fields, and
  capture/observation provenance. The prose contract only required a broad
  description of those fields.
- The prose manifest example's printer profile has `id`, `name`, `paper`,
  `ink`, and `settings`. The server renderer exposes printer make/model, paper
  type, ink type, ICC profile, print settings, driver metadata, calibration,
  and notes instead. Generated types must follow the published spec, not the
  old example.
- The prose contract lists reference patch roles. The server's current manifest
  renderer emits pair-color patches from test-sheet pairs; whether reference
  patches are represented in the published schema is a final spec-review item.

No endpoint gap is currently known for the six requested endpoints. The
implementation PR must pin the exact OpenAPI revision, regenerate the Swift
client, and amend this section with any generator/schema gaps found from that
artifact.
