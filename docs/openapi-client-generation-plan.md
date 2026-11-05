# OpenAPI Swift Client Generation Plan

This run establishes the tests and evidence plan for #5. The implementation
run will vendor the OpenAPI document published by
[`viamin/color_matching#110`](https://github.com/viamin/color_matching/issues/110)
at `iOS/Sources/ColorMatchingAPI/openapi.json`, generate a typed Swift client,
and make the app-facing API facade delegate to it.

## Acceptance-criterion map

| Criterion | Smallest credible verification | Status in this test-writing run |
| --- | --- | --- |
| Generator, runtime, and vendored API document | `APIClientTests.testVendoredOpenAPIDocumentIncludesEveryAppEndpoint` parses the vendored JSON and checks all six paths. | Red until the document is vendored. |
| Generated client covers manifest, recent sheets, capture creation, measurement upload, judgment upload, and ranked results | The same document test checks every requested OpenAPI path; the implementation run must compile generated operation references. | Red until the document is vendored. |
| App facade uses generated types | `APIClientTests` exercises the facade with `URLProtocol` local stubs. The implementation run must retain these app-facing behaviors while changing its transport/types to generated ones. | Read paths pass; generated-client wiring is not yet implemented. |
| Local stub tests, no live server | `APIClientTests` uses `MockURLProtocol` for manifest, recent sheets, capture, measurement, and judgment responses. | Passing except for the missing vendored-document test. |
| PR records prose/spec deltas and endpoint gaps | This document records the upstream inspection below; final PR description must carry it forward. | Human review required. |

## Prose-contract versus published-spec deltas

The upstream implementation and OpenAPI definitions were inspected from
`viamin/color_matching` `main` after #110 closed.

- The six requested paths exist, including ranked results. The app currently
  has no ranked-results call even though the endpoint is published.
- Measurement and judgment uploads return `200` JSON acknowledgements with
  `capture_id` and accepted-item counts; the prose contract documented no
  response body and existing tests used `204`.
- The published measurement request accepts RGB objects, arrays, or encoded
  strings, and accepts score, similarity, or distance compatibility forms.
  The prose contract described only RGB objects and supplied both distance and
  similarity.
- The published measurement schema requires normalized RGB values but does
  not describe the prose contract's measurement `stats` or top-level
  `scoring_algorithm_version`; the server accepts compatibility payloads.
- The OpenAPI manifest and ranked-results component schemas currently expose
  only their minimum compatibility fields, while the server responses contain
  the fuller payload described here. Generated models may therefore need
  additional-properties handling or an upstream schema expansion before the
  app can replace all hand-written response models without losing data.

## Endpoint gaps requiring a decision

No requested endpoint is absent. The generated client needs an app-facing
ranked-results method even though the current UI ranks capture scores locally.
The implementation PR should either wire that operation where appropriate or
state why it remains available through the generated client but unused by the
current capture flow.
