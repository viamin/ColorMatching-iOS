# OpenAPI client migration verification

## Criterion map

| Criterion | Smallest credible verification | Current status |
| --- | --- | --- |
| Generator and runtime are installed and the source document is available | `OpenAPIGenerationConfigurationTests.testPackageDeclaresGeneratorRuntimeAndGeneratedClientTarget` and `testGeneratedOpenAPIDocumentCoversEveryCompanionSurface` | Red: neither package configuration nor vendored document exists. |
| Generated client covers manifest, recent sheets, capture creation, measurement upload, judgment upload, and ranked results | The document-path test above plus `APIClientTests` local-stub request/response tests | Red: current client has no ranked-results operation and has no generated target. |
| Hand-written API models are replaced while client-side models remain | Implementation review of generated target and adapter imports | Not automatable in this red-phase test-only change. |
| Generated client works with local stubbed responses | `APIClientTests` uses `MockURLProtocol`; the existing write-operation tests cover capture, measurements, and judgments; new tests cover manifest and recent sheets. | The stubs pass against the existing adapter and must remain green after it delegates to generated operations. |
| PR records contract deltas and endpoint gaps | This document, informed by `viamin/color_matching#110` and its current main-branch controller tests. | Recorded below; final implementation PR must copy these findings into its PR description. |

## Contract deltas discovered

- The published provider API uses lookup codes for `sheet_id` and integer-string IDs for `capture_id`; the prose contract used opaque examples. Generated path parameters must remain strings.
- Measurement and judgment uploads return `200` JSON summaries (`capture_id` and counts), rather than the prose contract's `204` empty response. The replacement client must accept these bodies.
- Ranked results are now a defined response: `lps-ranked-results/v1`, aggregate capture counts, printer profile, per-pair score aggregates, current judgment, and latest observation. The prose contract only described this endpoint narratively.
- The manifest server response is authoritative for profile fields. The current app model intentionally only exposes geometry needed for capture; any additional generated fields should not force unrelated capture-domain changes.

## Endpoint gap

`APIClient` currently implements manifest, recent sheets, capture creation, measurement upload, and judgment upload only. It has no ranked-results operation, so the eventual generated-client adapter needs to add that surface before this issue can pass.
