# Issue #5 generated OpenAPI client: acceptance evidence plan

This is the tests-only (red) phase for issue #5. No production source or package
manifest changes are included in this change.

| Criterion | Smallest credible verification | Current result |
| --- | --- | --- |
| Generator, runtime, and versioned OpenAPI input are committed | `GeneratedOpenAPIClientAdoptionTests.testPackageDeclaresGeneratorAndRuntimeAndVendorsOpenAPIDocument` checks the package declarations and vendored document path. | Fails until the implementation phase. |
| Generated client covers all six used surfaces | `GeneratedOpenAPIClientAdoptionTests.testVendoredSpecificationDeclaresEveryAppAPIPath` requires the input to declare manifest, recent sheets, capture creation, measurement upload, judgment upload, and ranked results. `testAppCoreImportsGeneratedAPIModule` verifies that app core is wired to the generated module. | Fails until the implementation phase. |
| Existing app behavior sends/accepts the API payloads through local stubs | `APIClientTests` stubs every currently implemented route: manifest, recent sheets, capture creation, measurement upload, and judgment upload. The ranked-results test remains blocked by the absent surface. | Five routes pass now; ranked results is not implemented. |
| Contract deltas are recorded in the PR | Inspect the OpenAPI document from `viamin/color_matching#110` and compare each operation/schema with `docs/color-matching-api-contract.md`; cite the pinned source revision and list endpoint gaps. | External evidence blocked: GitHub's pull-request API returned 404 in this environment on 2026-11-05. |

## Known pre-implementation endpoint gap

The prose contract defines `GET /api/v1/test_sheets/:sheet_id/ranked_results`, but
the current hand-written `APIClient` has no corresponding method or testable
response model. The generated OpenAPI document must define that operation before
the implementation can satisfy the six-surface criterion.

## PR description template for implementation

```
## Contract deltas

- Spec source and revision: <URL and commit SHA>
- Prose-only fields/endpoints removed or renamed: <list>
- Spec-only fields/endpoints adopted: <list>
- Ranked-results operation: <operation ID and response schema>
- Remaining endpoint gaps: <none, or explicit issue links>

## Verification

- `swift test --disable-sandbox`
- Local stub coverage: manifest, recent sheets, create capture, upload measurements,
  upload judgments, ranked results
```
