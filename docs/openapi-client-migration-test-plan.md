# OpenAPI Client Migration Test Plan

This test-writing change captures the smallest credible verification for issue #5 before implementation.

| Criterion | Verification | Current result |
| --- | --- | --- |
| Generator, runtime, and OpenAPI document are present | `APIClientTests.testPackageDeclaresOpenAPIClientGenerationAndVendoredSpec` reads the Swift package and vendored spec and asserts the six required paths. | Red: the package has neither dependencies and no spec is vendored. |
| Manifest and recent-sheet responses stay decodable through the generated boundary | `APIClientTests.testFetchManifestDecodesGeneratedContractResponse` and `testFetchRecentSheetsDecodesNullableTitle` use `URLProtocol` stubs. | Existing handwritten client passes; migrate these tests to generated operation calls. |
| Capture, measurement, and judgment uploads stay compatible | Existing `APIClientTests` request-body stub tests. | Existing handwritten client passes; migrate these tests to generated operation calls. |
| Ranked-results endpoint is generated | Vendored-spec assertions in `testPackageDeclaresOpenAPIClientGenerationAndVendoredSpec`. | Red: no spec or client operation exists. |
| Prose-contract comparison in PR description | Human/external review of the downloaded `color_matching` OpenAPI document against `docs/color-matching-api-contract.md`. | Not run: the provider issue is closed, but its served document was not reachable from this environment and is not committed in this repository. |

Implementation must preserve local `URLProtocol` fixtures and replace the handwritten request/response types used by the app. The fixture tests are permanent coverage for the recurring capture upload flow; no live server is required in CI.

## PR Description Checklist

- State the exact upstream OpenAPI document URL and revision vendored or fetched.
- List each difference from the prose contract, including renamed fields, requiredness, nullable values, status codes, enum values, and payload envelopes.
- Record whether all six app surfaces are specified: manifest, recent sheets, capture creation, measurements, judgments, and ranked results.
- Call out endpoint gaps discovered in the published specification instead of silently preserving handwritten compatibility code.
