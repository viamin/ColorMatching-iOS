# OpenAPI client migration verification plan

This plan records the smallest credible verification for issue #5 before its
implementation begins. The permanent Swift API-client tests use `URLProtocol`
stubs, so they do not require a live Phoenix server or a database.

| Criterion | Verification | Location | Current test-writing status |
| --- | --- | --- | --- |
| Add and wire `swift-openapi-generator` and `swift-openapi-runtime` | Focused package/configuration review plus a clean `swift test --disable-sandbox` after generated sources are checked in | `iOS/Package.swift`, generated-client configuration | Not yet implemented |
| Vendor/fetch the published `/api/v1/openapi.json` document | Inspect the committed artifact and its regeneration command against the upstream endpoint | OpenAPI artifact and generation script | Not yet implemented |
| Typed manifest and recent-sheet reads | Permanent local-stub API test | `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift` | Covered |
| Typed capture creation, measurement upload, and judgment upload | Permanent local-stub API tests | `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift` | Covered |
| Typed ranked-results read | Permanent local-stub API test added with the generated endpoint facade | `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift` | Blocked: the current app has no ranked-results client call |
| Replace server DTOs while retaining client-only models | Source review and compile check after migration | `iOS/Sources/ColorMatchingLPSAppCore`, `iOS/Sources/MeasurementCore` | Not yet implemented |
| Describe prose-contract deltas and endpoint gaps in the PR | Human inspection of the PR description, using the findings below | PR description | Requires PR authoring |

## Upstream contract comparison (2026-11-05)

The upstream `viamin/color_matching` `main` branch, which closes issue #110,
serves its spec at `GET /api/v1/openapi.json`. Its source defines all six
routes needed here: manifest, recent sheets, capture creation, measurement
upload, judgment upload, and ranked results.

The published spec is currently too shallow to generate lossless DTOs for this
app:

- `Manifest` requires only `schema_version`, `sheet_id`, and
  `capture_profile.scoring_algorithm_version`; the app needs page geometry,
  markers, patches, and pairs to analyze a sheet.
- `RankedResults` requires only `schema_version` and `sheet_id`, while the
  runtime JSON also contains printer profile, capture provenance, scores,
  source colors, and user-judgment data.
- `MeasurementUploadRequest` omits `scoring_algorithm_version` and measurement
  `stats`, both sent by the current app. Its response is JSON `200` with
  counts, whereas the prose contract did not define a response and the current
  client accepts an empty `204`.
- Capture creation accepts both the documented nested `metadata` form and a
  legacy flat form. The generated facade should use the nested form.

The implementation PR should either obtain a corrected upstream spec before
generation or document an intentionally maintained compatibility overlay. A
generated client from the current shallow schemas would silently discard fields
that the app needs, defeating the purpose of the migration.
