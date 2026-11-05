---
module: ios-api
tags: [openapi, swift, generated-client, verification]
problem_type: verification-plan
---

# Issue #5 generated OpenAPI client verification

This is the tests-only (red-phase) verification plan for replacing the iOS
hand-written API models with a generated OpenAPI client. The upstream API
dependency is closed: [viamin/color_matching#110](https://github.com/viamin/color_matching/issues/110).

## Criterion map

| Criterion | Smallest credible verification | Current evidence |
| --- | --- | --- |
| Add `swift-openapi-generator` and `swift-openapi-runtime`; vendor/fetch the spec | Inspect `iOS/Package.swift` and the checked-in OpenAPI document; `swift test --disable-sandbox` must compile the generator plugin and generated target | Not run in this tests-only phase; implementation required |
| Generate the manifest, recent-sheets, capture, measurement, judgment, and ranked-results operations | Inspect generated source and compile the app target against it | Not run in this tests-only phase; ranked-results has no current app caller and must still be generated |
| Replace hand-written transport models while retaining client-only models | Review the API facade and generated type mappings; compile the app | Not run in this tests-only phase |
| Exercise the generated client with local stubs | Permanent XCTest stubs assert each app-used request route/payload and decode response shapes | `APIClientTests` already covers capture, measurement, and judgment; this PR adds published manifest and recent-sheet response fixtures. The same tests must pass through the generated client facade after implementation. Ranked-results needs a new client-facing behavior test when its generated operation is wired in. |
| Record contract deltas and endpoint gaps | Human-inspectable PR description backed by the upstream spec/source review | Recorded below; final PR description must carry this section forward |

## Contract deltas observed from the published API

The upstream source behind `GET /api/v1/openapi.json` differs materially from
the prose contract in these places:

- `printer_profile` is now operational metadata (`printer_make_model`,
  `paper_type`, `ink_type`, `icc_profile`, `print_settings`, driver and
  calibration fields) rather than the prose `id`, `name`, `paper`, `ink`, and
  `settings` shape.
- Ranked results have a concrete `lps-ranked-results/v1` payload, including
  ranking, source colors, aggregate score statistics, judgment observation,
  and capture provenance. The prose contract only described it narratively.
- The service's recent-sheets renderer currently emits `title: null`; clients
  must support the nullable field rather than assume a display name.
- The manifest includes `created_at`, `printer_profile`, and `capture_profile`.
  These server-owned fields should be generated rather than duplicated as iOS
  models.

## Endpoint gap

The app currently invokes manifest, recent sheets, capture creation,
measurement upload, and judgment upload. It has no ranked-results caller,
despite that endpoint being in both the prose contract and the published API.
Generation must include it; wiring it into UI behavior remains outside this
issue's non-goals unless explicitly requested.
