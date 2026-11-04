# Generated OpenAPI Client: Verification Plan

This document is the PR/run evidence plan for issue #5. It is intentionally
written before implementation so the generated-client change has criterion-level
coverage rather than relying on a broad `swift test` result.

| Criterion | Smallest credible verification | Test/evidence |
| --- | --- | --- |
| Generator/runtime dependencies and vendored spec are wired into the package | Swift package resolution and compilation | `iOS/Package.swift`; implementation-run `swift test --disable-sandbox` |
| Generated types serve every API surface currently used by the app | Local URLProtocol stubs exercise manifest, recent sheets, capture creation, measurement upload, judgment upload, and ranked results | `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift` |
| Hand-written transport models are replaced while client-only measurement models remain | Compile-time use of generated operation input/output types plus the same stub suite | Implementation diff and `APIClientTests` |
| Generated client works without a live server in CI | URLProtocol-backed request/response tests run in the package suite | `APIClientTests` |
| Prose-contract deltas are captured in the PR description | Human review of the implementation PR description against the upstream OpenAPI document | External evidence; cannot be proven by a Swift test |

## Contract comparison discovered before implementation

The upstream router and JSON renderer at `viamin/color_matching` establish the
following deltas from `docs/color-matching-api-contract.md`:

- Ranked results are no longer an unspecified future response: they carry the
  `lps-ranked-results/v1` schema version, aggregate counts/timestamps, scoring
  algorithm versions, source-color objects, score summaries, and optional
  judgment observations. The app has no ranked-results request today.
- The prose printer profile (`id`, `name`, `paper`, `ink`, `settings`) differs
  from the rendered profile (`printer_make_model`, `paper_type`, `ink_type`,
  `icc_profile`, `print_settings`, driver/calibration fields, and notes).
- The existing `SheetManifest` client model silently discards `created_at`,
  `printer_profile`, and `capture_profile`; a generated model should expose
  the published shape.
- Measurement and judgment uploads return a `200` acknowledgement containing
  `capture_id` and accepted-count fields. The prose contract does not specify
  a response body, while the current hand-written client discards it.

The upstream repository serves a runtime-generated OpenAPI document at
`GET /api/v1/openapi.json`. During this test-writing run its deployed hostname
was not resolvable and no serialized OpenAPI file was committed on upstream
`main`, so the implementation run must fetch the endpoint or vendor an
upstream-produced artifact before declaring the comparison complete.

## Red-phase status

`testFetchRankedResultsDecodesPublishedResponse` deliberately names the
missing `APIClient.fetchRankedResults` façade. It is the failing acceptance
test that the implementation run must make compile and pass by routing through
the generated client; it must not be removed or replaced with a manually
decoded model.
