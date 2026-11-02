# ColorMatchingOpenAPITests

Tests that exercise the **generated** OpenAPI Swift client against local
stubbed responses — no live server is contacted.

> **Red-phase status:** this directory is intentionally *not* wired into
> `iOS/Package.swift` yet. Package manifest changes are implementation work
> and land in the follow-up implementation run (see
> `docs/openapi-client-migration.md`). Wiring this test target is step 1 of
> that run; until then these tests cannot build, which is the expected
> red-phase signal for a compiled language.

## Wiring contract (implementation run)

Add to `iOS/Package.swift`:

- dependencies: `apple/swift-openapi-generator`, `apple/swift-openapi-runtime`,
  and `apple/swift-openapi-urlsession-transport` (for the app's real
  transport; tests use the stub transport below and need only the runtime)
- a `.target(name: "ColorMatchingOpenAPI")` that vendors the OpenAPI document
  at `Sources/ColorMatchingOpenAPI/openapi.json` (fetched from the Phoenix
  app's `GET /api/v1/openapi.json`, viamin/color_matching#110) and applies the
  `OpenAPIGenerator` build plugin
- a `.testTarget(name: "ColorMatchingOpenAPITests")` depending on
  `ColorMatchingOpenAPI` and the product `OpenAPIRuntime` from
  `apple/swift-openapi-runtime`

`OpenAPISpecConformanceTests` (in `../ColorMatchingLPSAppTests/`) guards the
vendored document itself and already runs today.

## Generated method names

`open_api_spex` derives operation ids as `<ControllerModule>.<action>`, and
swift-openapi-generator sanitizes them (`.` → `_`, `_` between words removed
with the next word capitalized). The six app surfaces therefore appear as:

| Operation id | Generated Swift method |
| --- | --- |
| `ColorMatchingWeb.TestSheetController.recent` | `colorMatchingWeb_TestSheetController_recent` |
| `ColorMatchingWeb.TestSheetController.manifest` | `colorMatchingWeb_TestSheetController_manifest` |
| `ColorMatchingWeb.TestSheetController.ranked_results` | `colorMatchingWeb_TestSheetController_rankedResults` |
| `ColorMatchingWeb.CaptureController.create` | `colorMatchingWeb_CaptureController_create` |
| `ColorMatchingWeb.CaptureController.upload_measurements` | `colorMatchingWeb_CaptureController_uploadMeasurements` |
| `ColorMatchingWeb.CaptureController.upload_judgments` | `colorMatchingWeb_CaptureController_uploadJudgments` |

If the generator version mangles a name differently, fix the call site here —
the durable assertions are the `operationID`, HTTP method, and path checks,
which are independent of Swift name mangling. Prefer decoding fixtures into
generated types over constructing them with memberwise inits: schema property
order comes from an Elixir map and is not stable, so memberwise init argument
order must not be relied on.
