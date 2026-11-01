# Issue #5 OpenAPI client verification plan

This is the test-writing evidence for replacing the iOS hand-written `/api/v1`
client with a client generated from `viamin/color_matching`'s published OpenAPI
document. The implementation run must preserve these local-stub scenarios while
changing their types and transport calls to generated ones.

## Criterion map

| Criterion | Smallest credible verification | Current state |
| --- | --- | --- |
| Add `swift-openapi-generator` and `swift-openapi-runtime`, and vendor/fetch the spec | Package-resolution check plus a committed spec source with a reproducible fetch/regeneration command | Not implemented in this tests-only run |
| Generate the six app surfaces | Compile the generated operations; exercise each against `MockURLProtocol` fixtures | Manifest, recent-sheets, capture creation, measurement upload, and judgment upload fixtures are permanent tests. Ranked results is explicitly skipped pending a generated operation and usable upstream schema. |
| Replace hand-written API models | Compile the app target without API DTOs outside generated code and the thin client-side adapters | Not implemented in this tests-only run |
| No-live-server Swift tests | `APIClientTests` injects `URLProtocol` into `URLSession`; no test contacts a network host | Fixtures are ready for the five currently implemented operations; not run because this container lacks Swift/Xcode. |
| PR contract-delta record | Inspect the merged upstream OpenAPI implementation and compare it to `docs/color-matching-api-contract.md` | Recorded below; requires no judgment from a test runner |

## Permanent stub coverage

`iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift` owns the API-boundary
tests. It injects a local `MockURLProtocol`, so the fixtures are both
deterministic and isolated from a live Phoenix server.

- `testFetchManifestDecodesPublishedManifestThroughStubbedTransport`
- `testFetchRecentSheetsDecodesPublishedDiscoveryResponseThroughStubbedTransport`
- `testCreateCaptureEncodesMetadataAndQuality`
- `testUploadMeasurementsEncodesScoresWithAlgorithmVersion`
- `testUploadJudgmentsEncodesPathAndPayload`
- `testFetchRankedResultsFromPublishedEndpoint` is intentionally skipped with
  issue #5 because the current client has no ranked-results operation and the
  published schema cannot generate a useful typed result yet.

The implementation run must unskip the ranked-results case and rewrite all six
tests to instantiate and call generated API types/operations, not manually
maintained DTOs. These are permanent regression tests, not ephemeral tests:
the app's capture/upload flow is recurring user behavior and drift at this
boundary is the defect this issue addresses.

## Published-spec audit for the PR description

Evidence inspected: upstream PR
[`viamin/color_matching#113`](https://github.com/viamin/color_matching/pull/113),
merged 2026-10-30 and closing upstream issue #110; the OpenAPI declarations in
[`ApiSchemas`](https://github.com/viamin/color_matching/blob/main/lib/color_matching_web/api_schemas.ex)
and endpoint operations in
[`TestSheetController`](https://github.com/viamin/color_matching/blob/main/lib/color_matching_web/controllers/test_sheet_controller.ex)
and
[`CaptureController`](https://github.com/viamin/color_matching/blob/main/lib/color_matching_web/controllers/capture_controller.ex).

Contract deltas and gaps to retain in the implementation PR description:

- The prose contract describes full manifest fields (page geometry, markers,
  printer/capture profiles, patches, and pairs). The published `Manifest`
  schema declares only `schema_version`, `sheet_id`, and
  `capture_profile.scoring_algorithm_version`; the remainder is absent from
  the schema. A generated model therefore cannot replace the app's manifest
  DTO without upstream schema expansion.
- The prose contract leaves ranked results as prose only. The published
  `RankedResults` schema declares just `schema_version` and `sheet_id`, while
  the server renderer returns printer profile, capture timestamps/counts,
  algorithm versions, and detailed ranked entries. This blocks a useful typed
  ranked-results operation and is why the corresponding test is skipped.
- The prose contract uses `204 No Content` for measurement and judgment
  uploads. The published API declares and returns `200 OK` JSON summaries
  (`capture_id` plus measurement/pair-score or judgment counts). The stubbed
  tests use those published `200` responses.
- The published capture request accepts both the nested prose shape
  (`metadata` and `quality`) and a legacy flattened shape. Its schema does not
  require the `quality` object; the iOS flow continues to send the nested
  shape.
- The prose contract says RGB payloads are `{r,g,b}` objects with statistics.
  The published upload schema accepts RGB arrays, objects, or JSON strings and
  does not describe the client-sent `stats` or top-level
  `scoring_algorithm_version`. The generated request must use the server
  schema, with any required client-only analytics kept out of generated DTOs.

## Implementation-run acceptance evidence

Do not mark the generated-client criteria passed until the implementation PR
contains all of the following inspectable evidence:

1. A vendored or reproducibly fetched `openapi.json`, pinned to an upstream
   revision, and the generation command used in CI/local development.
2. `swift test --disable-sandbox` output showing all six local-stub cases pass
   without a live server.
3. A compile check showing app call sites use generated operations/types and
   only client-side measurement/scoring models remain hand-written.
4. A resolution decision for the two incomplete upstream schemas above. If
   they remain incomplete, the PR must be blocked on the upstream contract
   rather than claiming generated typed coverage for those surfaces.

