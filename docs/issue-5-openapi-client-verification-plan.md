# Issue #5 OpenAPI Client Verification Plan

This document is the test-plan and PR-description input for replacing the iOS
hand-written API layer. It was prepared before implementation in the
tests-only phase.

## Acceptance criteria and verification

| Criterion | Smallest credible verification | Evidence at this head |
| --- | --- | --- |
| Fetch or vendor the upstream OpenAPI document and configure `swift-openapi-generator`/runtime | The permanent Swift test loads the vendored document and requires all six application paths. Package dependency and generated-source configuration require code review plus a green build in the implementation phase. | `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift:testVendoredOpenAPIDocumentDeclaresEveryCaptureFlowEndpoint` (intentionally red until the document is vendored) |
| Generate typed operations for manifest, recent sheets, capture creation, measurement upload, judgment upload, and ranked results | Local `URLProtocol` stubs exercise the app-facing client methods for the existing five used operations; the vendored-document test requires the ranked-results operation in the generation input. Add a typed ranked-results call when the generated type names are available. | `APIClientTests.swift:testFetchManifestDecodesStubbedPublishedResponse`, `testFetchRecentSheetsDecodesStubbedPublishedResponse`, `testCreateCaptureEncodesMetadataAndQuality`, `testUploadMeasurementsEncodesScoresWithAlgorithmVersion`, `testUploadJudgmentsEncodesPathAndPayload`, and the intentionally red vendored-document test |
| Replace hand-written server API models while retaining client-only models | Compile the app and its existing camera/measurement flow after the generated client replaces the hand-written transport models. This is implementation-phase compile evidence, not something a test name can prove. | Not run in this tests-only phase |
| Test generated client with local stubbed responses | The permanent capture-flow API boundary suite uses `URLProtocol`, has no live-server dependency, and supplies published-contract JSON responses. | `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift` |
| Record contract deltas and endpoint gaps in the PR description | The upstream controller and schema source is inspectable external evidence; the deltas below must be copied into the implementation PR description and reconciled against the fetched JSON. | Manual PR evidence required |

## Published-spec contract deltas found

The upstream issue is closed and its `ColorMatchingWeb.ApiSpec` dynamically
builds the document that it serves at `GET /api/v1/openapi.json`; it does not
check a JSON/YAML document into the provider repository. The implementation
must fetch that endpoint from the configured provider deployment or vendor an
exported response, then pin its source/revision.

- The prose manifest includes `created_at`, `printer_profile`, and
  `capture_profile` detail. The published `Manifest` schema currently requires
  only `schema_version`, `sheet_id`, and
  `capture_profile.scoring_algorithm_version`; the other response fields are
  not machine-described.
- The prose capture payload nests `metadata` and `quality`. The published
  schema accepts that nesting but also permits a legacy flattened payload, and
  makes only a subset of metadata required.
- The prose measurement payload requires `scoring_algorithm_version` and
  per-measurement `stats`. The published measurement schema describes neither;
  it requires normalized RGB data and allows multiple RGB representations.
- The prose says both upload endpoints succeed without defining bodies. The
  published spec defines 200 acknowledgement bodies with `capture_id` and
  counts, rather than the currently assumed 204/no-content response.
- The prose ranked-results endpoint has only a narrative response. The
  published schema currently requires only `schema_version` and `sheet_id`,
  while the server renderer returns rankings, aggregate scores, provenance,
  printer profile, and judgments. This is an endpoint-schema gap that must be
  resolved before a useful strongly typed ranked-results client can be
  generated.
- The published manifest schema documents a `lps-sheet-manifest/v1` enum and
  distance algorithm `lps-distance-v1`; ranked results add
  `lps-ranked-results/v1`, which is absent from the prose contract.

## Test execution status

The container has no `swift` executable, so `swift package resolve` and
`swift test --disable-sandbox` cannot run here. The tests remain intentionally
red until the implementation phase vendors the OpenAPI document. Lint is the
repository-specified `echo "No lint command configured"` command.
