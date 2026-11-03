# Issue #5: OpenAPI client verification plan

This document records the criterion-level verification plan for the generated
OpenAPI client work. It is intentionally checked in during the tests-only
phase so the implementation PR has an inspectable contract for completion.

## Acceptance criteria and verification

| Criterion | Smallest credible verification | Location/status in this tests-only PR |
| --- | --- | --- |
| Add `swift-openapi-generator` and `swift-openapi-runtime` | Focused package-manifest test | `APIClientTests.testPackageDeclaresGeneratedOpenAPIClientDependencies`; red until dependencies are added |
| Generate typed operations for manifest, recent sheets, capture creation, measurement upload, judgment upload, and ranked results | Local `URLProtocol` stubs through the generated-client-backed app API | Existing create/measurement/judgment tests plus new manifest/recent tests; ranked-results test is blocked until the generated operation is wired into a compilable public seam |
| Replace hand-written transport models but retain client-only models | Code review of generated source and public app boundary | Human/external evidence required; no test can prove a model was generated |
| Exercise generated client with local stubs | Permanent XCTest coverage with `MockURLProtocol`; no network access | `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift` |
| Record prose/spec deltas and endpoint gaps in the PR | Inspect the published provider OpenAPI source and PR body | Deltas below; final PR body still requires authoring during the implementation/PR run |
| `swift test --disable-sandbox` green | Run exact command after implementation | Not run in tests-only phase: the dependency assertion is intentionally red |

## Published-spec comparison

Evidence was inspected from `viamin/color_matching` PR #113, merged 2026-10-30,
which implements issue #110 and serves `GET /api/v1/openapi.json`.

The provider spec contains all six app surfaces: manifest, recent sheets,
capture creation, measurement upload, judgment upload, and ranked results.
No endpoint gap was found for the current iOS workflow.

The meaningful contract deltas are:

- The published manifest schema requires only `schema_version`, `sheet_id`, and
  `capture_profile.scoring_algorithm_version`; the prose contract describes the
  full page, marker, patch, pair, and profile payload used by the app. The
  generated type therefore cannot by itself replace the app's analysis manifest
  model unless the provider expands its response schema.
- The ranked-results schema requires only `schema_version` and `sheet_id`, while
  the prose contract expects source colors, scores, labels, capture provenance,
  printer profile, and scoring-algorithm version. Its output needs the same
  provider-schema expansion before it is a useful typed result model.
- Capture creation accepts both a legacy flat payload and the nested
  `metadata`/`quality` payload described in prose. In the nested form, the spec
  does not require `quality`; the prose contract presents it as present.
- The published measurement schema does not declare the prose
  `scoring_algorithm_version` or `stats` fields. It accepts the app's fields as
  additional JSON properties but does not type them.
- Measurement and judgment uploads return `200` JSON count payloads in the
  published spec; the prose contract states `204` with no response body.
- The published API requires bearer authentication for all workflow endpoints;
  its OpenAPI endpoint itself is public. The prose development-mode exception
  is environment behavior rather than a portable API guarantee.

## Implementation handoff

Keep the `APIClient` boundary only as an adapter where it protects client-only
measurement/scoring models. Its implementation should delegate all HTTP
operations to generated OpenAPI operations. Add a local-stub ranked-results
test once that operation is available; it must decode a representative provider
response and assert the generated operation's request path and bearer header.
