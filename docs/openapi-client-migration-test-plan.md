# OpenAPI client migration test plan (issue #5)

This is the test-writing-phase evidence for replacing the hand-written iOS
client. The implementation run must replace the existing Codable transport
models with generated types, rather than merely adding dependencies alongside
them.

## Criterion verification map

| Criterion | Smallest credible verification | Current evidence/status |
| --- | --- | --- |
| Add generator/runtime and obtain the upstream OpenAPI document | Focused package-configuration test plus a checked-in, version-pinned OpenAPI artifact | `APIClientTests.testPackageDeclaresGeneratedOpenAPIClientDependencies` is red until the packages are declared. The artifact must be reviewed as external evidence. |
| Generate the manifest, recent-sheet, capture, measurement, judgment, and ranked-result surfaces | Compile the generated client and run local-stub tests for every operation | Partial/red: local stubs now cover manifest, recent sheets, capture, measurement, and judgment. Ranked results has no app call yet, so the implementation run must add its generated-client test before claiming this criterion. |
| Replace server API models while retaining client-only models | Compile boundary: app targets import generated request/response types; MeasurementCore remains client-only | Not run: requires the implementation change. |
| Exercise generated client without a live server | Permanent URLProtocol-based Swift tests | `APIClientTests` uses `MockURLProtocol`; no live server is contacted. The implementation run must update these tests to instantiate generated operations/types. |
| Describe prose-contract deltas and endpoint gaps in the PR | Inspectable comparison with upstream `viamin/color_matching#110` source/spec | Recorded below; final wording belongs in the PR description. |

## Upstream contract comparison

External evidence was inspected from `viamin/color_matching` main at issue
`#110`: `ColorMatchingWeb.Router`, `ApiSchemas`, `TestSheetController`,
`CaptureController`, and `TestSheetJSON`.

- All requested paths exist, including `GET /api/v1/test_sheets/{sheet_id}/ranked_results`; the current iOS client has no ranked-results call.
- The prose contract's capture envelope is supported, but the spec also accepts a legacy flat capture form. Capture quality is not required by the published schema.
- The prose contract requires `scoring_algorithm_version` and measurement `stats`; the published measurement schema does not define either. It instead requires both linear and normalized RGB values, permits RGB as an array, object, or JSON string, and accepts score, similarity, or distance for pair scores.
- The prose contract describes complete manifest and ranked-result payloads. The published OpenAPI schemas expose only a required subset: manifest requires `schema_version`, `sheet_id`, and `capture_profile.scoring_algorithm_version`; ranked results requires `schema_version` and `sheet_id`.
- The published write endpoints return `200` JSON summaries for measurement and judgment uploads; the prose contract does not specify responses and the current client accepts an empty `204` response.
- Recent sheet `title` remains nullable as stated in the prose contract.

These are server-spec gaps, not reasons for the client to preserve
hand-written server models. The implementation PR should state whether it
uses generated additional-properties support or a narrow, client-side adapter
for the manifest fields needed by `MeasurementCore`.
