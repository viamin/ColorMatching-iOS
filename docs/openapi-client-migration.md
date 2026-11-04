# OpenAPI client migration evidence

This document is the proposed PR description and acceptance-criterion plan for #5.

## Criterion verification plan

| Criterion | Smallest credible verification | Evidence location |
| --- | --- | --- |
| Generator/runtime dependencies and vendored upstream document | Focused Swift configuration regression test | `iOS/Tests/ColorMatchingLPSAppTests/OpenAPIClientMigrationTests.swift` |
| Generated types replace API transport models | Focused Swift source-boundary regression test, then compile with generated target | `iOS/Tests/ColorMatchingLPSAppTests/OpenAPIClientMigrationTests.swift` and `swift test --disable-sandbox` |
| Manifest, recent sheets, create capture, measurements, and judgments operate through local responses | Permanent local-stub XCTest tests | `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift` |
| Ranked results operate through a local response | Add a permanent local-stub XCTest when the generated operation is wired into the app facade | `APIClientTests.swift` (red-phase gap) |
| Contract delta assessment | Inspectable comparison of the upstream API implementation/spec and the prose contract | This document |

## Published-spec comparison

The upstream dependency is complete: `viamin/color_matching#110` is closed and serves its generated OpenAPI 3 document at `GET /api/v1/openapi.json`.

Observed deltas from `docs/color-matching-api-contract.md`:

- Ranked results are a real, specified endpoint returning `lps-ranked-results/v1`, but no iOS API client method currently exposes it. This is the implementation gap the generated client must close.
- The actual manifest includes `created_at`, a detailed printer-profile object, and a capture profile. The current `SheetManifest` silently discards those server fields; generated types must retain them, with adapters only where camera/scoring code needs its existing client-side types.
- The prose printer-profile example uses `id`, `name`, `paper`, `ink`, and `settings`; the server renderer returns `printer_make_model`, `paper_type`, `ink_type`, `icc_profile`, `print_settings`, driver fields, calibration fields, and notes.
- Measurement and judgment uploads return `200` JSON confirmation bodies (capture ID and accepted-row counts), whereas the hand-written client treats every successful response as bodyless.
- Capture IDs are decimal string IDs in the published server implementation, not the illustrative `capture_123` shape in the prose contract.

No new server endpoints are required. The iOS capture/scoring workflow remains unchanged; only its transport contract becomes generated.

## Red-phase status

`OpenAPIClientMigrationTests` is intentionally red until the implementation run adds the generator/runtime package dependencies, vendors the served OpenAPI JSON at `iOS/Sources/ColorMatchingLPSAppCore/openapi.json`, and removes the hand-written transport payload models. The local-stub API tests do not contact a live Phoenix server.
