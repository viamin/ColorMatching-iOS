# Contract deltas: prose contract vs. published OpenAPI spec

Comparison between `docs/color-matching-api-contract.md` (hand-written prose
contract) and the machine-readable spec published by viamin/color_matching#113
(served at `GET /api/v1/openapi.json`, issue #110). Facts below were read from
the upstream implementation (`ColorMatchingWeb.Router`, `ApiSpec`,
`ApiSchemas`, `TestSheetController`, `CaptureController`).

**Embed this file's tables in the PR description for issue #5 (deliverable:
"PR description records: what changed between the prose contract and the
published spec, and any endpoint gaps discovered").**

## Summary of what changed

| Surface | Prose contract (`docs/color-matching-api-contract.md`) | Published spec | Impact on the app |
| --- | --- | --- | --- |
| Manifest response | Full geometry: `sheet_version`, `manifest_url`, `created_at`, `page`, `registration_markers`, `printer_profile`, `capture_profile` (illuminant + camera + scoring version), `patches[]`, `pairs[]` | Declares only `schema_version` (enum `lps-sheet-manifest/v1`), `sheet_id`, `capture_profile.scoring_algorithm_version` (enum `lps-distance-v1`) | **Endpoint gap G1**: the patch/pair geometry the sheet analyzer consumes is not part of the published contract; generated types cannot express it. Needs an upstream spec addition; until then the manifest surface typed by the generated client is version + sheet id + scoring version only. |
| Ranked results | No schema at all ("latest or aggregate ranked results with source colors, scores, labels, capture provenance, printer profile, and scoring algorithm version") | `schema_version` (enum `lps-ranked-results/v1`, a version string absent from the prose) + `sheet_id`, nothing else | **Endpoint gap G2**: ranked pairs/scores/labels are not declared upstream; the app's ranked-results view has no typed payload to consume yet. |
| Recent sheets | `sheets[]` of `sheet_id`, `manifest_url`, `title?` | Same; `title` is required-but-nullable; upstream serves the 20 most recent | Compatible; ordering/limit now pinned (limit 20). |
| Capture creation request | Nested `metadata` + `quality` only | Compatibility `anyOf`: flat legacy fields (`exposure_duration` — note different name, `rejection_reasons`, …) **or** nested `metadata`/`quality`; nested form requires `metadata` only | iOS uses the nested form; vendoring patch **P1** keeps nested-only. |
| Capture metadata types | `iso` shown as number, `white_balance_gains` `{red,green,blue}` | `iso` is `integer`; `white_balance_gains` is an untyped object | App model used `Float` iso → now `Int`. Untyped gains → patch **P4** (`additionalProperties: true`) so the payload survives generation. |
| Capture quality enum | Six allowed rejection strings listed in prose | `rejections` is a plain string array; no enum | Client-side enum kept for UI; not server-enforced (gap G3). |
| Measurement upload request | Top-level `scoring_algorithm_version`; measurements carry `stats` (sample_count, clipping_fraction, mean, standard_deviation); `normalized_linear_rgb_median` optional | No top-level `scoring_algorithm_version` (per-score `algorithm_version` instead); **no `stats` object at all**; `normalized_linear_rgb_median` **required**; `linear_rgb_median` is `RgbPayload` (array \| {r,g,b} \| string) | **Drift D-a**: app's `stats` upload is dropped server-side silently. **Drift D-b**: normalized median must now be sent for every patch. Patch **P2** flattens score `anyOf(score|similarity|distance)` to optionals; patch **P3** fixes `RgbPayload` to the object form. |
| Measurement upload response | Not specified (app assumed empty 2xx; hand-written tests stubbed 204) | `200` + `{capture_id, measurement_count, pair_score_count}` | Drift D-c: the generated client makes a 204 undecodable here — exactly the class of runtime surprise this migration eliminates. |
| Judgment upload request | `judgments[]` of `{pair_id, judgment}` with allowed values `match`/`near_match`/`no_match` | Same shape; `judgment` is a plain string, **no enum** | Gap G3: value list not machine-checked upstream; app keeps its own validation. |
| Judgment upload response | Not specified (app assumed empty 2xx) | `200` + `{capture_id, judgment_count}` | Drift D-c (same class as measurements). |
| Status codes | Never stated | Pinned per operation: manifest 200/401/404; recent 200/401; ranked 200/401/404; capture create 201/401/404/422; uploads 200/401/404/422 | Error handling can now be typed. |
| Auth | "shared bearer token" prose | `bearerAuth` (`http`/`bearer`) security scheme on every operation | Matches; now machine-checked (coverage tests pin it). |
| Base path | `/api/v1` inline in endpoint paths | Server `{url: "/"}`; paths carry `/api/v1` | Client server URL is scheme+host only — do **not** append `/api/v1`. |
| Extra endpoints | — | Spec also covers `printer_profiles`, `palettes`, `colors`, `metamer_pairs` (metamer), `/api/illuminant_measurements(+bulk)`, `/api/multi_image_mapping` (macOS-app surfaces) | Generated client will contain these unused operations; harmless, kept for verbatim fidelity. |

## Documented vendoring patches (visible diff vs. upstream)

| Patch | Schema | Upstream shape | Vendored shape | Rationale |
| --- | --- | --- | --- | --- |
| P1 | `CaptureRequest` | object with flat legacy props + `anyOf(required-subsets)` + nested `metadata`/`quality` | Nested-only: `properties {metadata, quality}`, `required [metadata]` | Swift generation of a properties+`anyOf` hybrid drops the properties; the app only ever sends the nested form. |
| P2 | `PairScoreRequest` | `anyOf` subsets requiring `score` xor `similarity` xor `distance` | Optional `score`/`similarity`/`distance` properties; required `pair_id`, `algorithm_version` | Same hybrid-generation issue; the app sends `distance`+`similarity` together, which upstream accepts (`anyOf` is satisfied). |
| P3 | `RgbPayload` | `anyOf(array<number>, {r,g,b}, string)` | Object `{r,g,b}`, all required | The app only sends the object form; keeps a typed struct instead of anonymous `case1/2/3` payloads. |
| P4 | `CaptureMetadata.white_balance_gains` | `{type: object}` (untyped) | `additionalProperties: true` | Untyped objects generate as empty structs, silently dropping the gains; free-form keeps the data flowing. |

If upstream later types these properly, drop the corresponding patch — the
coverage tests fail until the assertion is updated, forcing the reconciliation
to be reviewed.

## Endpoint gaps to raise upstream (out of scope for this repo)

- **G1**: manifest geometry (page, registration markers, printer/capture
  profiles, patches, pairs) absent from the published spec — blocking for a
  fully typed manifest consumer.
- **G2**: ranked-results payload (pairs, scores, labels, provenance) absent.
- **G3**: judgment values and capture rejection reasons are not closed enums
  upstream.

## Provenance note

Upstream renders the spec at runtime; no static file exists in
viamin/color_matching. The vendored document must be dumped from
`GET /api/v1/openapi.json` when a deployment is reachable, or reconstructed
from the modules named above. `OpenAPISpecCoverageTests` pins the semantic
facts either way, so incidental serialization differences (descriptions,
parameter metadata) do not affect the gate.
