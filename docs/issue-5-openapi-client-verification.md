# Issue #5 verification plan and PR description draft

## Criterion-to-verification map

| Criterion | Smallest credible verification | Evidence at implementation PR head |
| --- | --- | --- |
| Generated client dependencies and fetched/vendored spec | Inspect `iOS/Package.swift`, generator configuration, and the pinned OpenAPI artifact against the upstream `GET /api/v1/openapi.json` contract | Human/external evidence: source URL, revision/checksum, and generated diff |
| Generated coverage for manifest, recent sheets, captures, uploads, and ranked results | Local `URLProtocol` stubs call each façade operation and assert its request path, authorization, response decoding, and upload response body | Permanent unit/service tests in `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift` |
| No hand-written API models remain | Inspect the app core target: generated operation/schema types are used at the HTTP boundary; only measurement/camera domain types remain | Human/code-review evidence plus `swift test --disable-sandbox` compilation |
| No live server in CI | The permanent `URLProtocol` stubs above provide all response data and use `example.test`; CI runs the Swift test target without network access | Permanent unit/service tests in `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift` |
| PR contract-delta record | Include the following delta section in the PR description after regenerating from the pinned upstream spec | Human/code-review evidence: PR body |

## Red-phase test scope

The tests use local `URLProtocol` responses. They deliberately require behavior not present
in the existing hand-written layer:

- measurement and judgment uploads decode the OpenAPI 200 response bodies instead of
  discarding them as 204 responses;
- ranked results are fetched from the published route and decoded; and
- recent-sheet discovery remains covered with the published nullable `title` response.

The manifest operation needs an implementation decision before it can be covered by a
generated type: the currently published schema only declares `schema_version`, `sheet_id`,
and `capture_profile.scoring_algorithm_version`, whereas the app needs page geometry,
registration markers, patches, pairs, and `manifest_url` to analyze a sheet.

## Contract deltas for the PR description

Compared with `docs/color-matching-api-contract.md`, the upstream OpenAPI schema published
by `viamin/color_matching#110` has these relevant differences:

- `POST /captures/{capture_id}/measurements` and `POST /captures/{capture_id}/judgments`
  return documented 200 JSON response bodies (`capture_id` plus accepted counts). The prose
  omits those bodies and the existing client assumes an empty 204 response.
- `MeasurementUploadRequest` does not declare the prose contract's top-level
  `scoring_algorithm_version` or per-measurement `stats`. Its pair score accepts one of
  `score`, `similarity`, or `distance`, while requiring `pair_id` and `algorithm_version`.
- The capture request permits both the prose nested `metadata` shape and a legacy flat
  request shape. `CaptureMetadata` makes image dimensions required and specifies numeric
  bounds that the prose contract does not.
- The published manifest schema is incomplete for the actual manifest payload: it omits
  `manifest_url`, page geometry, markers, printer profile, patches, and pairs required by
  this app. A directly generated manifest type cannot replace `MeasurementCore.SheetManifest`
  until the server schema is expanded.
- The published ranked-results schema names only `schema_version` and `sheet_id`; the
  runtime response contains capture provenance, source colors, score aggregates, judgments,
  and result rows. Those fields likewise need to be added to the spec before a directly
  generated typed result can expose them safely.

Endpoint coverage is otherwise present for all requested paths: manifest, recent sheets,
capture creation, measurement upload, judgment upload, and ranked results.
