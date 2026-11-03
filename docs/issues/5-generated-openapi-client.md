# Issue #5: Generated OpenAPI Swift Client

## Acceptance-criterion verification plan

| Criterion | Smallest credible verification | Status in this tests-only run |
| --- | --- | --- |
| Add `swift-openapi-generator` and `swift-openapi-runtime`, and vendor or fetch the published document | Package resolution and checked-in spec provenance recorded in the PR | Not run: implementation files are disallowed during this test-writing run. |
| Generate the manifest, recent-sheet, capture, measurement, judgment, and ranked-results surfaces | Stubbed `URLProtocol` tests invoke each generated operation with published response fixtures | Partially prepared: manifest, recent-sheet, capture, measurement, and judgment fixtures are in `APIClientTests`; ranked results has no app client operation yet. |
| Replace hand-written API models and retain client-only models | Compile the app against generated types; inspect the removal of server DTOs | Not run: implementation files are disallowed during this test-writing run. |
| Test generated client against local stubs | Permanent `URLProtocol` tests, with no live server dependency | Red: the legacy no-content measurement response is still accepted. |
| Record prose-contract deltas and endpoint gaps in the PR | This evidence plus the PR description, based on the published server source and served-spec route | Complete as inspectable source evidence; PR-body copy remains for the implementation/PR run. |

## Published-spec source

`viamin/color_matching` closed issue [#110](https://github.com/viamin/color_matching/issues/110) via [PR #113](https://github.com/viamin/color_matching/pull/113). It serves the OpenAPI document at `GET /api/v1/openapi.json`; the route is public while the application operations use bearer authentication.

The implementation run should fetch that endpoint from the configured server (or vendor a versioned snapshot with its source URL and revision), feed it to `swift-openapi-generator`, and commit generated sources only if the package's chosen generation workflow requires them.

## Deltas from `color-matching-api-contract.md`

- The server's capture request allows either the documented nested `metadata` payload or legacy top-level fields. Its capture metadata requires image width and height, unlike the prose contract's optional fields.
- The measurement request has no required top-level `scoring_algorithm_version`; pair scores require `pair_id`, `algorithm_version`, and one of `score`, `similarity`, or `distance`. Measurement RGB values accept an array, object, or JSON string, and the published shape does not include the prose contract's `stats` object.
- Measurement upload is `200` with `{capture_id, measurement_count, pair_score_count}`. Judgment upload is `200` with `{capture_id, judgment_count}`. The existing handwritten client treats both as bodyless success and accepts `204`; the red test locks down rejection of that obsolete response.
- The published manifest schema guarantees only `schema_version`, `sheet_id`, and `capture_profile.scoring_algorithm_version`; the prose contract claims many more fields. The current app needs page geometry, markers, patches, and pairs, so the server spec must be expanded before those types can be safely generated as required client inputs.
- The ranked-results operation exists, but its published schema currently guarantees only `schema_version` and `sheet_id`. The prose contract describes scores, labels, capture provenance, printer profile, and algorithm version without defining a response shape. The app has no `fetchRankedResults` call today because it ranks locally; a generated ranked-results operation should be added only once the server schema specifies those fields.

## Endpoint gaps discovered

The issue's requested ranked-results generated surface cannot yet be type-safe: the published schema omits its usable result payload. The manifest schema is also too narrow for the existing capture workflow. These are server-spec gaps, not behavior changes for this app, and should be raised against `viamin/color_matching` before the implementation PR claims full generated coverage.
