# Issue #5 OpenAPI client verification plan

This is the test-writing (red) phase for replacing the hand-written iOS API
transport. The implementation run must make the adoption tests green and retain
the stubbed request/response tests as the local, deterministic client boundary.

| Criterion | Smallest credible verification | Current state |
| --- | --- | --- |
| Generator and runtime are installed; a published spec is vendored | `GeneratedOpenAPIClientAdoptionTests.testPackageDeclaresOpenAPIGeneratorAndRuntimeDependencies` and `.testVendoredSpecificationCoversEveryCompanionSurface` | Red: no dependencies or vendored spec yet |
| Generated client covers manifest, recent sheets, capture creation, measurement/judgment upload, and ranked results | The vendored-spec coverage test plus a local `URLProtocol` test for each generated operation | Red: only manifest/recent/capture/upload hand-written paths exist; ranked results is absent |
| Hand-written transport models are replaced while measurement-domain models remain | `GeneratedOpenAPIClientAdoptionTests.testHandWrittenTransportModelsAreReplacedByGeneratedClientTypes` plus compilation | Red: request models remain in `APIClient.swift` |
| Generated client is exercised without a live server | `APIClientTests` uses `MockURLProtocol`; implementation must update these stubs to invoke generated operations and add ranked-results coverage | Partially present, but currently invokes the hand-written client |
| Contract deltas and endpoint gaps are recorded | This document's "Published-spec deltas" section is inspectable PR evidence | Recorded below |

## Published-spec deltas

Evidence was inspected from `viamin/color_matching` main at the closed
dependency issue [#110](https://github.com/viamin/color_matching/issues/110),
whose OpenAPI endpoint is `GET /api/v1/openapi.json`.

- The published spec exposes the six companion routes, including
  `ranked_results`, while the current iOS client has no ranked-results method.
- Measurement and judgment uploads return `200` JSON acknowledgement objects
  (`capture_id` plus counts), not the prose contract's response-less `204`.
- Measurement uploads require `normalized_linear_rgb_median`; the prose
  contract presents it as optional. The published schema does not model the
  prose `scoring_algorithm_version` or per-measurement `stats` fields.
- Capture creation accepts both the nested `metadata` shape in the prose
  contract and a legacy flat shape. Its `iso` is an integer in the published
  schema, versus `Float` in the current client model.
- The published manifest and ranked-results schemas currently specify only a
  subset of the prose fields. Generated model integration may therefore need
  a small client-side adapter for the existing measurement-domain manifest
  types, or upstream schema enrichment before those types can be wholly
  generated.

## Intended implementation evidence

The implementation PR description should state the exact upstream spec commit
or content digest that was vendored, list any adapter retained solely because
the spec lacks fields, and report the result of:

```sh
cd iOS
swift test --disable-sandbox
```
