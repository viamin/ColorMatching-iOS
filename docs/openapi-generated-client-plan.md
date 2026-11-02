# Generated OpenAPI client: test plan and implementation contract

Working notes for issue #5 (replace the hand-written API layer with a generated
OpenAPI Swift client). This run added the **red-phase tests**; the sections
below map each acceptance criterion to its verification and pin the contract
the implementation run must satisfy to turn the new tests green.

## Acceptance criteria → verification mapping

| ID | Criterion (from #5) | Verification | Locator |
| --- | --- | --- | --- |
| AC-1 | `swift-openapi-generator` + `swift-openapi-runtime` added; OpenAPI document vendored | The new tests `import ColorMatchingOpenAPI` and `import OpenAPIRuntime`; compilation of `iOS/Tests/ColorMatchingLPSAppTests` is impossible without the packages and generated target wired into `iOS/Package.swift` | `iOS/Tests/ColorMatchingLPSAppTests/OpenAPIStubTransport.swift` |
| AC-2 | Client generated for the surfaces the app uses (manifest, recent sheets, capture creation, measurement upload, judgment upload, ranked results) | One stubbed generated-client test per operation, each asserting the exact HTTP method/path and the upstream operation ID, so a spec regeneration diff shows up as a test failure | `iOS/Tests/ColorMatchingLPSAppTests/GeneratedClientTests.swift`, `iOS/Tests/ColorMatchingLPSAppTests/GeneratedCaptureUploadTests.swift` |
| AC-3 | Hand-written API models replaced by generated types; client-side models kept | Tests construct only generated types (`Components.Schemas.*`) for wire payloads; `MeasurementCore.SheetManifest` and friends are not referenced by the new tests and stay hand-written (see deltas G-1) | `docs/color-matching-openapi-spec-deltas.md` |
| AC-4 | Swift tests against local stubbed responses, no live server | `RecordingClientTransport` (a `ClientTransport`) serves canned JSON and records outgoing requests; every network assertion is offline | `iOS/Tests/ColorMatchingLPSAppTests/OpenAPIStubTransport.swift` |
| AC-5 | PR description records prose-contract vs published-spec deltas and endpoint gaps | Delta document written from the published spec (`GET /api/v1/openapi.json` of viamin/color_matching#110) against `docs/color-matching-api-contract.md`; use it verbatim in the PR body | `docs/color-matching-openapi-spec-deltas.md` |
| AC-6 | Contract drift becomes a regeneration diff / compile error | Drift-sensitive assertions: operation IDs, request paths, response enums (`schemaVersion`), documented response codes (`.undocumented` case for anything else), and the documented-absent fields (`stats`, `scoring_algorithm_version`) in the measurement upload body | `GeneratedClientTests.testUndocumentedResponseStatusSurfacesAsUndocumentedCase`, `GeneratedCaptureUploadTests.testUploadMeasurementsEncodesDocumentedPayloadAndDecodesCounters` |

## Expected red phase

The three new test files do not compile until the implementation run lands:
`no such module 'ColorMatchingOpenAPI'` / `'OpenAPIRuntime'` is the expected
failure mode of this tests-only PR (the previously existing
`APIClientTests`/`MeasurementCoreTests` remain untouched and green once the
module wiring exists). No Swift toolchain exists in the authoring container, so
local execution was not possible; `swift test --disable-sandbox` on macOS CI is
the executor of record.

## Implementation contract the tests pin

1. **Package wiring** (`iOS/Package.swift`):
   - products: `apple/swift-openapi-generator` (1.x, plugin
     `OpenAPIGenerator`), `apple/swift-openapi-runtime` (1.x).
   - new target `ColorMatchingOpenAPI` whose sources are only
     `openapi.json` + `openapi-generator-config.yml`, with the generator
     plugin applied; it depends on `swift-openapi-runtime`.
   - `ColorMatchingLPSAppCore` depends on `ColorMatchingOpenAPI` and
     `swift-openapi-runtime` (for `BearerTokenMiddleware`).
   - `ColorMatchingLPSAppTests` depends on `ColorMatchingOpenAPI` and
     `swift-openapi-runtime` (the tests import both directly).
2. **Vendored document**: fetch `GET /api/v1/openapi.json` from the Phoenix app
   (viamin/color_matching#110) and store it as
   `iOS/Sources/ColorMatchingOpenAPI/openapi.json`. The six operation IDs are
   `ColorMatchingWeb.TestSheetController.manifest` / `.recent` /
   `.ranked_results` and `ColorMatchingWeb.CaptureController.create` /
   `.upload_measurements` / `.upload_judgments` — the tests assert these exact
   strings.
3. **Generator config**
   (`iOS/Sources/ColorMatchingOpenAPI/openapi-generator-config.yml`):

   ```yaml
   generate:
     - types
     - client
   accessModifier: public
   namingStrategy: idiomatic
   nameOverrides:
     ColorMatchingWeb.TestSheetController.manifest: getManifest
     ColorMatchingWeb.TestSheetController.recent: listRecentSheets
     ColorMatchingWeb.TestSheetController.ranked_results: getRankedResults
     ColorMatchingWeb.CaptureController.create: createCapture
     ColorMatchingWeb.CaptureController.upload_measurements: uploadMeasurements
     ColorMatchingWeb.CaptureController.upload_judgments: uploadJudgments
   ```

   The tests call the overridden method names
   (`getManifest`, `listRecentSheets`, `getRankedResults`, `createCapture`,
   `uploadMeasurements`, `uploadJudgments`) and reference the generated nested
   types (`Operations.<name>.Input/Output`, `Components.Schemas.*`).
   `accessModifier: public` is required so the tests (a separate module) can
   see the generated API.
4. **Bearer auth stays app-side** (the generator ignores security schemes):
   `public struct BearerTokenMiddleware: ClientMiddleware` with
   `init(token: String)` in `ColorMatchingLPSAppCore`, adding
   `Authorization: Bearer <token>` to every outgoing request.
   `testBearerTokenMiddlewareAddsAuthorizationHeader` pins it.
5. **Model replacement**: delete the hand-written wire models
   (`CaptureMetadata`, `WhiteBalanceGains`, `CaptureSessionResponse`,
   `RecentSheet`, `PairJudgment`, and the private request wrappers in
   `APIClient.swift`) and re-express `APIClient` (or its successor) on the
   generated `Client` plus `URLSessionTransport` from
   `apple/swift-openapi-urlsession`. Keep `MeasurementCore` untouched: its
   `SheetManifest`, `PatchMeasurement`, `ChannelStats`, `PairScore` are purely
   client-side analysis models (and per deltas G-1/G-2 the spec cannot yet
   express everything the app uses). Map between them and generated types at
   the call sites (e.g. `iso: Float?` → `Int?`, `RGB` → `RgbPayload(value2:)`).
   The existing `APIClientTests.swift` asserts the old hand-written surface and
   should be replaced by/absorbed into the new generated-client tests in the
   same implementation PR.
6. **Mechanical latitude for the implementation run**: if the vendored document
   serializes schema properties in a different order than `api_schemas.ex`,
   generated memberwise-init arguments may need reordering (labels and values
   must stay as written). Everything else in the tests is intentional contract.

## Verification status at this PR head

- Tests written and syntactically validated (fixtures parse as JSON);
  **not executed locally** — no Swift toolchain in this container. Executor of
  record: `swift test --disable-sandbox` on the macOS CI runner.
- Delta documentation (AC-5/AC-6 evidence) is inspectable at
  `docs/color-matching-openapi-spec-deltas.md`.
