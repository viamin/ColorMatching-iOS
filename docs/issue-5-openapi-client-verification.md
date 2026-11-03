# Issue #5 OpenAPI client: verification plan and contract deltas

This document is the test-phase evidence and proposed PR description material for
replacing the hand-written `/api/v1` client. The provider's published contract is
the OpenAPI document served by `viamin/color_matching` at
`GET /api/v1/openapi.json` (issue [viamin/color_matching#110](https://github.com/viamin/color_matching/issues/110)).

## Acceptance-criterion verification plan

| Criterion | Smallest credible verification | Evidence at this phase |
| --- | --- | --- |
| Add `swift-openapi-generator` and runtime; vendor or fetch the spec | Inspect `iOS/Package.swift`, generator configuration, and vendored/fetched spec revision. | Human/external evidence after implementation; tests cannot establish dependency provenance. |
| Generate the manifest, recent sheets, capture, uploads, and ranked-results surfaces | Permanent stubbed-client tests invoke every operation and assert method, path, authorization, request payload, and response decoding where applicable. | `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift`; ranked-results test is intentionally red until that generated operation is wired in. |
| Replace hand-written API models while preserving client-only models | Inspect the generated module and confirm network DTOs are generated types; compile the app and tests. | Human/code-review evidence after implementation. |
| Swift tests use local stubs, not a live server | `MockURLProtocol` supplies each response and rejects no network dependency. | Permanent unit/service tests in `APIClientTests.swift`. |
| Record prose-contract deltas and endpoint gaps | This section is reviewed against the provider's published OpenAPI document at the pinned revision used by the implementation. | Human/external evidence after spec vendoring. |
| `swift test --disable-sandbox` is green | Run that exact command after generated dependencies are added. | Not runnable in this container: the Swift toolchain is absent. |

## Deltas between the prose contract and provider implementation/spec

- The prose contract describes measurement and judgment uploads as empty responses
  (and the current client accepts a `204`). The provider returns `200` JSON
  acknowledgement bodies with `capture_id` plus counts.
- The prose contract left ranked-results shape unspecified. The provider exposes a
  concrete `lps-ranked-results/v1` document with aggregate score statistics,
  observation provenance, timestamps, printer profile, and algorithm versions.
- The prose example gives the printer profile `id`, `name`, `paper`, `ink`, and
  `settings`. The provider shape exposes printer metadata such as
  `printer_make_model`, `paper_type`, `ink_type`, `icc_profile`, print settings,
  driver/calibration metadata, and notes instead.
- The provider's capture IDs are decimal strings derived from persisted integer
  IDs; the prose contract uses opaque example IDs such as `capture_123`.
- The published OpenAPI schemas themselves are currently less complete than the
  provider response renderers: `Manifest` declares only `schema_version`,
  `sheet_id`, and the capture-profile algorithm version, while `RankedResults`
  declares only `schema_version` and `sheet_id`. This is insufficient to
  generate strongly typed models for the fields the app needs.
- The published measurement-upload schema requires
  `normalized_linear_rgb_median` but does not describe the current client’s
  `scoring_algorithm_version` or measurement `stats` payload. It also models
  the RGB payload as several compatibility shapes rather than one canonical
  object.

## Endpoint gaps discovered

The app has no ranked-results client operation today despite the prose contract
listing `GET /api/v1/test_sheets/:sheet_id/ranked_results`. The new permanent
stubbed test is deliberately red until the generated client exposes and wires
that operation. The provider declares all six app-used routes, but the partial
manifest, ranked-results, and measurement-upload schemas above block a fully
typed generated implementation until upstream expands them (or the iOS client
vendors an approved augmented specification).
