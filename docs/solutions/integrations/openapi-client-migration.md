---
module: iOS API client
tags: [openapi, swift, generated-client, color-matching]
problem_type: migration
---

# Generated OpenAPI client migration evidence

## Criterion verification plan

| Criterion | Smallest credible verification | Status in test-writing phase |
| --- | --- | --- |
| Swift OpenAPI generator/runtime and published document are wired into the package | `APIClientTests.testGeneratedOpenAPIClientModuleIsAvailable` imports the generated module | Red: the module is intentionally absent until implementation |
| Generated client covers manifest, recent sheets, capture creation, measurement upload, judgment upload, and ranked results | Local `URLProtocol` stubs exercise every generated operation after the adapter is implemented | Red: ranked-results adapter and generated module do not exist yet |
| Generated response/request types replace server-owned handwritten models | Compile the app and test target after the adapter is rewritten to use generated types | Not runnable until implementation |
| Local-stub Swift coverage | `swift test --disable-sandbox` | Existing manifest/recent/create/upload tests run against `MockURLProtocol`; generator-module assertion is expected red |
| PR documents contract deltas and gaps | This section is copied into the PR description | External/reviewer evidence |

## Published spec deltas

The published server contract is served at `GET /api/v1/openapi.json` by
`viamin/color_matching#110`. Compared with this repository's prose contract:

- `ranked_results` is now a documented operation, but its current response
  schema requires only `schema_version` (`lps-ranked-results/v1`) and
  `sheet_id`. The detailed ranking payload promised by the prose contract is
  not yet machine-described.
- The manifest schema currently requires only `schema_version`, `sheet_id`,
  and `capture_profile.scoring_algorithm_version`; the prose contract describes
  a substantially richer manifest. The generated client must therefore retain
  client-side decoding only for data that the app consumes until the server
  schema becomes complete.
- Capture creation accepts both the prose contract's nested `metadata`/
  `quality` form and a flat compatibility form. In the nested metadata form,
  `image_width` and `image_height` are required by the published schema,
  whereas the hand-written iOS model makes them optional.
- Measurement uploads in the published schema require both RGB median fields,
  do not describe the app's `stats` or top-level
  `scoring_algorithm_version`, and describe a successful response body with
  counts. The prose contract describes a request-only flow and permits an
  optional normalized median.
- Judgment uploads and recent-sheet responses match the prose shapes closely;
  the published spec makes a recent sheet's nullable `title` required as a
  property.

## Endpoint gap requiring follow-up

The generated client can be introduced for the typed portions of these six
operations, but the server spec must be expanded before it can fully replace
the app's manifest and ranked-results server models without an adapter or
additional client-side representation.
