# OpenAPI client migration verification plan

This is the red-phase test plan for issue #5. The generated-client
implementation will replace the current hand-written API layer without changing
the local-stub testing boundary.

| Criterion | Smallest credible verification | Current status |
| --- | --- | --- |
| Generated client dependency and checked-in/fetched OpenAPI document | Package manifest and generation configuration inspection | Not implemented in this tests-only run |
| Generated manifest, recent sheets, capture, measurement, judgment, and ranked-results surfaces | Local `URLProtocol` XCTest stubs that assert each request and decode each typed response | Manifest/recent/capture/measurement/judgment stubs are in `APIClientTests`; ranked results is an endpoint gap because the app has no current client method |
| Hand-written API models replaced while client-only models remain | Compile the app after removing server-model declarations; inspect retained MeasurementCore types | Not implemented in this tests-only run |
| Generated client works without a live server | `APIClientTests` uses `MockURLProtocol` exclusively | Covered for every currently callable endpoint |
| Contract deltas and endpoint gaps recorded | PR description backed by the upstream `/api/v1/openapi.json` artifact | Requires the implementation PR, after vendoring the published spec |

The upstream OpenAPI work merged as
[`viamin/color_matching#113`](https://github.com/viamin/color_matching/pull/113),
which publishes `GET /api/v1/openapi.json`. The implementation run must fetch
that artifact, commit or pin it for reproducible generation, and compare its
schemas against `docs/color-matching-api-contract.md`. In particular, the
prose contract has no concrete ranked-results response schema, so the published
spec is the authority for that generated response type.

The implementation PR description must use
[`docs/openapi-client-contract-deltas.md`](openapi-client-contract-deltas.md)
as its source of the known deltas, then re-check those findings against the
vendored version of the published document.
