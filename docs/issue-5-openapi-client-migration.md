# Issue #5 OpenAPI client migration evidence

## Criterion map

| Criterion | Smallest credible verification | Status in this test-writing run |
| --- | --- | --- |
| Add the generator/runtime and vendor or fetch the published document | Inspect `iOS/Package.swift`, the checked-in OpenAPI document, and generated client source in the implementation PR | Not implemented; `OpenAPIClientGenerationTests.testGeneratedClientSourceIsCheckedIn` is the red test. |
| Generate all used API surfaces | Local `URLProtocol` stubs exercise manifest, recent sheets, capture creation, measurement upload, judgment upload, and ranked-results response fixture | Manifest/recent stubs added; existing tests cover the three write surfaces; ranked-results fixture added. |
| Replace hand-written API models while keeping client-only models | Inspect the generated target and the remaining `MeasurementCore` model ownership; compile the app | Human/code-review evidence required. |
| Generated-client tests use local stubs | Run the focused XCTest suite after wiring the generated client into `APIClient` | Not run: this container does not provide `swift`. |
| Describe contract deltas and endpoint gaps | Compare the committed prose contract with `viamin/color_matching`'s published `/api/v1/openapi.json` source at issue #110 | Recorded below; final PR description must retain this section. |

## Contract deltas found

- The published capture request supports either the original flat capture fields or the app's nested `metadata` request. `quality` is optional in the specification, whereas the current app always sends it.
- Measurement uploads no longer specify a top-level `scoring_algorithm_version` in the published schema. Each pair score requires `algorithm_version` and one of `score`, `similarity`, or `distance`; the app supplies `similarity` and `distance`.
- The published measurement and judgment endpoints return `200` JSON acknowledgement objects with capture and row counts, rather than the prose contract's unspecified/empty successful response.
- Ranked results are now specified as `lps-ranked-results/v1`, including aggregate score fields, provenance timestamps, current judgment, and source colours. The current app has no corresponding API client operation; it only renders locally calculated scores.
- The manifest's published schema currently declares only `schema_version`, `sheet_id`, and `capture_profile.scoring_algorithm_version` as required, although the server renderer supplies the richer manifest fields described in the prose contract. Generated types must preserve the fields needed by `MeasurementCore`.

## Endpoint gaps

No gap was found for the five requested endpoint families: manifest, recent sheets, capture creation, measurement upload, judgment upload, and ranked results are all present in issue #110's server specification. The implementation must decide whether ranked results is exposed through the app facade now or generated but unused, because current UI behavior ranks measurements locally.
