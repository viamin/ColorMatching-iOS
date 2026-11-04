# Issue #5: OpenAPI client test plan and PR evidence

## Criterion map

| Criterion | Smallest credible verification | Initial status |
| --- | --- | --- |
| Add the generator/runtime and vendor or fetch the OpenAPI document | `APIClientTests.testGeneratedClientInputsAreCheckedIn` checks that both package dependencies and the vendored document exist. | Failing (red phase): neither dependency nor document is present. |
| Generate and wire every app API surface | Local `URLProtocol` fixture tests cover manifest, recent sheets, capture creation, measurement upload, and judgment upload. Add a ranked-results fixture after the generated operation is exposed. | Partial: the existing app has no ranked-results client operation. |
| Replace API models with generated types | Compile the app and the fixture tests after the generated package target replaces the current request/response types. | Not run: implementation is intentionally outside this tests-only phase. |
| Exercise the generated client without a live server | The permanent `URLProtocol` unit tests in `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift` own the request/response fixtures. Move these calls to the generated operation methods during implementation. | Partial: fixtures now cover five current operations; generated client is absent. |
| Record prose-contract deltas and endpoint gaps | Inspect the published provider contract and retain the results below in the PR description. | Complete external inspection; implementation follow-up required. |

## Provider evidence and contract deltas

The provider implementation merged [viamin/color_matching#113](https://github.com/viamin/color_matching/pull/113), which closes #110 and serves the document at `GET /api/v1/openapi.json`. Its contract is generated at runtime, so this repository must vendor a fetched, revision-pinned JSON document (or make fetching deterministic) before Swift generation.

Compared with `docs/color-matching-api-contract.md`, the published contract differs materially:

- The manifest schema guarantees only `schema_version`, `sheet_id`, and `capture_profile.scoring_algorithm_version`; the prose document describes additional manifest fields that are not machine-required.
- `RecentSheetsResponse.title` is required but nullable in the spec; the prose says it may be null, but does not make presence explicit.
- Capture input supports both the prose nested `metadata`/`quality` shape and a legacy flat shape. It requires only nested `metadata` (or the flat required fields); quality fields are not required.
- The spec models `iso` as an integer, unlike the app's `Float`, and requires positive image dimensions when supplied.
- Measurement uploads do not require `scoring_algorithm_version` or `stats`; pair scores require `algorithm_version` and exactly one of `score`, `similarity`, or `distance`. The prose requires all of the app's richer payload fields.
- Measurement and judgment uploads return 200 JSON count responses, whereas the prose and current client tests accept 204 with no body.
- The ranked-results response guarantees only `schema_version` (`lps-ranked-results/v1`) and `sheet_id`. The prose's promised rankings, scores, labels, provenance, printer profile, and algorithm version are not yet modeled by the published response schema.

## Endpoint gap to resolve in implementation

The app currently has no `ranked_results` operation or model, despite the documented route and the provider spec endpoint. The implementation PR must generate and expose that operation, then add its local fixture test. It should not invent a rich result model until the provider spec declares one.

## Commands and evidence

- Dependency-resolution attempt: `swift` is not installed in this container, so `swift package resolve` and `swift test --disable-sandbox` cannot run here.
- Lint command configured by the task: `echo "No lint command configured"`.
- Test command configured by the task: `echo "No test command configured"`.

This file supplies the required PR-description material and makes the red-phase boundary explicit; it is not a substitute for the implementation PR's generated client or its green test evidence.
