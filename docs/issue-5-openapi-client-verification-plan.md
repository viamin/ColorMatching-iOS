# Issue #5 generated OpenAPI client verification plan

This is the criterion-level test plan for replacing the hand-written iOS API
layer. It is intentionally committed with the red-phase tests so the
implementation run has an inspectable definition of done.

## Verification map

| Criterion | Smallest credible verification | Location / evidence |
| --- | --- | --- |
| Vendor the upstream machine-readable contract and keep all required operations | Permanent unit test parses the vendored JSON document and checks the six companion paths | `iOS/Tests/ColorMatchingLPSAppTests/OpenAPIContractTests.swift` |
| Generate and wire the manifest, recent-sheet, capture, measurement, and judgment operations | Permanent local-stub client tests assert request paths, bearer authentication, request bodies, and decoded responses | `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift` |
| Wire ranked-results generated operation | Permanent local-stub client test for `GET /api/v1/test_sheets/{sheet_id}/ranked_results`, including the published response shape | Add in the implementation run alongside the generated facade |
| Remove hand-written API transport models while preserving client-only measurement models | Human code review of the generated target and facade; the test suite cannot establish code provenance | PR diff review |
| Record contract deltas and endpoint gaps | Human review of the PR description against the published OpenAPI source | PR description |

The first criterion is deliberately red at this test-only PR head:
`iOS/OpenAPI/color_matching.json` has not yet been vendored. The implementation
run must fetch `/api/v1/openapi.json`, commit the resulting document, configure
`swift-openapi-generator` and `swift-openapi-runtime`, then make this test pass.

## Published-contract comparison for the implementation PR

The server route and schema source in `viamin/color_matching` issue #110 show
that all six companion endpoints exist:

- `GET /api/v1/test_sheets/recent`
- `GET /api/v1/test_sheets/{sheet_id}/manifest`
- `GET /api/v1/test_sheets/{sheet_id}/ranked_results`
- `POST /api/v1/test_sheets/{sheet_id}/captures`
- `POST /api/v1/captures/{capture_id}/measurements`
- `POST /api/v1/captures/{capture_id}/judgments`

Differences from `docs/color-matching-api-contract.md` that the implementation
PR must preserve or explicitly resolve:

- The real manifest renderer emits a relative `manifest_url`; the prose example
  uses an absolute URL.
- The manifest and ranked-results schemas currently declare only their
  compatibility/version fields as required. The iOS measurement workflow still
  needs the richer fields rendered by the server, so generated models may need
  validation or a small adapter before reaching `MeasurementCore`.
- Capture creation accepts the prose document's nested `metadata` and `quality`
  form, but the published request schema also supports a legacy flat form.
- The prose contract says measurement and judgment uploads return `204`; the
  published API returns `200` acknowledgement JSON containing `capture_id` and
  counts.
- Measurement uploads in the published schema require normalized RGB values and
  allow RGB representations beyond the prose contract's object form. Pair
  scores accept `score`, `similarity`, or `distance` with an algorithm version.
- Ranked results have a concrete `lps-ranked-results/v1` response with ranking,
  aggregate score, capture provenance, printer profile, and judgment fields;
  the prose contract describes this endpoint but omits its response schema.

No endpoint gap was found for the six requested companion surfaces. The
published OpenAPI schema is intentionally permissive in places; generated Swift
types alone will not guarantee the richer fields the current app needs, which is
why the implementation PR must document any adapter retained at that boundary.
