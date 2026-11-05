# Issue #5 generated OpenAPI client test plan

## Criterion verification map

| Criterion | Smallest credible verification | Current red-phase status |
| --- | --- | --- |
| Package contains `swift-openapi-generator` and `swift-openapi-runtime` | `GeneratedClientAdoptionTests.testPackageUsesSwiftOpenAPIGeneratorAndRuntime` | Failing until implementation adds the dependencies. |
| Generated client covers manifest, recent sheets, capture creation, measurement upload, judgment upload, and ranked results | `GeneratedClientAdoptionTests.testGeneratedClientIncludesEveryCompanionAPIPath` plus local `URLProtocol` stubs in `APIClientTests` | Failing until the spec is vendored/generated and ranked-results is wired. |
| Hand-written transport models are replaced | `GeneratedClientAdoptionTests.testAPIClientDoesNotDeclareTransportModelsOwnedByTheOpenAPISpec` | Failing until generated models replace the declarations. |
| Generated client handles local stubbed API responses | `APIClientTests` uses `MockURLProtocol`, with no live server | Existing covered operations pass; generated-client adoption remains red. |
| Prose-contract deltas are recorded in the PR | Human review of this plan and the implementation PR description | Not automatable; implementation must copy the deltas below into its PR body. |

## Published-spec deltas to include in the implementation PR

The upstream contract is served at `GET /api/v1/openapi.json` by `viamin/color_matching#110`.

- Capture creation accepts the documented nested `metadata` and `quality` form, but the spec also permits legacy flat capture fields. The iOS app should retain the nested form.
- Measurement and judgment uploads return `200` JSON acknowledgement documents with capture and accepted-row counts. The prose contract omitted response bodies and the current client assumes `204`.
- Ranked results are no longer only a prose promise. They are a versioned `lps-ranked-results/v1` response containing sheet-level capture provenance, scoring-algorithm versions, printer-profile fields, and ranked pair observations.
- The implementation emits a detailed printer profile (`printer_make_model`, `paper_type`, `ink_type`, driver/calibration fields), while the old prose manifest showed a different `id`/`name`/`paper`/`ink`/`settings` shape.
- The server-side OpenAPI schema for manifests currently guarantees the schema version, sheet ID, and capture-profile algorithm version; clients should preserve tolerance for the remaining manifest fields until the upstream schema makes them fully structural.
