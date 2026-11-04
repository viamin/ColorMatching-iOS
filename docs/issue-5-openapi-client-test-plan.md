# Issue #5 OpenAPI client test plan

This test-writing change establishes the smallest credible verification for each
acceptance criterion before the generated-client implementation begins.

| Criterion | Verification | Current result |
| --- | --- | --- |
| Generated client decodes used read surfaces without a live server | Permanent `URLProtocol` unit tests for manifest and recent-sheets responses from the published OpenAPI contract | Manifest test is red: the hand-written `SheetManifest` requires fields not guaranteed by the spec. Recent-sheets test is green. |
| Generated client preserves used write surfaces | Extend the existing permanent `URLProtocol` tests for capture creation, measurement upload, and judgment upload to construct generated operation inputs and assert operation paths, authentication, JSON bodies, and documented responses | Deferred to implementation because generated operation/type names do not exist yet. |
| Generated client covers ranked results | Add a permanent `URLProtocol` test for the published ranked-results response and its generated operation | Blocked by an upstream specification gap: `RankedResults` declares only `schema_version` and `sheet_id`, while the app needs actual ranked entries to display results. |
| Package dependencies and generated source are wired in | `swift test --disable-sandbox` compilation plus focused API-client test execution | Not run: the container has no `swift` executable. |
| Contract deltas are captured | Inspectable comparison against `viamin/color_matching` PR #113 (which closed #110) and this repository's prose contract | Recorded below; implementation PR description must carry these findings. |

## Published-contract deltas and endpoint gaps

- The prose manifest contains page geometry, registration markers, printer and
  capture profiles, patches, and pairs. The published `TestSheetManifest`
  schema requires only `schema_version`, `sheet_id`, and
  `capture_profile.scoring_algorithm_version`. The app cannot retain capture
  behavior from generated manifest types alone unless the server spec is
  expanded or a deliberately separate compatible payload is specified.
- The prose contract's ranked-results endpoint says the response should include
  colors, scores, labels, provenance, printer profile, and algorithm version.
  The published `RankedResults` schema requires only `schema_version` and
  `sheet_id`; it has no ranked-entry schema.
- The published capture request permits either the prose nested `metadata`
  payload or legacy top-level fields. Its `CaptureMetadata` requires image
  dimensions, whereas the hand-written iOS model makes them optional.
- The published measurement payload accepts RGB arrays, RGB objects, or
  JSON-encoded strings and allows `score`, `similarity`, or `distance` for a
  pair score. The prose contract fixes RGB objects and supplies both similarity
  and distance.
- The published measurement-upload operation returns a JSON count response;
  the hand-written client accepts any successful empty response.

Sources inspected: `docs/color-matching-api-contract.md` and
`viamin/color_matching` PR #113 (merged 2026-10-30; implementation of #110).
