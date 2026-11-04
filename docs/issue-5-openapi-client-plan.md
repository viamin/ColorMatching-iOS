# Issue #5: Generated OpenAPI Swift client

## Acceptance-criterion verification plan

| Criterion | Smallest credible verification | Status in this tests-only PR |
| --- | --- | --- |
| Add the OpenAPI generator/runtime and vendor or fetch the published document | `APIClientTests.testPackageDeclaresOpenAPIGeneratorAndRuntime` and `APIClientTests.testVendoredOpenAPIDocumentCoversEveryIOSClientOperation` inspect the package manifest and vendored document. | Red: neither artifact exists yet. |
| Generate the client for manifest, recent sheets, capture creation, measurement upload, judgment upload, and ranked results | The vendored-document test requires all six paths. The existing local-stub tests exercise capture creation, measurement upload, and judgment upload; the new local-stub tests exercise manifest and recent-sheets decoding. Add a ranked-results stub test when the generated operation is wired into the app core. | Partial red: the current API core has no ranked-results operation. |
| Replace hand-written server API models while retaining client-only models | Implementation review must inspect the generated target and the adapter boundary. This is a structural/human criterion; the generated target must compile in `swift test --disable-sandbox`. | Not run in the tests-only phase. |
| Exercise generated client against local stubs, with no live server in CI | Permanent `ColorMatchingLPSAppTests/APIClientTests.swift` uses `MockURLProtocol`; no test makes a network request. The implementation run must retain these tests while routing through generated operations. | The five existing operation tests remain executable once Swift is available; ranked-results coverage is pending its generated operation. |
| Record contract deltas and endpoint gaps in the PR description | Human/external evidence: compare `docs/color-matching-api-contract.md` with `viamin/color_matching#113` / the served `/api/v1/openapi.json` at implementation time. | Documented below; requires PR-description confirmation. |

## Contract deltas found before implementation

- The upstream spec is served dynamically at `GET /api/v1/openapi.json`; it is not committed as a static file. The iOS package should vendor a fetched snapshot at `iOS/openapi/color_matching.openapi.json` and make regeneration explicit.
- The prose contract's manifest example shows `printer_profile.id`, `name`, `paper`, `ink`, and `settings`. The actual server renderer returns `printer_make_model`, `paper_type`, `ink_type`, plus optional driver/calibration fields, and no `id`.
- The prose contract describes ranked results informally. The actual renderer returns a full aggregate result shape, but the published `RankedResults` OpenAPI schema currently requires only `schema_version` and `sheet_id`. This is an endpoint-schema gap: the richer result fields need to be specified before a generated ranked-results model can be relied on.
- Capture request compatibility is broader than the prose contract: the upstream spec accepts both the nested `metadata`/`quality` payload and a legacy flattened payload.
- Pair-score upload compatibility is broader than the prose contract: the upstream spec permits `score`, `similarity`, or `distance` for each score.

## Evidence sources

- Upstream implementation: `viamin/color_matching` PR [#113](https://github.com/viamin/color_matching/pull/113), merged 2026-10-30.
- Current prose contract: `docs/color-matching-api-contract.md`.
- Local stubbed client tests: `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift`.
