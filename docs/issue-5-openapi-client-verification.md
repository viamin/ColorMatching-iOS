# Issue #5 OpenAPI client verification

## Criterion map

| Criterion | Smallest credible verification | Status in this test-writing PR |
| --- | --- | --- |
| Generator, runtime, and vendored specification are configured | `OpenAPIGenerationContractTests.testPackageDeclaresOpenAPIGeneratorAndRuntime` and `testBundledSpecificationCoversEveryAppAPIEndpoint` inspect the package and checked-in specification. | Red: neither exists yet. |
| Hand-written transport models are removed | `OpenAPIGenerationContractTests.testAPIClientDoesNotDeclareHandWrittenTransportModels` rejects the current API-only Codable declarations. | Red: all four declarations are present. |
| Manifest, recent sheets, capture creation, measurement upload, and judgment upload continue to work through generated types | `APIClientTests.testAppAPIFlowUsesLocalStubbedResponses` exercises the complete current flow against `URLProtocol` stubs. | Expected green before migration; not executed here because Swift is unavailable. Retain as regression coverage. |
| Ranked results are generated and wired into the app | Add a typed ranked-results API test when the published schema establishes its response shape. The prose contract currently gives no response JSON to stub. | Blocked by viamin/color_matching#110. |
| Contract deltas and endpoint gaps are recorded in the PR | Human review of the published `viamin/color_matching#110` specification against `docs/color-matching-api-contract.md`. | External evidence required. |

## Published-spec comparison checklist

- Authentication scheme and required/optional bearer token behavior.
- Exact request/response schemas for the six endpoint paths asserted above.
- Enum spelling for capture rejections and user judgments.
- Timestamp encoding, nullable fields, numeric precision, and response status codes.
- Ranked-results response schema, which is absent from the prose contract.
