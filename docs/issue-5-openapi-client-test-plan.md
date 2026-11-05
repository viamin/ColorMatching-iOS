# Issue #5 OpenAPI client verification plan

This is the tests-first record for replacing the hand-written iOS API client.
The upstream dependency is [viamin/color_matching#110](https://github.com/viamin/color_matching/issues/110), delivered by [PR #113](https://github.com/viamin/color_matching/pull/113). Its OpenAPI document is served dynamically at `GET /api/v1/openapi.json`; it is not a checked-in JSON or YAML artifact.

## Acceptance-criterion map

| Criterion | Smallest credible verification | Location / status |
| --- | --- | --- |
| Add generator/runtime dependencies and vendor or fetch the document | Package manifest and generated-source review; the dependency is external and cannot be proven by an app test. | Human/external evidence required in the implementation PR. |
| Generate the manifest, recent-sheets, capture, measurement, judgment, and ranked-results surfaces | Local-stub unit tests issue every operation and decode each specified response. | `APIClientTests`; manifest/recent/capture/measurement/judgment stubs are in place. Ranked results is deliberately red until the generated operation exists. |
| Replace hand-written API models while retaining client-only models | Source review plus compilation against generated types. | Human/source evidence and `swift test --disable-sandbox` in implementation run. |
| Exercise generated client without a live server | Permanent local `URLProtocol` stub tests. | `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift`. |
| Record prose-contract deltas and endpoint gaps | Inspect the upstream published OpenAPI output and server spec modules. | This document; requires PR-body transfer before merge. |

## Published-spec deltas and gaps

- The spec is generated dynamically by `ColorMatchingWeb.ApiSpec` at `/api/v1/openapi.json`; the iOS package must fetch a pinned copy during generation or explicitly vendor the fetched document.
- `POST .../measurements` and `POST .../judgments` return `200` JSON acknowledgement bodies, not the prose contract's implied empty `204` responses. Their acknowledgement fields are `capture_id` plus respectively `measurement_count`/`pair_score_count` and `judgment_count`.
- Measurement uploads in the spec do not include the prose field `scoring_algorithm_version`; each pair score instead requires `algorithm_version` and one of `score`, `similarity`, or `distance`. `normalized_linear_rgb_median` is required by the published schema. The prose-only per-measurement `stats` object is not modeled in the published schema.
- The published capture schema permits both the prose nested `metadata`/`quality` shape and a legacy flat shape. `iso` is an integer in the spec, while the current client-side metadata model uses `Float`.
- Recent-sheet `manifest_url` is a string in the spec (the current hand-written model decodes it as `URL`).
- The real ranked-results response includes printer profile, aggregate timestamps/counts, algorithm versions, and ranked pair results. The current published `RankedResults` schema declares only `schema_version` and `sheet_id`; generation cannot provide typed access to the remaining real response fields. This is an upstream endpoint-schema gap that must be resolved or consciously treated as an untyped additional-properties response before this issue can close.
- The prose contract describes the ranked-results endpoint, but the current hand-written iOS `APIClient` does not expose it. The red test records that missing operation.

## Red-phase result

The ranked-results test is an intentional assertion failure, not a skipped test. It demonstrates the missing operation while keeping the test target compilable. The implementation run must replace it with a local-stub test that calls the generated typed operation and asserts decoded ranked results.
