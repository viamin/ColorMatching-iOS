# Issue #5 OpenAPI client verification plan

This is the test-writing phase for replacing the hand-written API layer. The
implementation run must generate the client from the published
`GET /api/v1/openapi.json` document and preserve the app-facing adapter only
where client-side measurement types require it.

| Criterion | Smallest credible verification | Evidence at implementation PR head |
| --- | --- | --- |
| Add generator/runtime and a fetched or vendored document | `swift package resolve` followed by `swift test --disable-sandbox`; inspect the committed spec source and generator target | Package manifest, resolved dependencies, vendored/fetch script and spec revision |
| Generate the manifest, recent sheets, capture, measurements, judgments, and ranked-results surfaces | Stubbed transport tests invoke every generated operation and assert request path, auth, encoded body, and decoded response | `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift` (permanent) |
| Replace hand-written API models without changing client-side measurement models | Compile the app plus a focused source review showing generated API types replace transport DTOs while `MeasurementCore` remains client-owned | `swift test --disable-sandbox` output and source diff |
| Test generated client without a live server | Permanent `URLProtocol` stub tests run through the generated client/adapter | `APIClientTests` result |
| Record prose-contract deltas and endpoint gaps | Compare the vendored OpenAPI document with `docs/color-matching-api-contract.md`; this requires human/external inspection, not a passing test | PR description with the spec revision/URL and delta list |

## Upstream findings to carry into the implementation PR

The upstream issue is complete: [viamin/color_matching#110](https://github.com/viamin/color_matching/issues/110)
serves an OpenAPI document dynamically at `/api/v1/openapi.json`.

The published OpenAPI source currently differs from the prose contract in
material ways that the generated-client implementation must account for:

- `CaptureMetadata` requires `image_width` and `image_height`, while the
  hand-written client marks both optional.
- Measurement and judgment uploads return `200` JSON count payloads, not the
  prose contract's `204` empty response.
- Ranked-results is routable, but its published schema only guarantees
  `schema_version` (`lps-ranked-results/v1`) and `sheet_id`; the prose promise
  of source colors, scores, labels, capture provenance, printer profile, and
  scoring version is not machine-specified. Treat this as an endpoint schema
  gap and do not invent a typed result model.
- The measurement upload schema models patch RGB values and pair scores, but
  does not require the prose contract's top-level `scoring_algorithm_version`.

These findings are external-contract evidence only. They must be rechecked
against the exact OpenAPI revision vendored or fetched by the implementation
PR.
