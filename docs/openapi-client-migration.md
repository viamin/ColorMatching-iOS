# OpenAPI client migration evidence

## Verification plan

| Criterion | Smallest credible verification | Status in test-writing phase |
| --- | --- | --- |
| Generated client covers manifest and recent sheets | Permanent local-stub XCTest sends a manifest and a recent-sheets response through the app-facing API client. | Passing coverage for the current facade; generation is not implemented yet. |
| Generated client covers capture creation, measurement upload, and judgment upload | Permanent local-stub XCTest verifies each request path, authorization, JSON body, and successful response status. | Passing coverage for the current facade; generation is not implemented yet. |
| Generated client covers ranked results | Permanent local-stub XCTest decoding the generated ranked-results operation. | Not runnable: no app-facing ranked-results operation exists. |
| Hand-written API models are replaced | Inspect `iOS/Sources/ColorMatchingLPSAppCore/APIClient.swift` and generated-client source after generation. | Not run: implementation phase. |
| OpenAPI document is fetched or vendored | Inspect the checked-in pinned document and the regeneration command. | Not run: implementation phase. |
| Contract deltas are recorded | Compare the prose contract with the upstream machine-readable OpenAPI response. | External evidence recorded below. |

The local-stub tests are permanent because manifest lookup and capture upload
are recurring app flows. They use `MockURLProtocol`, so CI needs no live
Phoenix server.

## Upstream evidence and contract deltas

Evidence was inspected on 2026-11-03 from the closed dependency
[viamin/color_matching#110](https://github.com/viamin/color_matching/issues/110),
its [router](https://github.com/viamin/color_matching/blob/main/lib/color_matching_web/router.ex),
and its [OpenAPI schema declarations](https://github.com/viamin/color_matching/blob/main/lib/color_matching_web/api_schemas.ex).
The document is served dynamically at `GET /api/v1/openapi.json`; it is not
checked into the Phoenix repository. The implementation must download and pin
that response (or vendor its exact JSON) before invoking `swift-openapi-generator`.

- The prose manifest requires page, markers, patches, pairs, printer profile,
  and capture profile. The published `Manifest` schema currently declares only
  `schema_version`, `sheet_id`, and `capture_profile.scoring_algorithm_version`.
  A generated model cannot safely replace `MeasurementCore.SheetManifest` until
  those fields are added to the upstream schema.
- The prose ranked-results description promises source colors, scores, labels,
  capture provenance, printer profile, and algorithm version. The published
  `RankedResults` schema declares only `schema_version` and `sheet_id`; no
  app-facing ranked-results operation currently exists.
- The prose measurement upload requires root `scoring_algorithm_version` and
  per-measurement `stats`; the published request schema declares measurements
  and pair scores but omits both. Conversely, the published endpoint returns a
  200 JSON receipt (`capture_id`, `measurement_count`, `pair_score_count`),
  while the prose contract and current app client expect an empty 204 response.
- The judgment upload likewise returns a 200 JSON receipt in the published
  schema/controller, while the prose contract and current client treat it as
  empty 204.
- The published capture schema accepts the current nested `metadata` and
  `quality` payload, but also preserves a legacy flattened form. It constrains
  `iso` to an integer, whereas the current client model uses `Float`.

## Endpoint gaps to resolve before implementation

1. Upstream needs to expand `Manifest` and `RankedResults` schemas to the
   complete response shapes used by iOS, or explicitly designate compatible
   component schemas for those fields.
2. Upstream needs to decide whether the measurement payload's root algorithm
   version and `stats` are supported compatibility fields, then describe them
   in OpenAPI. The iOS scoring behavior must not be changed merely to fit an
   incomplete schema.
3. The generated integration must decode (or intentionally discard with a
   documented adapter) the two 200 receipt responses instead of assuming 204.
