# OpenAPI Client Migration PR Notes

## Acceptance-criterion verification plan

| Criterion | Smallest credible verification | Status in tests-only phase |
| --- | --- | --- |
| Generated client is built from the provider document and covers manifest, recent sheets, capture creation, measurement upload, judgment upload, and ranked results | `swift test --disable-sandbox` compiles the generated target and runs a local-URLProtocol stub test for every operation | Pending implementation |
| The app uses generated API models while client-only measurement models remain local | Compile the app target and assert the adapter maps generated request/response values at its public boundary | Pending implementation |
| No live API is required in CI | `APIClientTests` stubs `URLSession` with `MockURLProtocol`; inspect every operation's URL, authorization, payload, and response decoding | Partially covered; ranked-results adapter is pending |
| The migration tracks the provider contract rather than prose | Vendor/fetch `GET /api/v1/openapi.json` from `viamin/color_matching` and review the generated-source diff | External evidence required during implementation |

The recurring user flow is: discover a sheet, load its manifest, create one
capture, upload its measurements and labels, then view ranked results. It needs
a permanent Swift integration test with local stubs because it is the boundary
most likely to drift. The existing focused unit tests cover the two upload
encoders. The generated-client implementation must add the missing ranked
results stub before this PR can claim the flow passes.

## Contract deltas found

The provider's closed issue
[`viamin/color_matching#110`](https://github.com/viamin/color_matching/issues/110)
publishes `GET /api/v1/openapi.json` and lists all six required routes. Its
controller schemas and response renderer differ from the prose contract in
these material ways:

- Measurement and judgment uploads return `200` JSON acknowledgements with
  `capture_id` and accepted counts. The prose contract omits a response, and
  the pre-migration tests used `204`.
- Ranked results are now a concrete `lps-ranked-results/v1` response with
  sheet/capture provenance, printer profile, algorithm versions, observations,
  and score aggregates. The prose contract only describes this endpoint.
- Capture creation supports the prose's nested `metadata`/`quality` request,
  but the published schema also supports a legacy flat capture shape. The
  generated client should deliberately use the nested shape.
- The published measurement schema requires each pair score to carry its own
  `algorithm_version`; the prose also sends a top-level
  `scoring_algorithm_version`, which is not required by that schema. The
  migration should preserve required per-score versioning and only retain the
  top-level field if the generated operation accepts it.
- The prose's manifest printer-profile example (`id`, `name`, `paper`, `ink`,
  `settings`) does not match the provider renderer
  (`printer_make_model`, `paper_type`, `ink_type`, plus optional calibration
  metadata). The app currently does not consume this nested object.

## Endpoint gaps

None in the provider route list: manifest, recent sheets, capture creation,
measurement upload, judgment upload, and ranked results are all present.
The current iOS hand-written `APIClient` lacks a ranked-results call, so the
implementation must add a generated-client adapter for it without changing
capture or scoring behavior.
