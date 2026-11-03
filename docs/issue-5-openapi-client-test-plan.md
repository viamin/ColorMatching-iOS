---
module: iOS
tags: [openapi, swift, api-client, testing]
problem_type: implementation-plan
---

# Issue #5 OpenAPI client: test and verification plan

## Scope and source of truth

The upstream dependency is complete: `viamin/color_matching#110` is closed and
commit `47057afd58f7d46b4d4b740ca7d2d08947774471` defines and serves the
OpenAPI document at `GET /api/v1/openapi.json`. The iOS implementation must
vendor that document at a pinned upstream commit (or fetch the same URL during
generation) and configure `swift-openapi-generator` and
`swift-openapi-runtime` in `iOS/Package.swift`.

The generated client must cover these app surfaces:

| Surface | Method and path | Permanent verification |
| --- | --- | --- |
| Sheet manifest | `GET /api/v1/test_sheets/{sheet_id}/manifest` | Local `URLProtocol` stub decodes the generated response and verifies bearer authentication. |
| Recent sheets | `GET /api/v1/test_sheets/recent` | Local stub decodes a nullable title and verifies bearer authentication. |
| Create capture | `POST /api/v1/test_sheets/{sheet_id}/captures` | Local stub verifies generated request JSON and decodes `capture_id`. |
| Upload measurements | `POST /api/v1/captures/{capture_id}/measurements` | Local stub verifies generated JSON and accepts the generated success response. |
| Upload judgments | `POST /api/v1/captures/{capture_id}/judgments` | Local stub verifies generated JSON and accepts the generated success response. |
| Ranked results | `GET /api/v1/test_sheets/{sheet_id}/ranked_results` | Local stub decodes the generated ranked-results response and verifies bearer authentication. |

`iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift` is the permanent
boundary suite. Its existing upload tests and the manifest/recent tests added
in this PR use local `URLProtocol` responses only; they must be moved to call
the generated transport or the thin app adapter during implementation. No live
Phoenix server belongs in CI.

## Acceptance-criterion mapping

| Criterion | Smallest credible verification | Status in this tests-only PR |
| --- | --- | --- |
| Add generator/runtime and OpenAPI document | Inspect the pinned document and `Package.swift` dependency/plugin configuration; `swift test --disable-sandbox` compiles generated types. | Not run: implementation phase. |
| Generate the six used surfaces | The six local-stub tests listed above compile against generated operations and assert decoded/generated payloads. | Partially prepared: manifest/recent/capture/measurements/judgments stubs exist; ranked-results adapter/test awaits implementation. |
| Replace hand-written API models | Code review plus compilation showing app imports generated types while MeasurementCore-only models remain. | Not run: implementation phase. |
| Generated client tests have no live server | Inspect `URLProtocol` stubs in `APIClientTests`; run the focused Swift test target. | Partially prepared; generated client wiring awaits implementation. |
| Contract deltas and endpoint gaps recorded | Human-reviewable PR description based on the pinned document and its upstream commit. | Recorded below for the implementation PR. |

## Prose-contract deltas found against upstream

The document is served dynamically by the Phoenix app, so the commit above is
the inspectable source used for this comparison.

- The published `Manifest` schema currently requires only `schema_version`,
  `sheet_id`, and `capture_profile.scoring_algorithm_version`; the prose
  contract additionally describes `sheet_version`, `manifest_url`, layout,
  printer profile, patches, and pairs. This leaves the generated manifest type
  less precise than the fields the iOS measurement flow consumes.
- The published capture request accepts either the prose nested
  `metadata`/`quality` structure or a legacy flat shape. The prose specifies
  only the nested shape. Capture metadata requires fewer fields in the
  published schema than the prose contract describes.
- The published capture uploads return JSON success bodies (`200`) containing
  identifiers and counts. The prose client contract models uploads as empty
  success responses; generated operations must consume or deliberately discard
  those bodies.
- The published document includes ranked results and gives it
  `schema_version: lps-ranked-results/v1`; the prose contract names the
  endpoint but does not define its response schema.
- The document also describes palette/printer-profile endpoints and two
  non-`/api/v1` POST endpoints that this iOS app does not use. They are outside
  this issue's generated-client surface.

## Endpoint gap to resolve before implementation is accepted

The app does not currently call ranked results, despite the issue requiring
that generated surface. The implementation PR must either add a thin,
behavior-preserving adapter and local-stub test, or explicitly record why the
unused generated operation is retained without UI wiring. It must not change
capture or scoring behavior.
