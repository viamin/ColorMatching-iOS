# Issue #5 OpenAPI client adoption — verification plan

This is the tests-only phase for issue #5. The next implementation phase must
make the tests in `iOS/Tests/ColorMatchingLPSAppTests/OpenAPIContractTests.swift`
pass before replacing the handwritten transport models.

## Criterion map

| Criterion | Smallest credible verification | Current result |
| --- | --- | --- |
| Add the generator/runtime and vendor a spec | `testPackageEnablesOpenAPIGenerationAndRuntime`; vendored-spec loading | Red: neither dependency nor vendored document exists. |
| Generate the six API surfaces | `testVendoredSpecDefinesEveryOperationUsedByTheApp` | Blocked: the server spec needs to be vendored first. |
| Replace API types without changing client-only analysis models | Local-stub integration tests in `APIClientTests`, retaining `MeasurementCore` tests as the client-only boundary | Not run: generated operation/type names cannot be selected until the vendor document is available. |
| Local stub coverage | Permanent XCTest cases using `MockURLProtocol` for each generated operation | Not run: must be added alongside the generated operation adapter. No live server is acceptable in CI. |
| Contract deltas and endpoint gaps | This document plus the server-source evidence below | Recorded; upstream schema gaps block a fully typed replacement. |
| `swift test --disable-sandbox` | Run after the generated package target and adapter compile | Not run in this red phase. |

## Published-spec evidence and blockers

The OpenAPI publisher merged as
[viamin/color_matching#113](https://github.com/viamin/color_matching/pull/113),
which serves `/api/v1/openapi.json`.

At the upstream `main` revision inspected on 2026-10-31, the published schema
does not describe the full payloads the iOS app consumes or emits:

- `TestSheetManifest` declares only `schema_version`, `sheet_id`, and
  `capture_profile`; the actual manifest renderer additionally sends geometry,
  registration markers, patches, pairs, page data, and the manifest URL.
- `RankedResults` declares only `schema_version` and `sheet_id`; the renderer
  also sends aggregate counts, algorithm versions, and ranked pair results.
- `MeasurementUploadRequest` declares no required top-level fields and omits
  `scoring_algorithm_version` and per-measurement `stats`, both sent by the
  app. It also leaves RGB permissive as an array, object, or JSON string.
- `CaptureRequest` permits either legacy flat fields or `metadata`; nested
  `quality` is not required and its fields are not required. The prose
  contract requires the nested metadata/quality shape used by this app.

These assertions are deliberately encoded in the permanent contract tests.
They should be resolved by improving the server's OpenAPI specification, not
by restoring handwritten iOS API models or silently discarding values.

## Implementation-phase stub matrix

Use one `MockURLProtocol`-backed XCTest per generated operation:

| Operation | Stub assertion |
| --- | --- |
| Manifest | Generated response decodes full sheet geometry used by `SheetAnalyzer`. |
| Recent sheets | Generated response decodes nullable title and manifest URL. |
| Create capture | Generated request sends the nested metadata and quality payload; response returns capture ID. |
| Measurements | Generated request preserves scoring version, RGB values, statistics, and pair scores. |
| Judgments | Generated request sends pair ID and judgment; response acknowledgement decodes. |
| Ranked results | Generated response decodes ranked pair, score, provenance, and algorithm fields. |

The operation assertions must execute through the generated client and a local
stub; inspecting `Package.swift` or a generated source file is not a substitute.
