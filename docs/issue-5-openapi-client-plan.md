# OpenAPI Swift client: issue #5 implementation record

## Acceptance-criterion verification plan

| Criterion | Smallest credible verification | Status in this tests-only change |
| --- | --- | --- |
| Add `swift-openapi-generator` and `swift-openapi-runtime`; vendor the published document | Focused package-layout test checks both dependencies and `Sources/ColorMatchingOpenAPI/openapi.json` | Red: `APIClientTests.testPackageIncludesGeneratedClientInputsAndRuntimeDependencies` |
| Generate the manifest, recent-sheet, capture, measurement, judgment, and ranked-result client surfaces | Compile the adapter against generated operation/model types; one stubbed-response test for each operation | Not yet runnable: generated operation names await vendored document |
| Replace server contract models while retaining client-only models | Compile the app target; focused adapter tests prove conversions from `MeasurementCore` inputs to generated requests | Not yet runnable: generated types absent |
| Exercise generated client locally, without a live server | Permanent `URLProtocol` stub tests: manifest and recent-sheet retrieval are added now; capture/measurement/judgment stubs already exist in `APIClientTests` | Partial: six-surface coverage awaits generated ranked-results operation |
| Record prose-to-spec deltas and endpoint gaps | Inspect the merged upstream API source at `viamin/color_matching` commit `47057afd58f7d46b4d4b740ca7d2d08947774471` and preserve the findings below | Complete external evidence |

The failing package-layout test is intentional red-phase coverage. It must turn green when the implementation adds the generator plugin, runtime dependency, and a pinned copy of the upstream OpenAPI document. It does not permit a test-only implementation workaround.

## Published-spec source

The upstream dependency was completed by `viamin/color_matching#113` (closing #110). Its `ColorMatchingWeb.OpenApiController` serves the document at `GET /api/v1/openapi.json`. The implementation should vendor a document fetched from that endpoint and record its upstream commit or checksum beside the asset.

## Prose-contract deltas and endpoint gaps

The upstream OpenAPI schema currently does not describe the full server payloads used by this app. This is a blocker to treating generated models as the app's source of truth; the client migration must either accompany an upstream schema expansion or retain only narrow, explicitly client-side adapters.

| Surface | Prose contract / actual renderer | Published OpenAPI schema gap |
| --- | --- | --- |
| Manifest | The app reads page geometry, registration markers, patches, pairs, printer profile, and capture profile. The renderer returns all of these fields. | `Manifest` declares only `schema_version`, `sheet_id`, and `capture_profile.scoring_algorithm_version`; generated models would omit the geometry and patch/pair fields required for capture. |
| Ranked results | The prose specifies provenance, source colors, scores, labels, printer profile, and scoring-version data. The renderer returns a complete ranked-result list and metadata. | `RankedResults` declares only `schema_version` and `sheet_id`; the app cannot use a generated ranked-results model for the advertised result data. |
| Capture creation | The prose nests metadata and quality. The server accepts that form, but also supports a legacy flattened request. | The OpenAPI `CaptureRequest` uses `anyOf` for both shapes. Generation must be verified against the nested shape the iOS app sends. |
| Measurement upload | The prose sends `scoring_algorithm_version` plus per-measurement stats, and treats upload success as empty `204`. | The published schema omits the top-level scoring version and stats, permits multiple RGB encodings, and documents a JSON `200` response containing counts. |
| Judgment upload | The prose documents an empty `204` success. | The published schema documents a JSON `200` response with capture and judgment counts. |

These are API-schema gaps rather than permission to change capture or scoring behavior in this repository. The implementation PR description must retain this table (updated against the vendored spec) and link an upstream issue/PR for any unresolved missing fields.
