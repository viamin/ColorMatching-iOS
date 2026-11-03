# Issue #5 OpenAPI client verification plan

This is the test-writing-phase evidence for replacing the hand-written iOS API
layer. The authoritative upstream input was fetched from
`viamin/color_matching` main at issue #110's completion, specifically
`/api/v1/openapi.json`'s source modules:

- `lib/color_matching_web/api_schemas.ex`
- `lib/color_matching_web/controllers/capture_controller.ex`
- `lib/color_matching_web/controllers/test_sheet_controller.ex`
- `lib/color_matching_web/controllers/test_sheet_json.ex`

## Criterion map

| Criterion | Smallest credible verification | Evidence in this PR phase |
| --- | --- | --- |
| Add generator/runtime and vendor the OpenAPI document | Focused Swift package-configuration test | `APIClientTests.testPackageManifestDeclaresGeneratedClientAndVendoredOpenAPISpec`; intentionally red until implementation adds both dependencies and `Sources/ColorMatchingAPI/openapi.json` |
| Generate all used API surfaces | Local `URLProtocol` client tests per route; a compile-time generated-target import in the implementation phase | Existing write tests plus new manifest/recent stub tests; ranked-results has no hand-written client method, so its generated operation test must be added with the generated target |
| Replace hand-written API models | Compile the app against generated operation/model types | Not runnable in this tests-only phase; the configuration test prevents claiming the prerequisite is complete |
| Generated client against local stubs | Permanent Swift unit/service tests using `MockURLProtocol`, no live server | `APIClientTests` covers manifest, recent sheets, capture creation, measurement upload, and judgment upload; implementation must move these calls to generated operations and add ranked-results coverage |
| PR description records contract deltas and endpoint gaps | Inspectable external evidence from the published upstream spec and renderer | Deltas below; implementation PR must copy these conclusions into its PR description |

## Published-spec deltas and gaps

- Capture creation accepts either the prose contract's nested `metadata` object or
  a legacy flattened body. The published contract calls the legacy duration field
  `exposure_duration`, while the nested field is `exposure_duration_seconds`.
- The prose contract requires `scoring_algorithm_version` and measurement
  statistics. The published measurement schema does not require either; it
  accepts RGB values as arrays, objects, or JSON strings and accepts one of
  `score`, `similarity`, or `distance` for pair scores.
- The prose contract expects empty `204` responses for measurement and judgment
  uploads. The real API returns `200` JSON acknowledgements with the capture ID
  and accepted-row counts.
- The prose contract describes a detailed manifest and ranked-results response,
  but the published OpenAPI schemas currently machine-describe only a minimal
  subset: manifest `schema_version`, `sheet_id`, and capture scoring version;
  ranked results `schema_version` and `sheet_id`. The renderer emits more
  fields, but a generated client cannot type-check them until upstream expands
  those schemas.
- The app does not currently call `GET /api/v1/test_sheets/{sheet_id}/ranked_results`.
  That operation is present upstream but is an app integration gap, not a reason
  to invent new capture/scoring behavior.

## Phase status

The package-precondition test is deliberately red because the generator,
runtime, and vendored spec do not exist in this checkout. This is expected in
the mandated tests-only phase. The environment also lacks a Swift executable,
so the test command cannot be executed here; the implementation phase must run
`swift test --disable-sandbox` after installing the normal macOS/Xcode toolchain.
