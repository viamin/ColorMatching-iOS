# OpenAPI client migration evidence (issue #5)

## Acceptance-criterion plan

| Criterion | Smallest credible verification | Status in this tests-only run |
| --- | --- | --- |
| Generator, runtime, and source OpenAPI document are present | `OpenAPIClientConfigurationTests` inspects the package declaration and vendored specification for all six operations | Red: implementation pending |
| Generated client covers manifest, recent sheets, capture creation, measurement upload, judgment upload, and ranked results | Permanent local-stub client tests instantiate generated operation inputs and decode generated outputs | Blocked until the dependency supplies a published specification and the implementation run wires generated types |
| Hand-written API models are replaced | Compilation plus a source review that confirms server transport models come from the generated module while `MeasurementCore` stays client-side | Not run: implementation pending |
| No live server is used in CI | Local `URLProtocol` stubs cover existing manifest/recent-sheet/capture/measurement/judgment traffic; generated-client stubs will replace their hand-written-type calls | Partially covered in this run |
| Prose-contract deltas and endpoint gaps are recorded | Compare the vendored upstream document revision against `docs/color-matching-api-contract.md` and inspect the generated diff | Blocked: viamin/color_matching#110 document could not be fetched from the declared upstream location |

## Contract comparison status

No published OpenAPI artifact from `viamin/color_matching#110` was available in this checkout or at the expected public raw-document location on 2026-11-02. Consequently, there is no defensible prose-to-spec delta to claim yet.

The local prose contract itself identifies a gap that must be resolved when the upstream document arrives: `GET /api/v1/test_sheets/:sheet_id/ranked_results` describes desired result content but supplies no concrete response schema. The app does not currently call that endpoint, while issue #5 requires it to be generated and tested. The implementation PR must record whether the published schema provides it; otherwise it remains an upstream endpoint gap.

## Local-stub coverage added now

`APIClientTests` now exercises the manifest and recent-sheet GET responses through `MockURLProtocol`, alongside the existing capture and upload stubs. These are permanent boundary tests and do not use a live server.
