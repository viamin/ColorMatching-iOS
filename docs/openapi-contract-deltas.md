# Contract Deltas: Prose Contract vs Published OpenAPI Spec

This report records what changed between the hand-written prose contract in
`docs/color-matching-api-contract.md` and the machine-readable contract that
`viamin/color_matching` now publishes.

| Source | What it is |
| --- | --- |
| `docs/color-matching-api-contract.md` | The prose contract this app was built against. |
| `GET /api/v1/openapi.json` on `viamin/color_matching` | The published OpenAPI 3 document, added by `viamin/color_matching` PR #113 ("Publish OpenAPI 3 spec for the /api/v1 API and enforce it in CI (Schemathesis + oasdiff)") which closes the tracking issue #110 this repo's issue #5 depends on. |

The published document describes 15 paths. The six paths this app uses are:

```
GET  /api/v1/test_sheets/recent
GET  /api/v1/test_sheets/{sheet_id}/manifest
GET  /api/v1/test_sheets/{sheet_id}/ranked_results
POST /api/v1/test_sheets/{sheet_id}/captures
POST /api/v1/captures/{capture_id}/measurements
POST /api/v1/captures/{capture_id}/judgments
```

Every path in the prose contract exists in the published document. The deltas
below are all about *shape*, not about missing routes.

## Summary

| # | Area | Prose contract | Published spec | Server behaviour | Impact on this app |
| --- | --- | --- | --- | --- | --- |
| 1 | Sheet manifest | Full payload (page, markers, printer profile, patches, pairs) | Only `schema_version`, `sheet_id`, `capture_profile.scoring_algorithm_version` | Renders the full payload | A generated manifest type drops `patches` and `pairs`, so the sheet cannot be analysed |
| 2 | Ranked results | "source colors, scores, labels, capture provenance, printer profile, and scoring algorithm version" | Only `schema_version` and `sheet_id` | Renders `printer_profile`, `capture_count`, capture timestamps, `scoring_algorithm_versions` and a `results[]` array | A generated ranked-results type is empty of everything the app would display |
| 3 | Measurement upload | Each measurement carries `stats` | `measurements[]` declares only `patch_id`, `linear_rgb_median`, `normalized_linear_rgb_median` | Reads `stats` and stores `sample_count`, `clipping_fraction`, `mean`, `standard_deviation` | A spec-only client silently drops the robustness statistics the server persists |
| 4 | Scoring version | `scoring_algorithm_version` at the top level of the upload | Not declared; `algorithm_version` is per pair score | Ignores the top-level field, persists per-pair `algorithm_version` | The per-pair field carries the provenance; the top-level field is redundant |
| 5 | Normalized median | Optional in the app | `normalized_linear_rgb_median` is **required** | Validates the request body | A capture without a normalized median is rejected with `422` |
| 6 | RGB payload | `{"r": ..., "g": ..., "b": ...}` | `RgbPayload` is `anyOf[array, object, string]` | Accepts all three, stores a JSON string | The object form the app sends is valid |
| 7 | Capture creation | `{"metadata": {...}, "quality": {...}}` | `CaptureRequest` declares flat fields, `metadata`, `quality` **and** a top-level `anyOf` | Accepts nested `metadata`/`quality` groups and flat fields | OpenAPI composition makes `anyOf` win, so a generated request type cannot carry `quality` next to `metadata` |
| 8 | Printer profile | `{id, name, paper, ink, settings}` | `PrinterProfile` declares `id`, `printer_make_model`, `paper_type`, `ink_type` | Renders `printer_make_model`, `paper_type`, `ink_type`, `icc_profile`, `print_settings`, `driver_name`, `driver_version`, `calibration_date`, `calibration_version`, `notes` | The prose shape is stale; there is no `id` or `name` in the payload |
| 9 | Patch identifiers | `"id": "patch_1"`, pair `"first_patch_id": "patch_1"` | Not described | `"pair_1#first"` / `"pair_1#second"` | Patch ids are composite; they must be carried through unchanged |
| 10 | Errors | Not documented | `ApiErrorResponse` with `errors` as an object or an array of `{detail, source}` | `{"errors": {"detail": "..."}}` for `400/401/404/422` | The app can stop collapsing every failure into one error |
| 11 | The spec itself | Not mentioned | Served at `GET /api/v1/openapi.json` (unauthenticated) | — | The document can be fetched from the running server |
| 12 | Unsupported methods | Not mentioned | Not documented | `405` with an `Allow: GET` header on read-only endpoints | Nothing to do on the client |

## Endpoint gaps

The published spec covers more of the server than the prose contract asks for,
and none of the extra surfaces are missing:

- `GET /api/v1/printer_profiles`, `GET /api/v1/printer_profiles/{printer_profile_id}/colors`,
  `GET /api/v1/printer_profiles/{printer_profile_id}/metamer_pairs`, `GET /api/v1/palettes`,
  `GET /api/v1/colors` — palette and printer-profile lookups this app does not use yet.
- `POST /api/illuminant_measurements`, `POST /api/illuminant_measurements/bulk`,
  `POST /api/multi_image_mapping` — server-side measurement entry and colour mapping.
- `GET /api/v1/openapi.json` — the contract document itself.

The prose contract asks for nothing the server does not expose.

## Consequences for the generated client

The published document is authoritative for *routes* but not for *payloads*. Two
of the deltas (1 and 2) mean a client generated from the document alone cannot
carry the sheet geometry the analyzer needs, and one (3) means it would drop
measurement statistics the server stores. `docs/openapi-generated-client.md`
records how this repo handles that: the vendored document keeps the published
shape and adds the missing fields locally, and every local addition is listed
here and flagged in the document itself.
