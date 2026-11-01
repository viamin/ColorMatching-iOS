# OpenAPI client contract deltas

This is evidence for the implementation PR for issue #5. It compares
`docs/color-matching-api-contract.md` with the OpenAPI definitions merged in
[`viamin/color_matching#113`](https://github.com/viamin/color_matching/pull/113)
(merge commit `05062f5381a6f76413cc2bdf1cb2cc08a1b70ff7`). The implementation
must repeat this comparison against the pinned, vendored `/api/v1/openapi.json`
before the PR is opened.

## Observed deltas

- `POST /captures/{capture_id}/measurements` and
  `POST /captures/{capture_id}/judgments` are specified as `200` JSON responses
  with capture and count fields. The prose contract and current app treat them
  as bodyless `204` responses.
- Capture creation accepts the nested `metadata`/`quality` body used by the app,
  but also supports a legacy flat request shape. The generator will represent
  this `anyOf`; the app should keep its single nested request construction.
- The published measurement schema requires a normalized median for each
  measurement, but does not declare the prose contract's root
  `scoring_algorithm_version` or per-measurement `stats` fields. Confirm the
  generated request type and server validation before retaining those fields.
- The published manifest schema only requires `schema_version`, `sheet_id`, and
  `capture_profile.scoring_algorithm_version`; it does not describe the page,
  markers, patches, or pairs that `MeasurementCore` consumes.
- The ranked-results schema only requires `schema_version` and `sheet_id`; the
  prose contract likewise has no concrete response body. This endpoint needs a
  server-side schema expansion before a useful typed ranked-results UI can be
  implemented.

## Endpoint gaps in the iOS app

The app currently calls manifest, recent sheets, capture creation, measurement
upload, and judgment upload. It has no ranked-results client method or UI call
site. The generated-client migration should add the typed operation and local
stub coverage, but must not change capture/scoring behavior.
