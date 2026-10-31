# Issue #5: generated OpenAPI client test plan and PR notes

## Acceptance criteria and verification

| Criterion | Smallest credible verification | Current status |
| --- | --- | --- |
| The package includes `swift-openapi-generator` and `swift-openapi-runtime`, and vendors or fetches the published document | `APIClientTests.testPackageDeclaresSwiftOpenAPIGeneratorAndRuntime` verifies the package declaration. The implementation PR must additionally review the tracked spec source and generator plugin configuration. | Red: neither dependency is currently declared. |
| Generated client covers manifest, recent sheets, capture creation, measurement upload, judgment upload, and ranked results | Permanent `URLProtocol` tests in `APIClientTests` stub each generated operation's server response/request. This run adds manifest and recent-sheet read coverage; the existing tests cover capture creation and both uploads. Add ranked-results coverage when the generated operation replaces the missing handwritten endpoint. | Blocked on implementation; ranked results has no current iOS method. |
| Handwritten API types are replaced, while client-only measurement/camera types remain | Inspectable implementation diff plus compilation of `swift test --disable-sandbox`. | Not run: implementation phase. |
| Generated client is exercised without a live server in CI | Permanent `URLProtocol` tests in `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift`. | Partially passing for current client; generated-client wiring is blocked on implementation. |
| PR records prose-contract deltas and endpoint gaps | This document's following section, updated against the published server implementation/spec. | Recorded below; final PR description should carry the same notes. |

## Contract deltas and endpoint gaps

The server-side dependency, `viamin/color_matching#110`, is closed and its router exposes `GET /api/v1/openapi.json`. The specification is published dynamically from `ColorMatchingWeb.ApiSpec`; this repository does not yet vendor or fetch it.

The current server implementation differs from the hand-written prose contract in material ways:

- The prose `printer_profile` example exposes `id`, `name`, `paper`, `ink`, and `settings`. The server renderer exposes `printer_make_model`, `paper_type`, `ink_type`, `icc_profile`, `print_settings`, driver metadata, calibration metadata, and notes.
- The prose leaves ranked-results as a narrative promise. The server now returns `lps-ranked-results/v1` with aggregate score, observation, capture-provenance, source-color, and ranking fields. The iOS handwritten client has no ranked-results operation at all.
- The prose omits successful upload response bodies. The server returns `capture_id` plus measurement/pair-score counts or judgment count for the two upload endpoints; the handwritten client currently discards them.
- The server requires bearer authentication in its `/api/v1` API pipeline. The prose's development-mode unauthenticated allowance is not part of the machine-readable API surface.

## Implementation handoff

Vendor the response from `/api/v1/openapi.json` with a pinned provenance/retrieval command, configure the Swift OpenAPI generator plugin and runtime, and replace API wire models with generated operation input/output types. Preserve `MeasurementCore` geometry, camera metadata acquisition, and scoring-domain models where they are client-only. Extend the local `URLProtocol` suite with a ranked-results fixture and assertions against the generated operation, then run `swift test --disable-sandbox`.
