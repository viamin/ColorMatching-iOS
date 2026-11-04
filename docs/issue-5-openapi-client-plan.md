# Issue #5 OpenAPI Client Verification Plan

This document supplies the verification and PR-description material for the
generated-client implementation. It is intentionally recorded before the
implementation phase so the replacement preserves the current app behavior
rather than merely compiling a generated package.

## Criterion map

| Criterion | Smallest credible verification | Evidence status in this tests-only PR |
| --- | --- | --- |
| Add generator/runtime and a pinned OpenAPI document | `swift test --disable-sandbox` resolves the package and compiles the generated target | Not run: implementation-only change |
| Generate every required operation | Compile-time use of the generated operation types for manifest, recent sheets, capture creation, measurement upload, judgment upload, and ranked results | Not run: the upstream spec is incomplete for the app's required response models |
| Replace server-owned hand-written models | Compile the app after deleting the server-owned wrappers; retain only client-side analysis models | Not run: implementation-only change |
| Exercise the client with no live server | Permanent `URLProtocol` tests cover local JSON responses and request shapes | `APIClientTests` covers manifest, recent sheets, capture creation, measurement upload, and judgment upload; ranked results needs a complete response schema and an implementation target |
| Record prose/spec deltas and endpoint gaps | Inspect the upstream published spec source and its `/api/v1` router routes | Recorded below; external behavior still needs confirmation from the served `openapi.json` artifact used for generation |

## Upstream contract inspection

Inspection source: `viamin/color_matching` commit
[`094bd6d`](https://github.com/viamin/color_matching/commit/094bd6d3443ddacbda7e63354299867eb5bdfa9f)
and its current `ColorMatchingWeb.ApiSchemas` and router. The dependency
issue is closed and specifies `GET /api/v1/openapi.json` as the published
artifact.

### Confirmed route coverage

The upstream router includes all requested paths:

- `GET /api/v1/test_sheets/recent`
- `GET /api/v1/test_sheets/{sheet_id}/manifest`
- `POST /api/v1/test_sheets/{sheet_id}/captures`
- `POST /api/v1/captures/{capture_id}/measurements`
- `POST /api/v1/captures/{capture_id}/judgments`
- `GET /api/v1/test_sheets/{sheet_id}/ranked_results`

### Deltas and blocking gaps

The prose manifest contract requires page geometry, registration markers,
patches, and pairs. The published `TestSheetManifest` schema declares only
`schema_version`, `sheet_id`, and `capture_profile` (whose only declared
field is `scoring_algorithm_version`). A Swift client generated solely from
that schema cannot replace the app's `SheetManifest`, `Page`,
`RegistrationMarker`, `Patch`, or `PairManifest` models without losing the
fields used by capture analysis.

The prose ranked-results section intentionally did not define a response
body. The published `RankedResults` schema is likewise only
`schema_version` and `sheet_id`; it does not describe source colors, scores,
labels, capture provenance, printer profile, or algorithm version promised
by the prose contract. The app currently has no ranked-results call, so this
is an endpoint/model gap to resolve before adding one.

The upstream schemas do make the two versioned compatibility values
machine-visible: `lps-sheet-manifest/v1` and `lps-distance-v1`. This is an
improvement over the prose contract, but it does not close the response-model
gaps above.

## Implementation handoff

Do not vendor or generate from a guessed document. First fetch the served
`/api/v1/openapi.json` artifact and confirm it includes the fields above.
Pin that artifact in this repository, then add the generator/runtime targets
and migrate the API boundary. Extend `APIClientTests` with a ranked-results
stub once its response schema is complete. Run `swift test --disable-sandbox`
after the generated target is wired in.
