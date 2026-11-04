# Issue #5: generated OpenAPI client verification plan

This is the test-writing (red) phase for issue #5. The generated client and
vendored OpenAPI document do not yet exist in this repository, so no generated
types can be exercised at this revision.

## Criterion map

| Criterion | Smallest credible verification | Current evidence | Status |
| --- | --- | --- | --- |
| Add `swift-openapi-generator`, `swift-openapi-runtime`, and the published spec | Focused package-wiring test checks both dependencies and the generated client target; the implementation must vendor the spec at a stable repository path. | `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift:testPackageWiresGeneratedOpenAPIClient` | Failed (red phase) |
| Generate all app-used surfaces | Permanent local-stub client tests cover manifest, recent sheets, create capture, measurement upload, judgment upload, and ranked results. | Manifest/recent/capture/measurement/judgment tests exist; ranked-results and generated client are missing. | Failed |
| Replace server API models with generated types while retaining client-only models | Compilation of the app and tests importing the generated module is the credible proof; tests construct generated request/response types only at the API boundary. | No generated module exists. | Not run |
| Test generated client against local stubs | `URLProtocol` stubs assert each operation's path, authorization, JSON request shape, and decoded response without a live server. | `APIClientTests` uses `MockURLProtocol`; it currently exercises the handwritten client only. | Failed |
| Record contract deltas and endpoint gaps in PR description | Inspect the published spec from `viamin/color_matching#110` and compare it with the prose contract; a human confirms the final PR body contains this section. | Deltas below were inspected from the merged provider implementation. | Not run (human/PR evidence) |

## Published-spec comparison

The provider issue is closed by [viamin/color_matching#113](https://github.com/viamin/color_matching/pull/113), merged as [`094bd6d`](https://github.com/viamin/color_matching/commit/094bd6d3443ddacbda7e63354299867eb5bdfa9f). Its spec is served at `GET /api/v1/openapi.json`.

Compared with `docs/color-matching-api-contract.md`:

- The prose manifest has page, markers, patches, pairs, printer profile, and a detailed capture profile. The published `Manifest` schema only requires `schema_version`, `sheet_id`, and `capture_profile.scoring_algorithm_version`; it does not type the remaining documented manifest shape.
- The provider requires `title` to be present (nullable) on recent-sheet entries. The prose says it may be `null`, which is compatible, but the existing Swift `RecentSheet` decoder does not require its presence.
- Capture creation accepts either the prose nested `metadata`/`quality` payload or a legacy flat payload. For nested metadata, the published schema requires `device_model`, `lens`, `image_width`, `image_height`, `app_version`, and `timestamp`; the handwritten Swift model makes several of these optional.
- Measurement uploads in the spec require each measurement's `normalized_linear_rgb_median`, do not declare the prose `stats` object or top-level `scoring_algorithm_version`, and require each pair score to include `algorithm_version` plus one of `score`, `similarity`, or `distance`.
- Measurement and judgment uploads return typed `200` JSON count responses, whereas the handwritten client only validates any 2xx response and the prose does not specify responses.
- Ranked results have a route and a minimal published response schema (`schema_version`, `sheet_id`), but the prose's promised detailed scores, labels, capture provenance, printer profile, and algorithm-version fields are not typed by the published schema. The current iOS client has no ranked-results method.

## Implementation handoff

After the spec is vendored, replace the red package-wiring test with imports of
the generated module and add a ranked-results `MockURLProtocol` response test.
Migrate the existing five local-stub tests to generated operation calls, then
run `swift test --disable-sandbox` from `iOS/`. The final PR description must
carry the comparison above and explicitly call out the manifest and
ranked-results schema gaps.
