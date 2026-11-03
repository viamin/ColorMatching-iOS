---
module: iOS
tags: [openapi, swift, api-client, tdd]
problem_type: migration
---

# Generated OpenAPI client migration: verification plan

This is the test-writing (red) phase for issue #5. The implementation run must
vendor the published `viamin/color_matching#110` document at
`iOS/OpenAPI/color_matching.yaml`, configure Swift OpenAPI Generator and
Runtime in `iOS/Package.swift`, generate the client, and replace the
hand-written transport models that represent server payloads. Measurement and
camera-analysis types remain client-side models.

## Criterion mapping

| Criterion | Smallest credible verification | Current evidence |
| --- | --- | --- |
| Generator, runtime, and document are present | Focused package/spec test checks the two dependencies, generator plugin, and vendored document | `GeneratedClientConfigurationTests.testPackageDeclaresOpenAPIGeneratorAndRuntime` (red until implementation) |
| All used API surfaces are generated | Focused spec-coverage test checks manifest, recent sheets, capture creation, measurements, judgments, and ranked results paths | `GeneratedClientConfigurationTests.testVendoredSpecificationCoversEveryAppEndpoint` (red until document is vendored) |
| Generated transport decodes local responses | Permanent local-stub tests exercise manifest and recent-sheets reads; implementation run must migrate the existing capture/measurement/judgment stubs to generated operations and add ranked-results decoding | `APIClientTests` local `MockURLProtocol` suite |
| Contract deltas and endpoint gaps | Human/external evidence: compare vendored upstream document with `docs/color-matching-api-contract.md` and record the result in the implementation PR description | Blocked: upstream document is not available on the public default branch and `viamin/color_matching#110` is not externally accessible in this environment |

## PR description template for the implementation run

```
## What changed
- Vendored OpenAPI document at `<commit SHA/source URL>` and generated the Swift client.
- Replaced hand-written server transport models with generated request/response types.
- Kept MeasurementCore analysis models client-side.

## Contract deltas from docs/color-matching-api-contract.md
- <observed field, nullability, enum, status-code, or naming delta>

## Endpoint gaps
- <missing operation, or "None: all six app-used operations are present.">

## Verification
- `swift test --disable-sandbox`
- Local stub coverage for manifest, recent sheets, capture creation, measurement upload,
  judgment upload, and ranked results.
```
