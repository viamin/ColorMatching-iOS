# Contract Deltas: Prose Doc vs. Published OpenAPI Spec

This records what changed between the hand-written prose contract
(`docs/color-matching-api-contract.md`) and the real `/api/v1` API, now
that `viamin/color_matching#110` ("Publish OpenAPI 3 spec for the
`/api/v1` API and enforce it in CI") has shipped in
[viamin/color_matching#113](https://github.com/viamin/color_matching/pull/113)
(merged `094bd6d3443ddacbda7e63354299867eb5bdfa9f`). The server now serves
the machine-readable spec at `GET /api/v1/openapi.json`
(`ColorMatchingWeb.ApiSpec`, built from `OpenApiSpex` route + controller
annotations — there is no static spec file checked into that repo to
vendor; it must be fetched from a running instance or regenerated from
`mix run` in that codebase).

This is prep for the issue #5 migration to a generated Swift client. The
Package.swift/generator wiring and model replacement are implementation
work for a follow-up run; this document and the accompanying
characterization/placeholder tests in `iOS/Tests/` capture what that run
needs to reconcile.

## Headline finding: ranked results has zero client support today

The issue's deliverable list names "ranked results" as a surface the app
uses today, but there is no `RankedResults` model and no
`APIClient.fetchRankedResults` (or similar) method anywhere in
`iOS/Sources`. `GET /api/v1/test_sheets/:sheet_id/ranked_results` is a real,
already-implemented, already-tested (server-side) endpoint
(`ColorMatchingWeb.TestSheetController.ranked_results`,
`ColorMatchingWeb.TestSheetJSON.ranked_results/1`) that this app has never
called. The generated-client migration is the first point this endpoint
gets a Swift type at all, not just a replacement of an existing one.

Real response shape (schema version `lps-ranked-results/v1`):

```json
{
  "schema_version": "lps-ranked-results/v1",
  "sheet_id": "RNKD-2345",
  "printer_profile": {
    "printer_make_model": "Epson SureColor P900",
    "paper_type": "Ultra Premium Luster",
    "ink_type": "OEM UltraChrome PRO10",
    "icc_profile": null,
    "print_settings": null,
    "driver_name": null,
    "driver_version": null,
    "calibration_date": null,
    "calibration_version": null,
    "notes": null
  },
  "capture_count": 1,
  "latest_capture_at": "2026-07-28T12:34:56.123456Z",
  "earliest_capture_at": "2026-07-28T12:34:56.123456Z",
  "scoring_algorithm_versions": ["ios-score/v1"],
  "results": [
    {
      "rank": 1,
      "pair_id": "RNKD-2345-0-0",
      "scoring_algorithm_version": "ios-score/v1",
      "row": 0,
      "col": 0,
      "source_colors": {"color_a_hex": "#FF0000", "color_b_hex": "#00FFFF"},
      "score": {
        "average": 0.91,
        "latest": 0.91,
        "minimum": 0.91,
        "maximum": 0.91,
        "capture_count": 1,
        "sample_count": 1,
        "algorithm_versions": ["ios-score/v1"]
      },
      "current_judgment": null,
      "current_judgment_observed_at": null,
      "observation_count": 0,
      "latest_observation": null,
      "capture_count": 1,
      "latest_capture_at": "2026-07-28T12:34:56.123456Z",
      "earliest_capture_at": "2026-07-28T12:34:56.123456Z"
    }
  ]
}
```

This is nothing like the one-line placeholder in the prose doc ("The
Phoenix app should return the latest or aggregate ranked results with
source colors, scores, labels, capture provenance, printer profile, and
scoring algorithm version") — the prose doc never specified field names,
so there was no way to hand-write this model correctly without guessing.
`iOS/Tests/ColorMatchingLPSAppTests/RealContractCoverageTests.swift` has a
failing placeholder test (`testRankedResultsEndpointHasNoClientSupportYet`)
that decodes this exact shape into a local fixture-only type and then
fails, documenting that production code has no equivalent yet.

## `SheetManifest` is missing fields the real schema requires

The published `TestSheetManifest` OpenAPI schema
(`ColorMatchingWeb.ApiSchemas.Manifest`) declares `capture_profile` as a
**required** property (alongside `schema_version` and `sheet_id`), with
`capture_profile.scoring_algorithm_version` itself required and enum-
constrained to `["lps-distance-v1"]`. The real manifest response also
always includes `created_at` and a `printer_profile` object. None of
`capture_profile`, `created_at`, or `printer_profile` exist on
`MeasurementCore.SheetManifest` today — `JSONDecoder` silently drops them
because Swift's `Decodable` ignores unknown keys by default, so decoding
doesn't fail, but the app can't read a field it never modeled.

- `printer_profile` shape is **not** what the prose doc showed. The prose
  doc's example (`{"id", "name", "paper", "ink", "settings"}`) does not
  match the real renderer (`TestSheetJSON.render_printer_profile/1`):
  `printer_make_model`, `paper_type`, `ink_type`, `icc_profile`,
  `print_settings`, `driver_name`, `driver_version`, `calibration_date`,
  `calibration_version`, `notes`. There is no `id` or `name` field at all.
- `capture_profile` real shape matches the prose doc:
  `expected_illuminant`, `preferred_camera`, `scoring_algorithm_version`.

`iOS/Tests/MeasurementCoreTests/MeasurementCoreTests.swift` already had a
characterization test (`testDecodesContractManifestFromServer`, predating
this pass) proving decode tolerates these extra keys. This pass adds
`testManifestRequiredCaptureProfileAndPrinterProfileAreNotModeled`, a
failing placeholder documenting that the client still can't *read*
`capture_profile`/`printer_profile`/`created_at`, which the generated
client's `Components.Schemas.TestSheetManifest` type will expose.

## Patches: the real manifest never emits `reference` patches

The prose doc documents two patch roles, `pair_color` and `reference`
(with reference roles `white`/`gray`/`black`/`blank_paper`). The real
renderer (`TestSheetJSON.render_patches/2`) only ever emits patches
derived from `sheet.pairs`, tagged `role: "pair_color"` — there is no code
path that emits a `role: "reference"` patch today. Whether that's a
deliberate scope cut for the MVP sheet layout or a documentation-only
feature that was never implemented server-side is unclear; flagging it so
the generated-client migration doesn't assume reference patches will show
up in practice.

## `recent_sheets.title` is always `null` today

The prose doc says `title` "may be `null` when the Phoenix app has no
display name for the sheet," implying it's sometimes populated. The real
renderer (`TestSheetJSON.render_recent_sheet/1`) hardcodes
`title: nil` unconditionally — there is currently no code path that
produces a non-null title. Not a client-side bug, just worth knowing the
field is dead weight until the server implements it.

## Upload responses are real payloads, and the client throws them away

Both upload schemas changed shape and the client ignores the bodies
entirely:

- `POST /api/v1/captures/:capture_id/measurements` returns
  `{"capture_id": "...", "measurement_count": N, "pair_score_count": N}`
  on success (`CaptureController.handle_measurement_upload/3`,
  `MeasurementUploadResponse` schema). `APIClient.uploadMeasurements`
  (`iOS/Sources/ColorMatchingLPSAppCore/APIClient.swift`) calls the
  private `send(_:)` helper, which validates the status code and discards
  the body.
- `POST /api/v1/captures/:capture_id/judgments` returns
  `{"capture_id": "...", "judgment_count": N}`
  (`JudgmentUploadResponse` schema). `APIClient.uploadJudgments` discards
  this body the same way.

Neither is a decode failure today (nothing attempts to decode), but it's a
real gap relative to "what the published spec says the endpoint returns."
`RealContractCoverageTests.swift` has two failing placeholders
(`testMeasurementUploadResponseBodyIsDiscardedByClient`,
`testJudgmentUploadResponseBodyIsDiscardedByClient`) documenting this so
the generated client's typed `Output` isn't silently discarded again.

## Measurement upload request: the client sends fields the published schema doesn't declare

The real `MeasurementUploadRequest` schema
(`ColorMatchingWeb.ApiSchemas.MeasurementUploadRequest`) only declares
`measurements` (each: `patch_id`, `linear_rgb_median`,
`normalized_linear_rgb_median`) and `pair_scores`. There is **no**
`scoring_algorithm_version` top-level property and **no** `stats` property
on a measurement item anywhere in the published schema — yet
`APIClient.uploadMeasurements` sends both (`scoring_algorithm_version` at
the request root, and a full `stats` object — `sample_count`,
`clipping_fraction`, `mean`, `standard_deviation` — per measurement). The
server presumably ignores unknown JSON keys today (nothing in
`capture_controller.ex` reads them), but a generated request type built
strictly from the published schema will not have fields to put this data
in. **This is a real risk for the follow-up implementation run**: either
the spec needs those fields added upstream (file against
`viamin/color_matching`) before the generated type can carry them, or the
team needs to confirm the server truly never needed `stats` /
`scoring_algorithm_version` and it's safe to stop sending them. This
document flags it; it is not encoded as a failing Swift test because
nothing in the client fails to compile or run today — it's a data-loss
risk in the next run's wire format, not a bug in this one.

## Things that already line up

- `GET /api/v1/test_sheets/recent` response shape (`sheets[].sheet_id`,
  `manifest_url`, `title`) matches the prose doc and
  `APIClient.fetchRecentSheets` / `RecentSheet` exactly.
- `POST /api/v1/test_sheets/:sheet_id/captures` accepts the nested
  `{"metadata": {...}, "quality": {...}}` shape the client sends — the
  real `CaptureRequest` schema's `anyOf` requires either that shape or a
  flattened one; the client already uses a valid branch. Response
  (`{"capture_id": "..."}`) matches `CaptureSessionResponse` exactly.
- `POST /api/v1/captures/:capture_id/judgments` request shape
  (`judgments[].pair_id`, `judgments[].judgment`) matches
  `JudgmentUploadRequest` / `PairJudgment` exactly.
- Registration markers are always exactly 4, in a fixed order
  (`top_left`, `top_right`, `bottom_right`, `bottom_left`), matching what
  `MeasurementCoreTests` already assumes.

## Endpoints the app doesn't use (out of scope for issue #5, noted for completeness)

`viamin/color_matching#110`'s spec also covers endpoints this app has
never touched and the issue's non-goals exclude: `printer_profiles`,
`palettes`, `colors`, `metamer_pairs`, `/api/illuminant_measurements` (+
`/bulk`), and `/api/multi_image_mapping`. No action needed here; listed so
a future reader doesn't wonder why they're absent from this delta list.
