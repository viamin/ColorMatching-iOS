# OpenAPI client migration evidence

## Acceptance-criterion plan

| Criterion | Smallest credible verification | Current test-phase evidence |
| --- | --- | --- |
| Add generator/runtime and a pinned OpenAPI document | Inspect `iOS/Package.swift`, the vendored document, and generated-source diff | Deferred: implementation phase must pin the `/api/v1/openapi.json` document from `viamin/color_matching#110`. |
| Generate and wire the six used API surfaces | Local `URLProtocol` stubs exercise manifest, recent sheets, capture creation, measurement upload, judgment upload, and ranked results through the generated client | `APIClientTests` has local stubs for the current five implemented surfaces. The ranked-results test is intentionally red because no client method exists. |
| Remove hand-written API models | Inspect the app-core API boundary and compile against generated types | Deferred: this is an implementation/code-review criterion. Preserve only `MeasurementCore` client-side analysis models. |
| Swift tests have no live-server dependency | Run `swift test --disable-sandbox`; each used endpoint is served by `MockURLProtocol` | Test-phase command is expected to be red only for the missing ranked-results client surface. |
| PR records contract deltas and endpoint gaps | Inspect this record and copy its delta section into the PR description | Recorded below; a PR has not been opened in this tests-only phase. |

## Published-spec deltas and gaps

Evidence inspected from `viamin/color_matching` main at `47057afd58f7d46b4d4b740ca7d2d08947774471`, which contains the OpenAPI endpoint introduced by `viamin/color_matching#110`.

- The published paths cover all six requested routes, including ranked results. This closes the prose contract's endpoint-level gap.
- `Manifest` declares only `schema_version`, `sheet_id`, and `capture_profile.scoring_algorithm_version`, while the iOS app requires geometry, patch, pair, and manifest URL fields. The generated manifest model cannot replace `SheetManifest` until the schema describes those fields.
- `RankedResults` declares only `schema_version` and `sheet_id`; it omits the `results` array and the ranking, score, source-color, judgment, capture, and printer-profile fields emitted by the controller. A typed ranked-results client cannot be generated from the published schema as-is.
- `MeasurementUploadRequest` omits the prose contract's `scoring_algorithm_version` and measurement `stats`; its declared measurement shape only requires patch ID and two RGB payloads. The app currently sends both omitted fields.
- `CaptureRequest` is more permissive than the prose contract: it accepts either legacy flat metadata or nested `metadata`; neither form requires the prose contract's `quality` object. The app uses the nested form with quality.
- The published API returns JSON acknowledgements for measurement and judgment uploads (`capture_id` and counts); the prose contract does not specify those responses, and the current app discards them.
- The OpenAPI document models `recent.title` as required-but-nullable. The prose contract permits null; this is compatible but generated Swift code must represent the field as optional/nullable.

## Implementation handoff

Do not claim this migration complete until the server schema gaps above are resolved or the generated client is configured with explicit, reviewed supplemental schemas. Update `APIClientTests.testGeneratedClientSupportsRankedResultsStubResponse` to call the generated client and remove its deliberate `XCTFail` in the implementation phase.
