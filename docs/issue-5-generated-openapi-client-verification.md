# Issue #5 verification plan

This is the test-writing run for replacing the hand-written iOS API models
with a generated OpenAPI Swift client. The implementation run must retain and
complete these tests; no live Phoenix service is used.

| Criterion | Smallest credible verification | Status in this run |
| --- | --- | --- |
| Add generator/runtime and vendor or fetch the published document | Inspect `iOS/Package.swift`, the pinned document, and generated target in the implementation PR. | Not yet implemented (external/inspectable). |
| Generated client covers manifest, recent sheets, capture creation, measurements, judgments, and ranked results | `URLProtocol`-stubbed Swift tests invoke each generated operation through the app boundary. | Manifest/recent are covered by `APIClientTests`; capture/measurement/judgment tests already exist; ranked-results test is intentionally red. |
| Replace server API models, preserving client-only models | Inspect source ownership plus compile generated types in the implementation PR. | Not yet implemented (human/inspectable). |
| No live server in CI | The stubbed tests use `MockURLProtocol`; the implementation test target must continue using it. | Covered for existing app-boundary tests. |
| `swift test --disable-sandbox` green | Run after Swift is available and generation is wired. | Not run: this container has no `swift` executable. |

## Published-spec comparison for PR description

Source inspected: `viamin/color_matching` issue #110 (closed) and its merged
OpenApiSpex route/schema implementation, which serves `GET /api/v1/openapi.json`.

Compared with `docs/color-matching-api-contract.md`:

- The published API includes `GET /api/v1/test_sheets/{sheet_id}/ranked_results`,
  with the concrete `lps-ranked-results/v1` response. The prose contract only
  described this response in words; this is the endpoint gap the app must wire.
- Measurement and judgment uploads return `200` JSON receipts containing the
  capture ID and accepted counts. The prose examples did not describe those
  response bodies; the current client discards them.
- Capture requests support both the nested `metadata`/`quality` shape used by
  the app and a legacy flat request shape. The generated client should use the
  nested shape and not preserve a hand-written duplicate model.
- Measurement RGB values permit an RGB array, an `{r,g,b}` object, or a
  JSON-encoded string in the published schema. The app's current native RGB
  object remains the intended request representation.
- The published API requires bearer authentication for all app-used operations;
  the OpenAPI document itself is the unauthenticated discovery endpoint.
- Recent-sheet `title` is required-but-nullable in the published schema, while
  the prose describes it as optionally null. The Swift mapping must preserve
  `nil`.

No behavioral change to capture or scoring is requested. The implementation PR
description should copy these deltas, pin the exact retrieved spec revision,
and add any deltas discovered by the generator.
