---
module: ColorMatchingLPSAppCore
tags: [api-client, openapi, swift-openapi-generator, migration]
problem_type: external-dependency-blocked
---

# OpenAPI Client Migration — Status Notes (issue #5)

Tracks progress on "Replace hand-written API layer with a generated OpenAPI
Swift client." This run is a **test-writing (red) phase**: it adds failing
tests that pin the missing deliverables and a regression baseline for the
current hand-written client, but makes no implementation changes.

## Blocked dependency

Issue #5 depends on `viamin/color_matching#110` publishing a machine-readable
OpenAPI document. In this environment the GitHub API proxy only reaches this
repo (`viamin/ColorMatching-iOS`):

```
$ curl "$GITHUB_API_URL/repos/viamin/color_matching/pulls/110" ...
{"error":"Repository mismatch"}
```

So the spec could not be fetched or vendored from here, and the following
deliverables cannot be implemented yet:

- Add `swift-openapi-generator` + `swift-openapi-runtime` to `iOS/Package.swift`.
- Fetch/vendor the OpenAPI document.
- Generate and wire in the typed client; replace hand-written models.

The implementation run should re-check `viamin/color_matching#110` for the
published spec before starting.

## What this run added instead

- `iOS/Tests/ColorMatchingLPSAppTests/OpenAPIMigrationReadinessTests.swift` —
  three failing assertions, one per blocked deliverable above, written
  against plain file/text checks (not generated types) so they compile and
  run without the generator or spec present:
  - `Package.swift` must name `swift-openapi-generator` and
    `swift-openapi-runtime`.
  - An OpenAPI document must be vendored somewhere under `iOS/`.
  - `APIClient.swift` must cover the `ranked_results` surface (see gap
    below).
  These should go green, unmodified in intent, once the implementation run
  lands the migration — if any of them need to change shape, that is itself
  a signal the migration took a different path than planned here.
- `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift` — added
  characterization tests for `fetchManifest` and `fetchRecentSheets` (the
  two existing endpoints that had no test coverage), stubbed from the exact
  JSON shapes in `docs/color-matching-api-contract.md`. These pass today
  against the hand-written client and act as the regression baseline the
  generated client must continue to satisfy once swapped in.

## Endpoint gap discovered without the spec

Comparing `docs/color-matching-api-contract.md` against
`iOS/Sources/ColorMatchingLPSAppCore/APIClient.swift` (independent of
whether the published spec matches the prose doc):

- **Ranked results is documented but never implemented.** The contract
  describes `GET /api/v1/test_sheets/:sheet_id/ranked_results`, but
  `APIClient` has no method for it — ranked pairs shown in `ContentView`
  are computed locally from `MeasurementCore` scoring, never fetched from
  the server. The generated client must add this surface; it is not a
  translation of existing code.
- **`SheetManifest` silently drops documented fields.** The contract's
  manifest sample includes `created_at`, `printer_profile`, and
  `capture_profile`, none of which `MeasurementCore.SheetManifest` models.
  `JSONDecoder` ignores unknown keys, so this has not caused a visible
  failure, but generated types will surface these fields — the
  implementation run should decide whether the app needs them or should
  keep them client-ignored.

A full delta against the *real, published* spec cannot be produced until
`viamin/color_matching#110` is reachable; the two gaps above are everything
discoverable from the prose contract and current source alone.

## Environment constraint

No Swift toolchain is installed in this sandbox (`swift` not on `PATH`), so
`swift test` could not be run here to confirm these tests build and fail as
described. The implementation run (or CI) should run
`swift test --disable-sandbox` and confirm:
- `OpenAPIMigrationReadinessTests` fails on all three assertions before the
  migration, and passes after.
- `APIClientTests` (including the two new characterization tests) passes
  both before and after.
