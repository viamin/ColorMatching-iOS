# OpenAPI Client Migration Evidence

## Acceptance-criterion plan

| Criterion | Smallest credible verification | Status in test-writing phase |
| --- | --- | --- |
| Package contains the generator and runtime, and the spec is vendored | `OpenAPIContractTests.testPackageDeclaresSwiftOpenAPIGeneratorAndRuntime` plus `testVendoredOpenAPIDocumentCoversEveryAppOperation` | Red: implementation has not added the package dependencies or `iOS/OpenAPI/openapi.json`. |
| Generated client covers manifest, recent sheets, capture creation, measurement upload, judgment upload, and ranked results | `OpenAPIContractTests.testVendoredOpenAPIDocumentCoversEveryAppOperation` asserts each canonical path/method exists; `APIClientTests` uses `MockURLProtocol` local responses for the first five currently exposed operations. | Ranked-results app integration is absent today and needs an implementation-phase local-stub test once the generated operation name is available. |
| App uses generated types instead of hand-written API models | Inspect the implementation diff and compile `swift test --disable-sandbox`; source migration itself is not provable from an HTTP test alone. | Not run: implementation is intentionally out of scope for this test-writing run. |
| Generated client is exercised against local stubs | `APIClientTests` uses `MockURLProtocol`; no live server is contacted. | Manifest and recent-sheets tests added this run; capture, measurements, and judgments already had stub coverage. |
| Contract deltas and endpoint gaps are recorded | This document is the PR-description source of truth; reviewer inspection is required. | Recorded below. |

## Upstream evidence

`viamin/color_matching#110` is closed. Its delivered API exposes the OpenAPI document at `GET /api/v1/openapi.json`; the upstream `ColorMatchingWeb.OpenApiController` delegates it to `OpenApiSpex.Plug.RenderSpec`.

## Prose-contract deltas and gaps

- The prose contract declares `created_at`, `printer_profile`, and `capture_profile` on a manifest. The current iOS `SheetManifest` only decodes the page, markers, patches, and pairs used by the app, so those fields are client-side compatibility gaps to resolve during generated-type adoption.
- The prose contract describes the ranked-results endpoint only narratively. It does not define a response schema, and the current iOS API client exposes no ranked-results method. The published OpenAPI document is the authority for the missing response type and operation shape.
- The prose contract names endpoint parameters `:sheet_id` and `:capture_id`; OpenAPI paths use `{sheet_id}` and `{capture_id}`. The tests use the OpenAPI form.
- The upstream issue additionally documents two non-`/api/v1` POST endpoints. They are outside this issue's required iOS surfaces and remain intentionally unconsumed.
