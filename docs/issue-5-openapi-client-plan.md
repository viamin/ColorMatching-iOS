---
module: ios-api
tags: [openapi, swift, testing]
problem_type: implementation-plan
---

# Issue #5 OpenAPI client: test and evidence plan

This is the test-writing (red) phase for #5. Implementation files and package
configuration are deliberately not changed in this commit. The next phase must
vendor or fetch the OpenAPI document from the upstream service at
`GET /api/v1/openapi.json`, add `swift-openapi-generator` and
`swift-openapi-runtime`, generate the client, and replace the hand-written wire
models without changing the app's capture or scoring models.

## Criterion coverage plan

| Criterion | Smallest credible verification | Status in this phase |
| --- | --- | --- |
| Generated OpenAPI dependency and checked-in/fetched document | Inspect `Package.swift`, the generation configuration, and the vendored/fetchable document at the PR head. | Not run: implementation phase. |
| Manifest and recent-sheet generated operations | Permanent URLProtocol stub tests in `APIClientTests`; assert route, authentication, and decoding, using response shapes rendered by the upstream service. | Implemented; currently exercise the legacy facade. |
| Capture creation, measurement upload, and judgment upload generated operations | Permanent URLProtocol stub tests in `APIClientTests`; assert route plus request JSON and response handling. | Existing coverage retained; generated-client assertion deferred to implementation phase. |
| Ranked-results generated operation | Permanent URLProtocol stub test once the generated operation and response type are available. | Not run: no current app facade or response model exists. |
| Hand-written API wire models removed | Inspect generated target and `APIClient.swift`; compilation proves app adapters use generated types. | Not run: implementation phase. |
| No live server in CI | `swift test --disable-sandbox` runs URLProtocol stubs only. | To be run after generated client is wired in. |
| PR documents contract deltas and endpoint gaps | This file provides the evidence gathered from the upstream routes/spec source; copy its delta section into the implementation PR description. | External evidence gathered; final PR evidence pending. |

## Contract deltas and endpoint gaps found

The upstream issue is closed and publishes the document dynamically through
`GET /api/v1/openapi.json`; it does not commit a static OpenAPI JSON file.
The implementation needs a reproducible fetch/vendor step pinned to the
upstream revision or an explicit checked-in artifact.

The upstream router contains all six companion routes: recent sheets, manifest,
ranked results, capture creation, measurement upload, and judgment upload.
The existing app implements the first five but has no ranked-results API call or
response model, despite the prose contract naming that endpoint.

The prose says a manifest contains page geometry, markers, profiles, patches,
and pairs. The rendered upstream response does contain those fields, but its
published OpenAPI `Manifest` schema currently only requires `schema_version`,
`sheet_id`, and `capture_profile`; the additional response fields are not
machine-described. Likewise, the OpenAPI `RankedResults` schema only describes
`schema_version` and `sheet_id`, while the server renders profiles, capture
provenance, result rows, score aggregates, and judgments. Generation will
therefore not yield the complete types the prose promises until the upstream
spec is expanded.

For capture creation, the upstream schema accepts either the nested
`metadata`/`quality` payload described by the prose or a legacy flat payload.
The current app uses the nested form. Measurement and judgment uploads return
`200` JSON count payloads upstream, whereas the prose and current tests use
`204`; the generated client must accept the published `200` responses and the
stub tests should be updated to assert their decoded count payloads.
