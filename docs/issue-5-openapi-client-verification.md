# Issue #5: OpenAPI client verification plan

This is the tests-only change for #5. It records the acceptance-criterion
checks that the implementation change must satisfy.

| Criterion | Smallest credible verification | Current state |
| --- | --- | --- |
| The package uses the generated OpenAPI client dependencies | `GeneratedClientConfigurationTests.testPackageDeclaresOpenAPIGeneratorAndRuntime` | Red: dependencies absent |
| Generated operations cover every app surface | `GeneratedClientConfigurationTests.testGeneratedClientIncludesEveryCompanionEndpoint` | Red: no generated source exists |
| Manifest and recent-sheet operations decode provider-shaped local responses | `APIClientTests.testFetchManifestDecodesLocalStubbedResponse` and `APIClientTests.testFetchRecentSheetsDecodesLocalStubbedResponse` | Green against the current hand-written boundary; retain when it delegates to generated types |
| Capture creation, measurement upload, and judgment upload use local stubbed responses | Existing `APIClientTests` request/response tests | Green against the current hand-written boundary; retain/adapt to generated types |
| Ranked results are wired into the generated client | Generated-source endpoint check above, then add a local-stub response assertion when the generated operation name is available | Red |
| Prose contract differences are recorded | This document, based on `viamin/color_matching` `main` at the dependency issue's closure | Inspectable external evidence; needs PR body copy |

## Contract deltas found

The upstream implementation renders a `lps-ranked-results/v1` response with
aggregate capture timestamps/counts, printer profile, algorithm versions, and
per-pair score/judgment provenance. The local prose contract documents only
the ranked-results route and a high-level description, so it provides no
machine-checkable ranked-results response shape.

The prose manifest describes `printer_profile` as `id`, `name`, `paper`,
`ink`, and `settings`. The provider's published schema module models printer
profiles as `id`, `printer_make_model`, `paper_type`, and `ink_type`; the
generator must follow the published document, not the legacy prose names.

The prose says measurement and judgment uploads have no response body. The
provider returns acknowledgement objects containing `capture_id` and counts,
which the generated client should model even if the app currently ignores
them.

The upstream OpenAPI schema currently declares only selected required fields
for manifest and ranked-results objects. This is an endpoint-schema gap: the
generator can type the declared fields, but comprehensive nested manifest and
ranked-results modeling depends on expanding the provider schema.

## PR description text

Copy the table and deltas above into the implementation PR description, adding
the exact vendored OpenAPI document revision and the final `swift test
--disable-sandbox` result. No live provider is used by these tests.
