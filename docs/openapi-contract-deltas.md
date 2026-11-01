# OpenAPI Contract Deltas: `docs/color-matching-api-contract.md` vs. the Published Spec

Source for this analysis: `viamin/color_matching` PR
[#113](https://github.com/viamin/color_matching/pull/113) ("Publish OpenAPI 3
spec for the `/api/v1` API and enforce it in CI"), which closed
[#110](https://github.com/viamin/color_matching/issues/110) and merged on
2026-10-30. The spec is served dynamically at `GET /api/v1/openapi.json`
(`OpenApiSpex.Plug.RenderSpec`, built from
`ColorMatchingWeb.ApiSpec.spec/0`) rather than committed as a static file, so
this document was produced by reading the merged source directly:
`lib/color_matching_web/api_spec.ex`, `api_schemas.ex`,
`controllers/test_sheet_controller.ex`, `controllers/test_sheet_json.ex`, and
`controllers/capture_controller.ex`, plus the persistence/normalization layer
they call into (`lib/color_matching/persistence.ex`,
`lib/color_matching/persistence/capture_upload.ex`).

This replaces the "fetch the spec file and diff it" step for issue #5's
"what changed between the prose contract and the published spec" deliverable
with a direct read of the behavior the spec documents (or fails to
document). No live server is required to produce or consume this document.

## Compatible as documented

- `POST /api/v1/test_sheets/:sheet_id/captures`: the nested
  `metadata`/`quality` request shape in the prose contract is accepted as-is.
  `Persistence.normalize_capture_attrs/1` explicitly flattens aliases
  (`metadata.exposure_duration_seconds` → `exposure_duration`,
  `quality.rejections` → `rejection_reasons`) so the existing hand-written
  `APIClient.createCapture` payload needs no changes.
- `POST /api/v1/captures/:capture_id/judgments`: request shape matches
  (`judgments: [{pair_id, judgment}]`).
- `capture_id` is returned/consumed as a string in every endpoint, matching
  the hand-written models.

## Deltas and gaps

### 1. `stats` is accepted but is not in the published schema (measurement upload)

`APIClient.uploadMeasurements` nests per-patch robustness stats under
`stats: {sample_count, clipping_fraction, mean, standard_deviation}`, per the
prose contract. The server's `CapturePatchMeasurement` changeset requires
exactly those four fields, and
`Persistence.CaptureUpload.normalize_measurement_attrs/2` reads them from a
nested `stats` map with a comment confirming this is intentional:

> "The iOS contract nests robustness stats under `stats`; older callers send
> them flat. Accept both, with the top-level value preferred."

However, `ApiSchemas.MeasurementUploadRequest` only declares
`patch_id`, `linear_rgb_median`, `normalized_linear_rgb_median` on each
measurement item — **`stats` (and its four required sub-fields) is entirely
undocumented in the OpenAPI schema**, even though the server requires it to
persist a measurement. A client generated strictly from the published spec
would not know this field exists or is required. **This is the most
actionable gap to raise upstream before/while generating the client** —
either add `stats` to `MeasurementUploadRequest`, or document the
already-supported flat aliases (`sample_count`, `clipping_fraction`, `mean`,
`standard_deviation` at the top level of each measurement item) as the
canonical shape.

### 2. `linear_rgb_median` / `normalized_linear_rgb_median` / `mean` / `standard_deviation` accept three shapes

`ApiSchemas.RgbPayload` is `anyOf`: a 3-element number array, an
`{r, g, b}` object, or a bare string (pre-encoded). The prose contract only
documents the object form. The hand-written client only ever sends the
object form, which is still valid, so this isn't a break — but a generated
client will surface this as a 3-way union/`oneOf` type that the prose
contract gave no indication of.

### 3. `pair_scores[]` accepts `score`, `similarity`, or `distance` as alternatives, not `distance` + `similarity` together

The prose contract's example sends both `distance` and `similarity` for a
pair score. The real `PairScoreRequest` schema requires `pair_id` and
`algorithm_version`, then `anyOf: [score, similarity, distance]` — exactly
one signal, not a pair. Server-side `resolve_score/1` prioritizes
`score` > `similarity` > `1 - distance`, clamped to `[0, 1]`, and stores a
single `score` value. Downstream, `GET .../ranked_results` only ever exposes
that unified `score` (see #6) — there is no way to retrieve the original
`distance`/`similarity` split back out. The hand-written client currently
sends both fields per the old contract; that still works (the server picks
`similarity`), but a generated client's stricter typing will make the
`anyOf` explicit, and callers should standardize on sending exactly one of
the three going forward.

### 4. Upload responses return JSON bodies the hand-written client discards

The prose contract shows no response body for measurement/judgment uploads
(implying `204`). The real endpoints return `200 OK` with a body:

- `POST .../measurements` → `{capture_id, measurement_count, pair_score_count}`
- `POST .../judgments` → `{capture_id, judgment_count}`

`APIClient.uploadMeasurements`/`uploadJudgments` only validate the status
code and discard the body (`send(_:)` in `APIClient.swift`). Not a breaking
change today, but the generated client should decode and the app should
surface these counts (e.g., to confirm the server accepted every row) rather
than silently dropping them.

### 5. `printer_profile` shape in the manifest does not match the prose contract at all

Prose contract (`manifest.printer_profile`):

```json
{"id": "printer_profile_1", "name": "...", "paper": "...", "ink": "...", "settings": {}}
```

Real `TestSheetJSON.render_printer_profile/1` (used by both `manifest` and
`ranked_results`):

```json
{
  "printer_make_model": "...",
  "paper_type": "...",
  "ink_type": "...",
  "icc_profile": "...",
  "print_settings": {},
  "driver_name": "...",
  "driver_version": "...",
  "calibration_date": "2026-01-01",
  "calibration_version": "...",
  "notes": "..."
}
```

No field names overlap (`id`/`name`/`paper`/`ink`/`settings` vs.
`printer_make_model`/`paper_type`/`ink_type`/...), and there is no `id` at
all. The app currently has no `PrinterProfile` Swift model and ignores this
object entirely (Codable silently drops unknown keys), so there's no runtime
break today, but the generated client's `PrinterProfile` type must be built
from this real shape, not the prose contract's.

### 6. `GET /api/v1/test_sheets/:sheet_id/ranked_results` is a response the app does not fetch yet, and the published schema barely describes it

This endpoint is one of the five surfaces issue #5 calls out
("ranked results"), but `APIClient` has no method for it today — there is
no existing hand-written model to compare against, only the one paragraph
of prose in `docs/color-matching-api-contract.md` ("source colors, scores,
labels, capture provenance, printer profile, and scoring algorithm
version").

The published `ApiSchemas.RankedResults` schema only declares
`schema_version` and `sheet_id` as properties — it documents essentially
none of the actual response. The real shape, read from
`TestSheetJSON.ranked_results/1` and `ColorMatching.RankedResults`, is:

```json
{
  "schema_version": "lps-ranked-results/v1",
  "sheet_id": "sheet_123",
  "printer_profile": { "...": "see #5 above" },
  "capture_count": 3,
  "latest_capture_at": "2026-07-25T12:00:00Z",
  "earliest_capture_at": "2026-07-20T09:00:00Z",
  "scoring_algorithm_versions": ["lps-distance-v1"],
  "results": [
    {
      "rank": 1,
      "pair_id": "pair_1",
      "scoring_algorithm_version": "lps-distance-v1",
      "row": 0,
      "col": 1,
      "source_colors": {"color_a_hex": "#FF0000", "color_b_hex": "#00FF00"},
      "score": {
        "average": 0.965,
        "latest": 0.97,
        "minimum": 0.9,
        "maximum": 0.98,
        "capture_count": 2,
        "sample_count": 2,
        "algorithm_versions": ["lps-distance-v1"]
      },
      "current_judgment": "near_match",
      "current_judgment_observed_at": "2026-07-25T12:05:00Z",
      "observation_count": 2,
      "latest_observation": {"judgment": "near_match", "observed_at": "2026-07-25T12:05:00Z"},
      "capture_count": 2,
      "earliest_capture_at": "2026-07-20T09:10:00Z",
      "latest_capture_at": "2026-07-25T12:05:00Z"
    }
  ]
}
```

This is the biggest gap found: a client generated strictly from the
published OpenAPI schema today would get a near-empty `RankedResults` type
(`schema_version` + `sheet_id` only) and would need the schema fleshed out
upstream — or a hand-maintained override — before it's usable. Also note
`source_colors` here is an **object** (`{color_a_hex, color_b_hex}`), while
the manifest's pair-level `source_colors` is an **array** of hex strings
(`["#FF0000", "#00FF00"]`) — same field name, different shape, across two
endpoints the app will call back to back.

### 7. `recent_sheets[].title` is always `null` today

The prose contract says `title` "may be `null`" (implying it's sometimes
populated). `TestSheetJSON.render_recent_sheet/1` hardcodes
`title: nil` unconditionally — there is currently no code path that
populates it server-side. Not a client-side typing problem (`title` is
already optional in the hand-written `RecentSheet` model), but worth knowing
before building any UI around it.

## Net effect on the generated-client work (issue #5)

- Endpoints needing upstream spec fixes before generation produces a usable
  type, in priority order: **ranked results** (#6 — schema says almost
  nothing) and **measurement upload `stats`** (#1 — required fields are
  completely undocumented).
- `printer_profile` (#5) needs the generated type built from the real
  `TestSheetJSON` shape; there is no existing Swift model to migrate, so
  this is new code, not a replacement.
- `pair_scores[]` (#3) and the upload response bodies (#4) are places where
  the generated client's stricter typing will do more than the hand-written
  client does today (expose the `anyOf`, expose discarded response counts);
  that's consistent with issue #5's intent (drift becomes a compile error)
  even though it's not something breaking today.
