# OpenAPI Swift Client: Verification Plan

This is the red-phase verification plan for #5. The tests use `URLProtocol`
stubs only; no test contacts a live Phoenix server.

| Criterion | Smallest credible verification | Current evidence |
| --- | --- | --- |
| Generated client dependencies and vendored contract | `OpenAPIClientAdoptionTests.testPackageUsesGeneratedClientAndVendoredSpecCoversAppEndpoints` checks both Swift dependencies and all six app-used paths in the vendored OpenAPI JSON. | Red until implementation vendors the document and configures the generator/runtime. |
| Manifest and recent-sheet reads | `APIClientTests` stubs published response bodies and checks decoded values, authorization, and paths. | Passing against the compatibility client; must remain passing through generated-client wiring. |
| Capture, measurement, and judgment writes | Existing `APIClientTests` stubs each write endpoint and checks URL, authorization, and JSON request payload. | Passing against the compatibility client; must remain passing through generated-client wiring. |
| Ranked results | The vendored-spec test requires the ranked-results operation. A client stub test must be added with the generated operation because the current public client has no ranked-results method. | Red gap intentionally exposed by this test-writing run. |

## Contract deltas found from upstream #110

The upstream contract is served dynamically at `/api/v1/openapi.json`; this
repository must vendor a reviewed snapshot for reproducible generation. The
published schema currently describes the manifest and ranked-results responses
only minimally, despite the server rendering richer payloads. It also permits
both nested `metadata` capture requests (the iOS prose contract) and legacy
flat capture fields. Measurement uploads no longer require the prose
contract's `scoring_algorithm_version` or per-measurement `stats`, while
`normalized_linear_rgb_median` is required by the published schema. Finally,
the server's successful measurement and judgment uploads return 200 JSON
count responses, whereas the prose contract and current client expect no
response body / 204.

The implementation PR must record whether the upstream spec is tightened or
the app maps the generated types to its existing client-side measurement and
scoring models. In particular, generated models must not replace purely local
camera-analysis models unless their ownership becomes server-defined.
