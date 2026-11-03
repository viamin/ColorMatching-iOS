# Generated OpenAPI Client: Test Plan and Contract Evidence

This is the tests-only plan for issue #5. It maps each acceptance criterion to
its smallest credible verification before implementation begins.

| Criterion | Verification | Evidence at this PR head |
| --- | --- | --- |
| Package has generator/runtime and a vendored or fetched source document | Focused Swift package-manifest test (red until implementation) | `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift:testPackageDeclaresTheOpenAPIGeneratorAndRuntime` |
| Generated client covers manifest, recent sheets, capture creation, measurement upload, judgment upload, and ranked results | Permanent protocol-level stub tests, one per operation | Existing write tests plus read tests in `APIClientTests`; ranked-results test is intentionally deferred until the generated operation name is available |
| Hand-written API models are replaced while client-only measurement models remain | Human code review of the generated target and the adapter boundary | Implementation PR diff |
| Generated client is exercised without a live server | `URLProtocol`-backed Swift tests | `APIClientTests` |
| PR description records contract deltas and endpoint gaps | Human/external evidence | “Contract deltas” below, copied into the implementation PR description |

## Contract deltas from the published upstream source

Evidence was read from `viamin/color_matching` main at issue #110’s published
OpenAPI source (`ColorMatchingWeb.ApiSchemas` and the test-sheet/capture
controllers). The served document is `GET /api/v1/openapi.json`.

- Uploading measurements and judgments responds with `200` and JSON
  acknowledgements (`capture_id` plus count fields). The prose contract says
  `204` and does not describe those response bodies.
- Capture creation accepts the iOS prose contract’s nested `metadata` and
  `quality` form, but also accepts a legacy flattened capture shape. The
  generated client should use the nested form.
- The manifest and ranked-results schemas advertise explicit compatibility
  values: `lps-sheet-manifest/v1`, `lps-distance-v1`, and
  `lps-ranked-results/v1`. The prose contract omits the ranked-results schema.
- Recent-sheet `title` is required-but-nullable in the published schema; this
  matches the prose response’s nullable title.
- The published measurement schema requires
  `normalized_linear_rgb_median`, whereas the hand-written client’s
  client-side `PatchMeasurement` allows it to be absent. The adapter must
  reject or supply a value before calling the generated operation.

## Endpoint gaps

No route gap was found for the six requested surfaces: manifest, recent sheets,
capture creation, measurement upload, judgment upload, and ranked results are
all routed under `/api/v1` upstream. The iOS client currently has no ranked
results request, so implementation must add that generated-client call and a
stubbed response test once the generated operation name is available.

## Implementation PR description checklist

- State how `GET /api/v1/openapi.json` is fetched or vendored, including the
  pinned revision/checksum.
- Include the deltas above and whether ranked-result fields require an adapter
  beyond the published minimum schema.
- Report the focused Swift test result and identify the local `URLProtocol`
  stubs as the no-live-server evidence.
