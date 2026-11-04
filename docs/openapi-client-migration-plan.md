# OpenAPI client migration plan

This is the PR-description source for issue #5. It records the acceptance
criterion map and the upstream contract evidence gathered on 2026-11-04.

## Acceptance criterion map

| Criterion | Smallest credible verification | Current result |
| --- | --- | --- |
| Add `swift-openapi-generator` and `swift-openapi-runtime`; vendor or fetch the spec | `Package.swift` dependency plus a checked-in/reproducibly fetched `openapi.json`; `swift package resolve` | Not run: implementation phase required. |
| Generate the manifest, recent, capture, measurement, judgment, and ranked-results surfaces | Compile a client target that invokes each generated operation | Not run: no upstream `openapi.json` artifact has been supplied to this repository yet. |
| Replace handwritten API models while retaining client-only models | Compilation proves UI/core adapters use generated request/response types; code review identifies retained client-only types | Not run: implementation phase required. |
| Exercise generated client with local stubs | Permanent Swift tests with `URLProtocol` stubs cover all six generated operations | Partially prepared: `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift` covers manifest, recent sheets, capture creation, measurement upload, and judgment upload. Ranked results awaits the generated operation. |
| PR description records prose/spec deltas and endpoint gaps | This document, based on upstream issue #110 and its current `main` source/spec modules | Recorded below; runtime OpenAPI JSON remains external evidence to fetch/vendor before merge. |
| `swift test --disable-sandbox` is green with generated types wired in | Run that command after implementation | Not run: generated types are absent in this tests-only phase. |

The manifest/recent/capture/upload tests are permanent focused integration tests:
they use a local `URLProtocol` stub and exercise the transport adapter without a
live Phoenix server. They are not a substitute for the generated-client tests;
the implementation phase must update them to instantiate the generated client
and add the ranked-results stub.

## Published API deltas and gaps

Evidence source: [viamin/color_matching#110](https://github.com/viamin/color_matching/issues/110), closed 2026-10-30, plus the linked `main` router, controllers, and `ApiSchemas` source inspected 2026-11-04. The served document is declared at `GET /api/v1/openapi.json`, but no deployed base URL or static JSON document is published in the upstream repository. Fetch or vendor that exact served artifact during implementation; do not generate from the prose contract or reverse-engineer the schema modules.

- The upstream router has all six required routes: manifest, recent sheets, capture creation, measurement upload, judgment upload, and ranked results.
- The prose contract treats upload responses as unspecified. The published controller operations declare `200 OK` JSON responses: measurement upload returns `capture_id`, `measurement_count`, and `pair_score_count`; judgment upload returns `capture_id` and `judgment_count`. The handwritten client currently accepts any 2xx and discards these payloads.
- The nested `metadata` capture form remains accepted. The published schema requires `device_model`, `lens`, `image_width`, `image_height`, `app_version`, and `timestamp`; the current client exposes several of them as optional. It also models `iso` as an integer while the client uses `Float`.
- The published capture request schema additionally accepts a legacy flattened shape, uses `exposure_duration` there (versus `exposure_duration_seconds` in nested metadata), and has no rejection enum. The prose contract specifies only the nested shape and lists rejection strings.
- The published manifest schema currently guarantees only `schema_version`, `sheet_id`, and `capture_profile.scoring_algorithm_version`. The prose contract and current app consume a materially richer manifest. This is an endpoint-schema completeness gap that must be resolved upstream before a strongly typed replacement can preserve current behavior.
- The published ranked-results schema currently guarantees only `schema_version` (`lps-ranked-results/v1`) and `sheet_id`. The prose contract calls for source colors, scores, labels, capture provenance, printer profile, and scoring algorithm version. The app does not currently call this route, but the issue requires a generated surface and its stub test.
