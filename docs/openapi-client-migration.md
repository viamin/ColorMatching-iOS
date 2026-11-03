# OpenAPI Client Migration Verification Plan

This file is the PR-body source for issue #5. It records criterion-level
evidence that the implementation run must update before merge.

| Criterion | Smallest credible verification | Initial state |
| --- | --- | --- |
| Generator, runtime, and vendored spec are wired into the Swift package | `GeneratedOpenAPIClientAdoptionTests.testPackageWiresGeneratorRuntimeAndVendoredAPISpec` inspects the manifest and the vendored `iOS/OpenAPI/openapi.json` input. | Red: package has neither packages nor plugin, and the spec is absent. |
| Generated client covers manifest, recent sheets, capture creation, measurement upload, judgment upload, and ranked results | Local `URLProtocol` tests use representative fixtures for each generated operation and assert method, route, typed request, and typed response. | Existing stubs cover capture creation and both uploads only; manifest/recent/ranked-results coverage must be added in implementation. |
| Hand-written API models are replaced while client-only models remain | A focused source-level migration guard confirms API request/response transport types come from the generated module; MeasurementCore analysis types remain owned by MeasurementCore. | Not implemented. |
| No live server is needed in CI | All generated-client tests inject a `URLSession` using `MockURLProtocol`; each fixture is local. | Existing API client tests use this pattern. |
| `swift test --disable-sandbox` is green | Run the command after implementation. | Not run in this environment: Swift is not installed. |

## Published-contract evidence

The provider's closed issue [viamin/color_matching#110](https://github.com/viamin/color_matching/issues/110)
adds an OpenAPI endpoint at `GET /api/v1/openapi.json`. Its committed router
declares all six consumer routes: manifest, recent sheets, capture creation,
measurement upload, judgment upload, and ranked results.

The provider's hosted endpoint could not be fetched in this isolated run
(DNS resolution failed), so the actual JSON document must be fetched or
vendored by the implementation run and its revision/checksum recorded in the
PR description. The provider's source establishes the endpoint and routes,
but is not a substitute for inspecting the published document.

## Contract deltas observed before fetching the JSON document

The prose contract says uploads return `204 No Content`. The provider's
controllers declare `200 OK` JSON responses for both measurement and judgment
uploads, containing `capture_id` plus a count. The generated client must model
the published `200` responses rather than preserve the prose-only `204`
assumption.

The prose contract only describes ranked results narratively; it does not give
a response schema. The published OpenAPI document is therefore required before
the iOS client can generate a typed ranked-results operation. No other deltas
are asserted until that document is vendored and reviewed.
