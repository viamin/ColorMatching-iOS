# OpenAPI Client Migration Test Plan (#5)

## Acceptance-criterion map

| Criterion | Smallest credible verification | Status in this tests-only PR |
| --- | --- | --- |
| Package uses `swift-openapi-generator` and `swift-openapi-runtime`; published document is vendored | Permanent contract test reads `iOS/Sources/ColorMatchingAPI/openapi.json`; implementation review inspects `iOS/Package.swift` plugin/runtime declarations | Blocked pending implementation |
| Generated client exposes manifest, recent sheets, capture creation, measurement upload, judgment upload, and ranked results | Permanent contract test asserts the vendored document has the six required path/method pairs | Red test added |
| Hand-written API models are replaced while client-side measurement models remain | Human code review of generated target and app adapter; compiler proves the app consumes generated API types | Not automatable before generated target exists |
| Client calls work against local stubs without a live server | Permanent `URLProtocol` tests exercise manifest, recent sheets, capture creation, measurement upload, and judgment upload | Existing plus new coverage; ranked-results stub awaits generated surface |
| PR records prose-contract deltas and endpoint gaps | Human/external evidence from the fetched `GET /api/v1/openapi.json`, compared with `docs/color-matching-api-contract.md` | Pending vendored document |

## Red-phase evidence

`OpenAPIContractTests.testVendoredOpenAPIDocumentCoversCompanionOperations` intentionally fails until the implementation adds the published OpenAPI JSON at `iOS/Sources/ColorMatchingAPI/openapi.json`. It makes the six operations required by the issue a checked generator-input contract rather than an informal checklist.

## Published-spec baseline and delta checklist

`viamin/color_matching#110` is closed and its router serves the spec at `GET /api/v1/openapi.json`. This checkout does not yet include a fetched copy or a configured deployment origin, so field-level comparison is not yet inspectable. The implementation PR must fetch and commit the exact document, record its source revision/fetch date, then compare it with the prose contract:

- request and response requiredness/nullability for all six operations;
- enum wire values for capture rejections and user judgments;
- date/time, numeric, and identifier formats;
- manifest fields presently ignored by the iOS model (`created_at`, `printer_profile`, `capture_profile`);
- ranked-results response shape, which the prose contract does not define; and
- any documented operation absent from the published spec (or published operation missing from prose).

The generated-client implementation must add a local-stub test for ranked results once its generated operation/type name is available.
