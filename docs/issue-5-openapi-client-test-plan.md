# Issue #5 OpenAPI client verification plan

This is the red-phase verification plan for replacing the hand-written iOS
`/api/v1` client. It maps each acceptance criterion to the smallest credible
evidence before implementation begins.

| Criterion | Verification | Current evidence / expected result |
| --- | --- | --- |
| Add `swift-openapi-generator` and `swift-openapi-runtime`; fetch or vendor the published document | Inspect `iOS/Package.swift`, the checked-in spec, and generated source in the implementation PR | Not run in this test-writing phase. The published document must be fetched from `viamin/color_matching`'s `GET /api/v1/openapi.json` rather than reconstructed from this repository's prose contract. |
| Generate client surfaces for manifest, recent sheets, capture creation, measurement upload, judgment upload, and ranked results | Permanent local-stub XCTest coverage for each generated operation | `APIClientTests` now stubs the manifest and recent-sheet reads and already stubs capture, measurement, and judgment writes. `testRankedResultsEndpointRequiresGeneratedClientCoverage` is intentionally red until generated ranked-results support and its stubbed response test replace it. |
| Replace API-owned hand-written models, retaining client-only measurement models | Inspect generated type references and removal of duplicated API Codable declarations | Not run in this test-writing phase; requires implementation diff review. |
| Generated-client tests use local stubs, with no live CI server | Permanent XCTest target using `MockURLProtocol` | The tests use an ephemeral `URLSession` whose sole protocol is `MockURLProtocol`; no test contacts a live server. Run `swift test --disable-sandbox` after Swift is available. |
| PR description records contract deltas and endpoint gaps | Human/external evidence: compare the vendored published OpenAPI document against `docs/color-matching-api-contract.md`, then paste the result into the PR description | Not run: the published document is deliberately not inferred from the prose contract. Known pre-implementation gap: the app has no ranked-results client operation even though the prose contract names that endpoint. |

The recurring capture-upload flow is covered by focused local-stub tests: create
capture, upload measurements and scores, then upload judgments. The generated
client implementation must preserve those request shapes while obtaining API
types and endpoint definitions from the OpenAPI document.
