# Issue #5 OpenAPI Client Verification Plan

## Scope and evidence map

| Criterion | Smallest credible verification | Status in this tests-only change |
| --- | --- | --- |
| Generated package uses `swift-openapi-generator` and `swift-openapi-runtime`, with a tracked OpenAPI document | Focused XCTest inspects the package manifest and vendored document | Red: `APIClientTests.testPackageDeclaresGeneratedClientDependenciesAndVendoredSpecification` |
| Manifest and recent-sheet surfaces work with generated types | Permanent XCTest with local `URLProtocol` stubs, asserting request shape and decoded published responses | Manifest/recent coverage added; implementation will switch its backing types to generated ones |
| Capture creation, measurement upload, and judgment upload work with generated types | Permanent XCTest with local `URLProtocol` stubs, asserting request bodies and success responses | Existing `APIClientTests` cover these request surfaces; implementation must retain and adapt them |
| Ranked-results surface is generated and wired in | Permanent XCTest with a local stub of the published ranked-results response | Not run: the current app has no ranked-results API operation or model. Add once the generated operation name is available. |
| No live service is needed in CI | The permanent API tests use `MockURLProtocol` only | Covered by the cited tests |
| PR records contract deltas and endpoint gaps | Inspectable comparison against the upstream published endpoint/source | Recorded below; final PR description must carry it forward |

## Published API comparison

Source inspected at `viamin/color_matching` `main` (commit `47057afd58f7d46b4b740ca7d2d08947774471`), which serves the document at `GET /api/v1/openapi.json`.

- The manifest and recent-sheet response shapes agree with the prose contract for the fields used by the app. The published spec only requires a small subset of manifest fields even though the server renderer emits the full geometry payload; generated decoding therefore must preserve unknown-field tolerance while the app keeps its client-side `MeasurementCore.SheetManifest` geometry model.
- Capture creation accepts both the prose contract's nested `metadata`/`quality` form and an older flat compatibility form. `iso` is an integer in the published spec, not the prose contract's floating-point presentation.
- Measurement upload differs materially: the published schema does not declare `scoring_algorithm_version` at the top level, requires normalized RGB values, permits RGB arrays/objects/JSON strings, and its documented success is `200` with counts rather than the current client test's `204` empty body.
- Judgment upload's published success is `200` with `capture_id` and `judgment_count`, rather than the current client test's `204` empty body.
- Ranked results are now a real endpoint and renderer (`lps-ranked-results/v1`), but its OpenAPI schema currently declares only `schema_version` and `sheet_id`; its returned ranking fields are not yet machine-described. This is an endpoint-specification gap that must be called out in the PR and either resolved upstream or represented as an intentionally limited generated model.

## Implementation handoff

The implementation run should vendor the exact JSON returned by the upstream endpoint, add the OpenAPI build plugin/runtime dependencies, regenerate only the five in-scope paths, and replace transport-facing hand-written `Codable` request/response types. `MeasurementCore` analysis types remain client-side models. It must add the ranked-results stub test before marking the ranked-results criterion passed.
