# Issue #5 OpenAPI client verification plan

This is the criterion-level plan for replacing the hand-written iOS API layer. It is deliberately recorded before implementation so the generated-client migration has focused, inspectable coverage rather than relying on a broad green test suite.

## Acceptance criteria and verification

| Criterion | Smallest credible verification | Current evidence / expected implementation evidence |
| --- | --- | --- |
| Add `swift-openapi-generator` and `swift-openapi-runtime`, and vendor or fetch the source document | Human/externally inspectable package and vendored/fetched document at the PR head | Pending implementation. The provider serves the document at `GET /api/v1/openapi.json`; route evidence is [ColorMatchingWeb.Router](https://github.com/viamin/color_matching/blob/main/lib/color_matching_web/router.ex). |
| Generate each app-used surface: manifest, recent sheets, create capture, upload measurements, upload judgments, ranked results | Focused permanent Swift tests using a local `URLProtocol` stub, one request/response test per operation | Existing flow tests: `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift`. This test-writing PR adds the manifest and recent-sheet stub tests; implementation must migrate all six tests to generated operations and add ranked-results coverage. |
| Replace server API models with generated types while retaining client-only models | Compile-time evidence: the app target builds against generated operation/component types, plus review of the deleted server-model declarations | Pending implementation; this is not a behavior a test can establish by itself. |
| No live server in CI | Permanent local-stub tests | `APIClientTests` configures `URLSession` with `MockURLProtocol`; no test makes a network call. |
| Record prose-contract deltas and endpoint gaps | Human/external evidence from the published provider source and OpenAPI endpoint | Recorded below. |
| `swift test --disable-sandbox` is green once generated types are wired in | Targeted test command | Pending implementation because this test-only PR cannot alter `Package.swift` or production targets. |

## Provider-contract deltas found before implementation

Provider issue [viamin/color_matching#110](https://github.com/viamin/color_matching/issues/110) is closed. Its router declares the six required paths and `GET /api/v1/openapi.json` ([router source](https://github.com/viamin/color_matching/blob/main/lib/color_matching_web/router.ex)). The generated document must be fetched from that endpoint (or a checked-in snapshot of it), not recreated from this prose contract.

The provider's published schema modules reveal these deltas from `docs/color-matching-api-contract.md`:

- The manifest schema requires only `schema_version`, `sheet_id`, and `capture_profile.scoring_algorithm_version`; the prose contract requires a complete page, marker, printer-profile, patch, and pair manifest. The generator will therefore not produce the rich manifest model the current analyzer consumes without a provider-spec expansion.
- The prose says ranked results include colors, scores, labels, capture provenance, printer profile, and scoring version. The published `RankedResults` schema requires only `schema_version` and `sheet_id`, so it cannot type the useful ranked-result payload yet.
- Capture creation accepts either the nested prose payload or a legacy flat payload. In the nested form, the schema does not require individual quality fields; the spec also calls the flat duration field `exposure_duration`, whereas the prose calls it `exposure_duration_seconds`.
- The prose requires a top-level `scoring_algorithm_version` and per-measurement stats for measurement uploads. The published schema instead requires normalized RGB values, does not require those stats or the top-level version, and permits score, similarity, or distance in each pair score.
- The prose specifies empty `204` responses for measurement and judgment uploads. The provider schema/controller specify `200` JSON acceptance responses containing the capture ID and submitted counts.
- The prose describes optional development authentication; the published operations declare bearer authentication.

These gaps are provider-spec gaps, not justification for preserving hand-written server models. The implementation PR should vendor the exact served document, generate the operations it can type, and either block on or explicitly adapt only after the provider closes the manifest/ranked-result schema gaps.

## PR description handoff

Use the preceding delta list in the implementation PR description. State whether the provider has expanded the manifest and ranked-result schemas since this plan was written; if not, the issue cannot meet the generated typed-client exit criterion for those two app flows without an explicit dependency update.
