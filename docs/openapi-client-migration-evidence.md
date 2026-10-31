# OpenAPI client migration evidence

## Acceptance-criterion verification plan

| Criterion | Smallest credible verification | Status in this tests-only PR |
| --- | --- | --- |
| Swift OpenAPI generator/runtime and a vendored API document are configured | `OpenAPIClientGenerationTests.testPackageDeclaresTheOpenAPIGeneratorAndRuntime` and `testVendoredOpenAPIDocumentContainsEveryConsumedOperation` | Red: neither dependency nor document exists yet. |
| Generated client covers manifest, recent sheets, capture creation, measurement upload, judgment upload, and ranked results | Local `URLProtocol` stubs in `APIClientTests`; the future implementation must route the app facade through generated operations. `testGeneratedClientExposesRankedResultsOperation` prevents omitting the currently absent ranked-results call. | Manifest/recent stubs are green against the current facade; ranked results is red. Capture/measurement/judgment stubs already exist and remain permanent regression coverage. |
| Hand-written API models are replaced while client-only measurement models remain | Compile the app and run `swift test --disable-sandbox` after the generated types replace transport models. Inspect the generated-source diff and `MeasurementCore` public models. | Not runnable: Swift is not installed in this environment. |
| PR records prose-contract deltas and endpoint gaps | This section is the inspectable source for the implementation PR description. | Complete evidence; requires human review of the final PR body. |

## Published contract deltas

The upstream API is served from `GET /api/v1/openapi.json` by `viamin/color_matching` issue [#110](https://github.com/viamin/color_matching/issues/110). Its source declares all six iOS-consumed paths, including ranked results.

- The prose document leaves ranked-results response fields unspecified. The API publishes `lps-ranked-results/v1`, `sheet_id`, printer profile, capture time/count metadata, scoring algorithm versions, and per-pair ranking, score, source-color, and judgment provenance.
- Measurement and judgment uploads return `200` JSON acknowledgment bodies (`capture_id` plus counts), not the prose contract's implied empty `204` response.
- The API's capture request uses a compatibility `oneOf` shape, and its OpenAPI validation constrains positive exposure, ISO, and image dimensions. These constraints are absent from the prose contract.
- The published schema currently describes RGB request components as integer channels even though the prose document describes normalized decimal channels. This must be resolved with the server owners before treating generated request types as a drop-in replacement.
- The manifest schema presently requires only its compatibility version, sheet id, and scoring-algorithm field, while the response renderer supplies the richer manifest described in prose. Generated models may therefore expose optional fields that the existing hand-written `SheetManifest` treats as required.
- The API uses stringified integer capture IDs. The prose contract's example is an opaque `capture_123` identifier.

## Endpoint gaps discovered

- No endpoint is missing from the published API: all six app surfaces are declared.
- The current iOS app has no ranked-results request at all, despite the prose contract listing that endpoint. The red `testGeneratedClientExposesRankedResultsOperation` is the implementation trigger.
- The upstream spec is runtime-served rather than checked into its repository as a static JSON artifact. The iOS PR should vendor a reviewed snapshot and document the exact upstream revision or content hash used for regeneration.
