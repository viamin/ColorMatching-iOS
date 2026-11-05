# OpenAPI client verification plan

This is the acceptance-criterion map for issue #5. The permanent tests use
`URLProtocol` stubs only; they never contact a live Phoenix server.

| Criterion | Smallest credible verification | Evidence location |
| --- | --- | --- |
| Generator and runtime are installed and a spec is vendored | Focused configuration test checks the generator/runtime products and vendored spec paths | `iOS/Tests/ColorMatchingLPSAppTests/OpenAPIClientWiringTests.swift` |
| Generated types handle the manifest, recent sheets, capture creation, measurement upload, judgment upload, and ranked results | Permanent local-stub API tests assert request/response behavior for each operation; this red-phase change adds manifest/recent coverage and requires the implementation change to add ranked-results stubbing alongside the generated wrapper | `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift` |
| Hand-written transport models are removed while client-side measurement models remain | Focused wiring test rejects the old private transport payload models | `iOS/Tests/ColorMatchingLPSAppTests/OpenAPIClientWiringTests.swift` |
| No live server is required in CI | `URLProtocol` in the API tests serves every response locally | `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift` |
| Contract deltas and endpoint gaps are recorded | Human/external review of the vendored OpenAPI snapshot against `docs/color-matching-api-contract.md` and the upstream published endpoint | PR description; not settled by automated tests |

## Upstream evidence and known deltas

The upstream router at `viamin/color_matching` issue #110 exposes the six
companion routes above and serves its generated OpenAPI 3 document at
`GET /api/v1/openapi.json`. The document is generated at runtime, so this
repository must vendor a fetched snapshot and make regeneration a deliberate
diff instead of depending on an unversioned remote response during builds.

The prose contract already lists all six companion routes. Its ranked-results
section does not define a response schema, while the published specification
does; the implementation must preserve the server schema rather than invent a
local response model. The upstream API also has unrelated palette and
illuminant routes, which are outside this app's requested generated surface.
