# Contract Deltas: Prose Contract vs Published OpenAPI Spec

Comparison of `docs/color-matching-api-contract.md` (the prose contract, written first)
against the OpenAPI 3 spec published by `viamin/color_matching` at
`GET /api/v1/openapi.json` (viamin/color_matching#110). The PR that switches the iOS app
to a generated client must carry this delta record in its description.

Upstream references (commit observed 2026-11-02): `lib/color_matching_web/api_schemas.ex`,
`lib/color_matching_web/controllers/capture_controller.ex`,
`lib/color_matching_web/controllers/test_sheet_controller.ex`,
`lib/color_matching_web/controllers/test_sheet_json.ex`,
`lib/color_matching/persistence/capture_upload.ex`, `lib/color_matching_web/router.ex`.

## Summary of drift

| # | Area | Prose contract says | Published spec / server does | Severity |
| --- | --- | --- | --- | --- |
| 1 | Manifest shape | Full documented payload (`page`, `registration_markers`, `printer_profile`, `capture_profile`, `patches`, `pairs`, ...) | Spec only guarantees `schema_version`, `sheet_id`, `capture_profile.scoring_algorithm_version`. Server *does emit* the full payload today (`TestSheetJSON.manifest/1`). | High — generated types cannot cover the manifest without a vendored extension |
| 2 | `printer_profile` fields | `{id, name, paper, ink, settings}` | `{printer_make_model, paper_type, ink_type, icc_profile, print_settings, driver_name, driver_version, calibration_date, calibration_version, notes}` — no `id`, no `name` | Medium |
| 3 | Patch IDs | Example implies opaque IDs (`patch_1`) | Server derives `"{pair_id}#first"` / `"{pair_id}#second"`; measurement upload rejects patch IDs not on the sheet | Low |
| 4 | Capture request | One nested shape (`metadata` + `quality`) | Spec allows nested *or* flat legacy form via `anyOf`; the flat form names differ (`exposure_duration`, `rejection_reasons` vs nested `exposure_duration_seconds`, `rejections`) | Medium — see gap (a) |
| 5 | Measurement/judgment upload responses | Implied "accepted" with no body (the hand-written tests stubbed `204` empty) | Both return `200` with a required JSON body: `{capture_id, measurement_count, pair_score_count}` / `{capture_id, judgment_count}` | Medium — generated client now decodes counts |
| 6 | `normalized_linear_rgb_median` | Optional in the app (`RGB?`) | Spec marks it **required** in every measurement item | Low — the app always uploads normalized measurements today |
| 7 | `stats` block | Documented (`sample_count`, `clipping_fraction`, `mean`, `standard_deviation`) | Not in the spec; server accepts it (nested preferred, flat legacy also accepted) and persists it | Low — documented as a vendored extension |
| 8 | Top-level `scoring_algorithm_version` on measurement upload | Documented | Not in the spec; server ignores it — per-pair `algorithm_version` (required) is what is stored | Low |
| 9 | Pair scores | `distance`, `similarity`, `algorithm_version` | Spec: `pair_id` + `algorithm_version` required, any of `score`/`similarity`/`distance`; server stores a single clamped score, mapping `distance` → `1 - distance` | Low |
| 10 | Ranked results | Vague: "source colors, scores, labels, capture provenance, printer profile, scoring algorithm version" | Spec guarantees only `schema_version` (`lps-ranked-results/v1`) + `sheet_id`; server emits a rich payload (rank, per-pair score aggregates, current judgment, capture counts/provenance) | High for future UI — recorded as endpoint gap |
| 11 | Error shape | Not documented | `errors` is either an object or an array of `{detail, source.pointer}` (`json_render_error_v2`); 401/404/422 documented on every app-facing operation | Low |
| 12 | Auth | Shared bearer token | `bearerAuth` (`http`/`bearer`) security scheme on all app-facing operations; matches | None |
| 13 | Capture IDs | String `"capture_123"` | Integer IDs serialized as strings; path params cast back to integer | Low |
| 14 | Recent sheets | `sheets[]` with nullable `title` | Same; server currently always emits `title: null` | None |

## Endpoint gaps discovered

- **(a) `anyOf` + sibling `properties` is not generator-consumable.** `CaptureRequest`
  and `PairScoreRequest` in the served spec carry `properties` *and* a top-level `anyOf`.
  OpenAPIKit (used by swift-openapi-generator) drops sibling `properties` when `anyOf` is
  present, which would generate empty wrapper structs. The vendored document normalizes
  these schemas (see `docs/openapi-client-generation.md`). Upstream should restructure
  these schemas (e.g. `allOf` of `$ref`s) so the served spec is directly generatable.
- **(b) The served manifest schema under-documents the payload the iOS app depends on**
  (delta 1). Until upstream documents the full manifest, the vendored copy documents the
  fields the server actually emits, marked in the generation doc as a vendored extension.
- **(c) Ranked results payload is under-documented** (delta 10). The app does not consume
  it yet; the generated client covers only the guaranteed fields. Consuming the rows
  later requires an upstream schema first.
- **(d) `stats` and top-level `scoring_algorithm_version` are undocumented upstream**
  (deltas 7–8). Vendored as extension/optional fields to preserve today's wire behavior.
- **(e) Unused-by-iOS endpoints in the spec**: `/api/v1/printer_profiles`,
  `/api/v1/printer_profiles/{id}/colors`, `/api/v1/printer_profiles/{id}/metamer_pairs`,
  `/api/v1/palettes`, `/api/v1/colors`, `/api/illuminant_measurements`,
  `/api/illuminant_measurements/bulk`, `/api/multi_image_mapping`. Left untouched
  (non-goal: new endpoints).
- **(f) Judgments are free strings in the spec.** The prose contract enumerates
  `match`/`near_match`/`no_match`; the spec types `judgment` as a plain string (server
  validates elsewhere). The generated client cannot enforce the enum; kept as-is.

## Required changes to the hand-written layer

Recorded for the implementation PR:

- Upload calls must accept a `200` JSON body (and may surface the returned counts);
  the `204`-era stubs in `APIClientTests` are updated in the tests-only PR.
- `normalized_linear_rgb_median` must be treated as required by the upload path (delta 6).
- `PairJudgment`/`RecentSheet`/`CaptureMetadata`/`WhiteBalanceGains` hand-written Codable
  structs are replaced by generated `Components.Schemas.*` types; `MeasurementCore`
  domain structs stay.
