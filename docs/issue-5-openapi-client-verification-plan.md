---
module: iOS
tags:
  - openapi
  - swift
  - api-client
problem_type: verification_plan
---

# Issue #5 OpenAPI Client Verification Plan

This test-writing change maps each acceptance criterion to evidence that the
implementation change must produce. The published upstream specification is
the authority, not this repository's former prose contract.

| Criterion | Smallest credible verification | Evidence at this revision |
| --- | --- | --- |
| Add `swift-openapi-generator` and `swift-openapi-runtime`; vendor/fetch spec | `swift package resolve` plus an inspectable, pinned OpenAPI document and generator configuration | Not run: implementation-phase change |
| Generate all app-used surfaces | Compile tests that call generated operations for manifest, recent sheets, capture creation, measurement upload, judgment upload, and ranked results | Partially covered by permanent local-stub tests; generated operation coverage is not yet implemented |
| Replace hand-written API models | Compile succeeds after the app adapter uses generated request/response types; review confirms only client-side measurement models remain | Not run: implementation-phase change |
| Generated client local-stub tests | Permanent `APIClientTests` use `MockURLProtocol`, with no live server; each exercised operation asserts request path/authentication and decodes a stub response | Manifest and recent-sheet reads are covered in `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift` |
| Record prose/spec deltas and endpoint gaps | Inspect the vendored upstream specification against `docs/color-matching-api-contract.md`; record the comparison in the PR description | Human/external evidence required after the spec is vendored |
| `swift test --disable-sandbox` green | Run the exact command in an environment with Swift installed | Not run here: the container does not provide a `swift` executable |

The existing write-operation tests in `APIClientTests` cover capture creation,
measurement upload, and judgment upload. The implementation must preserve
those behavioral assertions while replacing their hand-written transport
models. A new ranked-results stub test is required once the published spec's
response schema is vendored; the current prose contract intentionally omits a
response shape for that endpoint.

## Prose Contract Gaps To Resolve In The PR Description

- `GET /api/v1/test_sheets/:sheet_id/ranked_results` has no response schema in
  the prose contract, so a typed result cannot be derived from it.
- The prose manifest's `printer_profile` shape conflicts with the server-shaped
  fixture already used by `MeasurementCoreTests` (`id`/`name`/`paper`/`ink`/
  `settings` versus `printer_make_model`/`paper_type`/`ink_type`).
- The prose contract describes a shared bearer token as MVP behavior; the
  OpenAPI security scheme and requiredness must be compared directly.
