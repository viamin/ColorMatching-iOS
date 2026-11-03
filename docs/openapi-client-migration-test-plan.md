# OpenAPI client migration: acceptance evidence plan

This is the red-phase test plan for issue #5. It defines the evidence that the
implementation PR must produce; it is not evidence that the generated client is
already present.

| Criterion | Smallest credible verification | Location / status |
| --- | --- | --- |
| Package contains the generator/runtime and a vendored or fetched OpenAPI document | Inspect `iOS/Package.swift`, generator configuration, and the checked-in spec URL/version. | Human/code-review evidence; not yet run. |
| Generated operations cover manifest, recent sheets, capture creation, measurements, judgments, and ranked results | Compile the generated module and exercise every operation against a local `URLProtocol` stub. | `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift`; red: ranked-results operation is absent. |
| Hand-written API models are replaced while client-only analysis models remain | Inspect the generated type imports and the remaining `MeasurementCore` model ownership. | Human/code-review evidence; not yet run. |
| Generated client works with local stubs | Run `swift test --disable-sandbox` and require the `APIClientTests` stubs to pass. | Infrastructure blocked in this run: Swift is not installed in the container. |
| PR records prose-contract versus published-spec deltas | Compare `docs/color-matching-api-contract.md` with `viamin/color_matching` issue #110's published API behavior. | Delta record below; human/code-review evidence. |

## Contract deltas observed before implementation

- Measurement and judgment uploads return `200` JSON acknowledgement bodies with
  `capture_id` and counts, while the prose contract documents no response body
  and the existing tests use `204`.
- The prose contract describes ranked-results only in prose; the published API
  declares a typed `200` ranked-results response. The iOS client currently has
  no ranked-results operation.
- Capture IDs in the published controller are decimal string IDs. The prose
  contract's `capture_123` example implies an opaque prefixed identifier.
- The server exposes bearer authentication on all six sheet/capture operations.
  The existing client sends it, so no intended behavior change is identified.

The implementation must refresh this comparison from the vendored OpenAPI JSON,
not only from the controller source, and record any schema-only changes in the
PR description.
