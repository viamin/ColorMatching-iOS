# OpenAPI Swift Client Migration Evidence

This file records the acceptance-criterion plan for issue #5 while its
dependency, `viamin/color_matching#110`, is unavailable in this checkout.

## Verification map

| Criterion | Smallest credible verification | Current evidence/status |
| --- | --- | --- |
| Add `swift-openapi-generator` and `swift-openapi-runtime`, with the server document | Inspect `iOS/Package.swift` and the vendored/fetched document after #110 lands | Blocked: neither dependency nor machine-readable document is present. |
| Generate the manifest, recent-sheets, capture, measurement, judgment, and ranked-results client surfaces | Compile the generated client and its adapter target | Blocked: source OpenAPI operation IDs/schema names are not available. |
| Replace server API models but retain client-only models | Compile the app target and review the adapter boundary | Blocked until generated types exist. |
| Local-stub generated-client tests | Permanent `APIClientTests` use `MockURLProtocol`; no live server | Read and write request/response stubs are covered for the existing facade. Ranked results cannot be added until #110 specifies its response schema. |
| PR description records prose-contract deltas and endpoint gaps | Compare the vendored #110 document to `docs/color-matching-api-contract.md` | Blocked: the published document is absent. Known current gap: the app has no `ranked_results` API method/type despite the prose contract defining the route. |

## Contract comparison to perform when #110 lands

Compare operation paths, parameter names, required/nullable fields, date and
number formats, enum wire values, response status codes, and operation IDs.
The prose contract currently defines these surfaces:

- manifest and recent sheets;
- capture creation;
- measurement and judgment upload;
- ranked results.

The resulting PR description must list actual deltas from that comparison; it
must not claim the prose document is equivalent to the published spec without
the spec as inspectable evidence.
