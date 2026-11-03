# OpenAPI client migration (#5)

## Verification plan

| Criterion | Smallest credible verification | Status in tests-only PR |
| --- | --- | --- |
| Generated package dependencies and vendored/fetched document | Inspect `iOS/Package.swift`, the pinned OpenAPI document, and generated-target configuration | Not yet implemented |
| Generated typed operations for manifest, recent sheets, capture creation, measurement upload, judgment upload, and ranked results | Local `URLProtocol` system-style tests that exercise each generated operation with fixture responses | Existing facade coverage expanded for manifest, recent sheets, capture, measurements, and judgments; ranked-results coverage cannot be written against a missing client operation |
| Hand-written API models replaced while client-only models remain | Compile the app and inspect the generated model imports and retained MeasurementCore types | Not yet implemented |
| No live server in CI | The same `URLProtocol` tests run under `swift test --disable-sandbox` | Ready once the generated client replaces the facade |
| PR records contract deltas and endpoint gaps | This document, based on the published provider source at the pinned commit below | Complete external evidence |

The permanent tests are deliberately stubbed at the `URLSession` boundary. They protect the recurring sheet-discovery and capture-upload flow without needing a Phoenix server or database.

## Published-spec evidence

On 2026-11-03, `viamin/color_matching#110` was closed. Its OpenAPI endpoint is served dynamically at `GET /api/v1/openapi.json`; there is no static OpenAPI file in the provider repository. This review used provider commit [`47057afd58f7d46b4d4b740ca7d2d08947774471`](https://github.com/viamin/color_matching/tree/47057afd58f7d46b4d4b740ca7d2d08947774471) and its [router](https://github.com/viamin/color_matching/blob/47057afd58f7d46b4d4b740ca7d2d08947774471/lib/color_matching_web/router.ex), [operation declarations](https://github.com/viamin/color_matching/blob/47057afd58f7d46b4d4b740ca7d2d08947774471/lib/color_matching_web/controllers/test_sheet_controller.ex), and [schemas](https://github.com/viamin/color_matching/blob/47057afd58f7d46b4d4b740ca7d2d08947774471/lib/color_matching_web/api_schemas.ex).

The implementation PR must download `/api/v1/openapi.json` from a configured provider environment, check in the exact document used for generation, and record its source URL and SHA-256. A repository commit alone cannot reproduce the generated JSON because the provider builds the specification from routes and schema modules at runtime.

## Contract deltas and endpoint gaps

- The real provider exposes all six relevant paths, including `GET /api/v1/test_sheets/:sheet_id/ranked_results`. The iOS app has no ranked-results API call today, despite the prose contract listing it.
- The OpenAPI `Manifest` schema only requires `schema_version`, `sheet_id`, and `capture_profile.scoring_algorithm_version`. It does not describe the page, markers, patches, pairs, or `manifest_url` that `MeasurementCore.SheetManifest` requires. A generated model from the published schema cannot replace that model without a provider-spec expansion or a deliberately retained client-side decoding adapter.
- The OpenAPI ranked-results schema similarly specifies only `schema_version` and `sheet_id`; the full response is rendered by the provider but not machine-described. The generated client cannot expose typed ranked rows until this is fixed upstream.
- The prose capture body uses `metadata` and `quality`, which the provider accepts. The published OpenAPI additionally accepts a legacy flat capture body. It declares `iso` as an integer (the iOS hand-written model uses `Float`) and does not require any `quality` fields.
- Measurement uploads in the prose include top-level `scoring_algorithm_version` and per-measurement `stats`; the OpenAPI schema does not describe either. It requires only patch IDs and raw/normalized RGB medians when rows are supplied. It also describes successful `200` JSON count responses, while the old tests modeled `204` empty responses.
- The prose restricts judgments to `match`, `near_match`, and `no_match`; the published schema allows any string.
- The prose leaves ranked-result fields informal. The provider renders a `lps-ranked-results/v1` envelope, aggregate scores, provenance, and judgments, but those fields are absent from the OpenAPI schema.

These gaps need resolution before claiming that the generated types entirely replace the app's hand-written API models. The implementation may still generate operation bindings, but it must not silently downgrade required manifest/ranked-result fields to untyped dictionaries.
