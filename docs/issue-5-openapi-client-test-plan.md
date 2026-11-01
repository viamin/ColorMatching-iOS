# Issue #5 OpenAPI client test plan and contract deltas

## Criterion verification plan

| Criterion | Smallest credible verification | Status in this tests-only change |
| --- | --- | --- |
| Generated client package and vendored/fetched published document | Package manifest and committed OpenAPI artifact review; `swift package resolve` | Not implemented in this phase |
| Generated client covers manifest, recent sheets, capture creation, measurement upload, judgment upload, and ranked results | Local `URLProtocol` stubs exercise every generated operation and decode its typed response | Existing stubs cover capture/measurement/judgment; `APIClientTests` adds manifest/recent coverage. Ranked results has no iOS operation yet. |
| Hand-written server models are replaced while client-only models remain | Compile-time review of generated type use in `APIClient` and app call sites | Not implemented in this phase |
| No-live-server Swift test coverage | Permanent unit/service tests using `MockURLProtocol` | `APIClientTests` |
| Contract-delta and endpoint-gap record | Inspectable PR description based on upstream OpenAPI spec | Recorded below for the implementation PR |

## Published-spec comparison

Source inspected: `viamin/color_matching` issue #110, closed on 2026-10-30, and its OpenAPI schema modules on `main`.

- The prose manifest and recent-sheets payloads match the published schema at the fields used by this app. The published schema explicitly requires `title` in each recent-sheet item while allowing it to be null; the prose contract only says that it may be null.
- Capture creation supports both the nested iOS-compatible `metadata`/`quality` body and a legacy flat body. The prose documents only the nested shape.
- Measurement uploads accept RGB channels as arrays, objects, or JSON strings, and pair scores can use `score`, `similarity`, or `distance`. The prose documents only object RGB values and the distance/similarity form.
- Measurement and judgment uploads return 200 JSON acknowledgement bodies with `capture_id` and counts. The prose client models these operations as no-content responses, so the current client discards those fields.
- Ranked results is now explicitly versioned as `lps-ranked-results/v1`; the prose describes its content but does not give an example schema. The iOS app currently has no ranked-results method or UI call site. This is the endpoint gap to resolve during implementation.

## Implementation handoff

Vendor the upstream `GET /api/v1/openapi.json` output at a pinned revision, add `swift-openapi-generator` and `swift-openapi-runtime`, generate only the six app operations, and migrate `APIClient` to generated request/response types. Keep conversion adapters only where camera/scoring domain types remain client-side. Extend `APIClientTests` with a ranked-results stub and update the existing three write-path stubs to assert generated acknowledgement response decoding.
