# Issue #5 OpenAPI client verification plan

This test-writing change establishes the evidence required before replacing the
manual API layer. The implementation must vendor the document served by
`color_matching` at `/api/v1/openapi.json` as `iOS/OpenAPI/openapi.json` and
regenerate the Swift client from that file.

| Criterion | Smallest credible verification | Status in this test-writing PR |
| --- | --- | --- |
| Generator, runtime, and published spec are included | `OpenAPIGenerationTests` checks the package declarations and the vendored document | Red: dependencies and vendored document are not present |
| All app API surfaces are generated | The vendored document test requires GET manifest/recent/ranked-results and POST capture/measurements/judgments operations | Red: no vendored document exists |
| Manual API models are replaced | Implementation review confirms `APIClient` delegates request and response transport to generated OpenAPI types, retaining only app-domain adapters | Not yet run |
| Generated client handles local server responses | `APIClientTests` uses `MockURLProtocol` for manifest, recent sheets, capture creation, measurement upload, and judgment upload | Not run: this container has no Swift toolchain; rerun after generated-client wiring |

## Contract delta to record in the implementation PR

The upstream issue is closed and the current server router exposes all six
operations above. Compared with the prose contract, the server now publishes
`lps-ranked-results/v1` and returns a structured ranked-results payload
(aggregate counts, score summaries, observation provenance, and printer
profile fields); the prose contract only described that endpoint narratively.
The server's capture measurement and judgment uploads return JSON acceptance
summaries (`capture_id` plus counts), whereas the current hand-written client
discards successful response bodies. The real spec should be the final
authority for field-level deltas when its snapshot is vendored.

No endpoint gap was found for the six iOS surfaces. The app currently does not
render ranked results from the network, so wiring that generated operation is
required for parity with the issue deliverable but must not change capture or
scoring behavior.
