# Issue #5: generated OpenAPI client verification

This is the tests-first plan and the PR-description evidence for replacing the
hand-written `/api/v1` transport layer. The provider dependency is complete:
[`viamin/color_matching#110`](https://github.com/viamin/color_matching/issues/110)
closed on 2026-10-30 and serves OpenAPI 3 at `/api/v1/openapi.json`.

## Acceptance-criterion map

| Criterion | Smallest credible verification | Status in this tests-only change |
| --- | --- | --- |
| Package uses `swift-openapi-generator` and `swift-openapi-runtime`; provider spec is fetched or vendored | Inspect `iOS/Package.swift`, generation configuration, and committed OpenAPI artifact in the implementation PR | Not run: implementation is intentionally out of scope for this tests-only phase. |
| Generated client covers manifest, recent sheets, capture creation, measurement upload, judgment upload, and ranked results | Local `URLProtocol` stubs in `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift` exercise each operation and its request/response contract | Red: ranked-results operation has no client method yet. Existing tests cover the three uploads; this change adds the three GET surfaces. |
| Hand-written API models are replaced, preserving client-side models | Inspect the implementation diff and compile the app against the generated module | Not run: requires implementation. |
| Swift tests use local stubs, never a live server | `APIClientTests` injects `URLSession` with `MockURLProtocol`; every test supplies its own response | Ready for implementation verification. |
| `swift test --disable-sandbox` is green | Run after the generated package is committed | Not run: `swift` is unavailable in this container, and the intentionally red ranked-results test cannot compile until implementation exists. |
| PR description records prose-contract deltas and endpoint gaps | This document supplies the text below; a human can inspect it against the provider source and served OpenAPI document | Recorded. |

## Contract deltas found

- The prose contract says only that ranked results include source colours,
  scores, labels, provenance, printer profile, and algorithm version. The
  published server response is concrete: it is `lps-ranked-results/v1` and
  contains sheet-level capture timestamps/counts and per-pair rank, row/column,
  aggregate score statistics, observation information, and source-colour
  objects. The new red test fixes a representative complete stub response.
- Capture creation accepts both the prose contract's nested `metadata`/`quality`
  payload and a legacy flat payload (`CaptureRequest.anyOf`). The generated
  client must use the nested shape used by the iOS app.
- The prose requires all capture metadata fields and enumerates rejection and
  judgment strings. The published schema requires only a subset of metadata and
  represents rejection and judgment values as unrestricted strings. The client
  should retain its client-side validation/domain enums rather than silently
  broaden app behaviour.
- The prose measurement payload includes `scoring_algorithm_version` and
  detailed `stats`; the published `MeasurementUploadRequest` documents only
  measurements and pair scores, permits RGB in three compatibility encodings,
  and documents pair score as `score`, `similarity`, or `distance`. This is an
  endpoint/schema gap to resolve before generation: either expand the provider
  schema to document the iOS payload or adapt the iOS request to the published
  form without changing scoring behaviour.
- The prose omits success response bodies for measurement and judgment uploads;
  the published spec declares structured response bodies. The generated client
  should accept and ignore or use those typed success responses deliberately.
- The prose manifest's printer profile has `id`, `name`, `paper`, `ink`, and
  `settings`. The provider now emits printer make/model, paper/ink type, ICC,
  driver, calibration, and notes fields; the published manifest schema currently
  only requires `schema_version`, `sheet_id`, and capture-profile algorithm
  version. That under-specification is a generation gap because the iOS app
  needs geometry/patch/pair fields from the manifest.

## Endpoint gaps discovered

The six app-relevant routes are present in the provider OpenAPI path list:

- `GET /api/v1/test_sheets/{sheet_id}/manifest`
- `GET /api/v1/test_sheets/recent`
- `POST /api/v1/test_sheets/{sheet_id}/captures`
- `POST /api/v1/captures/{capture_id}/measurements`
- `POST /api/v1/captures/{capture_id}/judgments`
- `GET /api/v1/test_sheets/{sheet_id}/ranked_results`

There is no route gap. The manifest and measurement schema precision gaps above
must be addressed before a generated client can safely replace the current
hand-written Codable models.
