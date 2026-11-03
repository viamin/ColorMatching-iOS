# OpenAPI client migration: verification plan

This is the tests-only draft for issue #5. The implementation must vendor or
fetch the OpenAPI document served by `viamin/color_matching` issue #110 and
replace the transport DTOs in `ColorMatchingLPSAppCore` with generated types.

## Criterion coverage

| Criterion | Smallest credible verification | Draft status |
| --- | --- | --- |
| Package contains the generator/runtime and a pinned OpenAPI document | Inspect `iOS/Package.swift`, generator configuration, and vendored/fetched document revision | Not implemented in this phase |
| Generated client exposes manifest, recent sheets, capture, measurement, judgment, and ranked-results operations | Compile a test target importing the generated module and calling each operation | Not implemented in this phase |
| App no longer owns API DTOs | Inspect the production target: generated types own API payloads; MeasurementCore-only analysis models remain | Not implemented in this phase |
| Local stub behavior | `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift` uses `MockURLProtocol`, never a live server | Manifest/recent-sheet baselines added; generated-client conversion remains |
| Contract deltas and endpoint gaps are recorded | This document and the implementation PR description cite the exact upstream OpenAPI document revision | Blocked on the published document being vendored/fetched |

## Contract comparison baseline

The prose contract names six `/api/v1` surfaces: manifest, recent sheets,
capture creation, measurement upload, judgment upload, and ranked results.
Its ranked-results section deliberately gives no response schema. Until the
published OpenAPI document is committed or fetched by the implementation, a
typed response assertion for ranked results would invent a contract and is not
credible. The implementation PR must record the actual ranked-results schema
and any other field, requiredness, enum, or status-code delta against
`docs/color-matching-api-contract.md`.

Upstream issue #110 additionally describes two non-`/api/v1` write routes.
They are outside this app issue's requested generated-client surface unless
the imported OpenAPI document shows an app call site that needs them.
