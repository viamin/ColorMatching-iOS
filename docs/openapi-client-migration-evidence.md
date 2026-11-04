# OpenAPI client migration: test plan and contract audit

This record is the PR/run evidence for issue #5's test-writing phase. The
implementation run must regenerate the Swift client from the vendored version
of the upstream document and replace the hand-written transport models only
where the generated schema has sufficient detail.

## Acceptance-criterion verification plan

| Criterion | Smallest credible verification | State in this tests-only PR |
| --- | --- | --- |
| Add `swift-openapi-generator` and `swift-openapi-runtime`, and vendor/fetch the upstream document | Inspect `iOS/Package.swift`, the committed spec, and generated-source diff | Not run: implementation-only change |
| Generate and use manifest, recent sheets, capture, measurements, judgments, and ranked results | Permanent `APIClientTests` stubs exercise every generated operation and decode its typed response | Blocked pending generated module and a complete upstream schema |
| Remove hand-written API models while retaining client-only models | Inspect `APIClient.swift` imports/types and compile `swift test --disable-sandbox` | Not run: implementation-only change |
| Test generated client with local stubs | `APIClientTests` uses `MockURLProtocol`; no live-server dependency | Red tests added for documented acknowledgements and the published manifest minimum |
| Record prose-to-spec changes and endpoint gaps | This audit, based on `viamin/color_matching` commit `094bd6d3443ddacbda7e63354299867eb5bdfa9f` | Complete external inspection; follow-up required upstream |
| `swift test --disable-sandbox` green | Run after generated client is wired | Intentionally red in this phase |

## Published-contract deltas

The upstream OpenAPI publisher is `viamin/color_matching#110`, merged as
commit `094bd6d3443ddacbda7e63354299867eb5bdfa9f` on 2026-10-30. Its document
is served dynamically at `GET /api/v1/openapi.json`; no versioned static
document is committed upstream.

- Manifest: the prose contract includes sheet version, manifest URL, page,
  registration markers, printer and capture profiles, patches, and pairs. The
  published `TestSheetManifest` schema requires only `schema_version`,
  `sheet_id`, and `capture_profile.scoring_algorithm_version`. This is a
  blocking gap: the app needs geometry and patch/pair data to analyze a sheet.
- Recent sheets: both contracts describe `sheets`, `sheet_id`, `manifest_url`,
  and nullable `title`; the published schema makes `title` explicitly
  required-and-nullable.
- Capture creation: the prose uses nested `metadata` plus `quality`. The
  published spec accepts that form, but also documents a legacy flat form and
  has stricter positive bounds for image dimensions, ISO, and exposure.
- Measurement upload: the prose describes a 204-style fire-and-forget upload.
  The published spec and controller return a 200 acknowledgement with
  `capture_id`, `measurement_count`, and `pair_score_count`. Pair scores also
  allow `score`, `similarity`, or `distance`.
- Judgment upload: the prose does not document a response. The published spec
  and controller return a 200 acknowledgement with `capture_id` and
  `judgment_count`.
- Ranked results: the prose promises source colors, scores, labels, capture
  provenance, printer profile, and scoring algorithm version. The published
  schema requires only `schema_version` (`lps-ranked-results/v1`) and
  `sheet_id`; it cannot generate a useful typed ranked-results model.

## Endpoint gaps requiring resolution

Before an implementation PR can truthfully claim fully generated types for
the app's used surfaces, upstream needs to expand the manifest and ranked
results response schemas to the fields its controllers actually return. The
implementation must pin a fetched OpenAPI artifact (for reproducible code
generation), rather than relying on the mutable runtime URL alone.

## Red-phase tests

`iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift` now uses local
`MockURLProtocol` stubs only. The upload tests expect the published 200 JSON
acknowledgements to be surfaced, and the manifest test uses the smallest JSON
object valid under the published schema. They fail against the current
hand-written client: upload calls discard successful bodies and manifest
decoding requires fields the published schema omits. These are intentional
assertion/behavior failures, not test infrastructure failures.
