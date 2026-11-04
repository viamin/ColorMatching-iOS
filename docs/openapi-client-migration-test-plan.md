# OpenAPI client migration: test plan and PR evidence

This is the test-writing evidence for #5. The implementation run will replace
the current transport/model layer behind these tests with generated OpenAPI
types and operations; the tests intentionally use `MockURLProtocol`, so CI
does not need a live Phoenix server.

| Criterion | Smallest credible verification | Status in this test-writing run |
| --- | --- | --- |
| Generated client covers manifest and recent sheets | Permanent local-stub tests decode the server-shaped manifest and discovery responses. | Added; cannot run locally because Swift is unavailable. |
| Generated client covers capture creation, measurements, and judgments | Permanent local-stub tests assert request path, bearer auth, and server-shaped request bodies. | Existing coverage retained; cannot run locally because Swift is unavailable. |
| Generated client covers ranked results | A permanent local-stub test should call the generated ranked-results operation and decode `lps-ranked-results/v1`. | Not yet written: no generated API module or operation exists in this tests-only phase. |
| Replace hand-written API models, retaining client-only models | Compile the app target after replacing only transport representations; inspect the resulting diff. | Implementation-phase verification. |
| Add generator/runtime and vendor or fetch the spec | Resolve SwiftPM dependencies and run generation deterministically from the published `GET /api/v1/openapi.json` document. | Implementation-phase verification. |
| Record prose/spec deltas and endpoint gaps | Human inspection of upstream route, renderer, and generated OpenAPI document; place the results in the PR description. | Initial external evidence recorded below. |
| `swift test --disable-sandbox` is green | Run the stated command in a Swift-enabled environment. | Not run: this container has no `swift` executable. |

## Upstream evidence and deltas to put in the implementation PR description

Upstream issue [viamin/color_matching#110](https://github.com/viamin/color_matching/issues/110)
is closed. Its router exposes all required sheet/capture routes and serves the
OpenAPI document at `GET /api/v1/openapi.json`.

The source renderer currently exposes a material delta from the prose contract:
`manifest_url` is emitted as a relative path such as
`/api/v1/test_sheets/sheet_1/manifest`, while the prose document illustrates an
absolute URL. The local stub coverage uses the published relative form.

The upstream route and renderer also confirm that ranked results are present
with `schema_version: lps-ranked-results/v1`. The current iOS `APIClient` has
no ranked-results method, which is the endpoint gap the implementation must
close. The renderer returns aggregate result metadata (capture times/count,
printer profile, algorithm versions) and per-pair rank, colors, score,
judgment, observations, and capture provenance; these fields are not specified
by the prose contract beyond a short descriptive sentence.

Before merging the implementation PR, regenerate from the actual served JSON
and compare it with these observations. The generated document—not this source
inspection or the prose contract—is the final authority for request and
response types.
