# Issue #5 OpenAPI Client Verification Plan

## Scope and evidence map

| Criterion | Smallest credible verification | Current evidence / status |
| --- | --- | --- |
| Add `swift-openapi-generator` and `swift-openapi-runtime`, and vendor or fetch the API document | Inspect `iOS/Package.swift` and the checked-in OpenAPI input after implementation; run `swift package resolve` | Not run: the upstream document from `viamin/color_matching#110` was not available to this test-writing run. |
| Generate the manifest, recent-sheets, capture, measurement-upload, judgment-upload, and ranked-results surfaces | Compile the generated client, then exercise each operation with a `URLProtocol` stub | Permanent stubs exist for the five operations currently exposed by `APIClient`; ranked-results has no client operation or response schema yet. |
| Replace hand-written API models while retaining client-only models | Code review of `ColorMatchingLPSAppCore` and compile the app against generated operation/input/output types | Not run: implementation phase. `MeasurementCore` analysis models are explicitly client-side and remain out of scope. |
| Test the generated client without a live server | `swift test --disable-sandbox`, using the `MockURLProtocol` stubs in `APIClientTests` | The stubs cover request paths, bearer auth, request bodies, and decoding for the existing five API operations. They must be updated to instantiate the generated client/types in implementation. |
| Record prose-contract deltas and endpoint gaps in the PR | Compare the vendored OpenAPI input byte-for-byte/semantically to `docs/color-matching-api-contract.md`; include results in the PR body | Blocked pending the published OpenAPI document. See the known gaps below. |

## Permanent local-stub coverage

`iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift` is the permanent
integration boundary for this change. It never contacts a live server: a
`URLProtocol` intercepts the request and returns fixture responses.

- `testFetchManifestDecodesStubbedManifestAndSendsBearerToken`
- `testFetchRecentSheetsDecodesStubbedResponse`
- `testCreateCaptureEncodesMetadataAndQuality`
- `testUploadMeasurementsEncodesScoresWithAlgorithmVersion`
- `testUploadJudgmentsEncodesPathAndPayload`

The implementation phase must preserve these behavioral assertions while
making the test construct the generated client and generated request/response
types. Add a sixth analogous stub test when the OpenAPI document defines the
ranked-results response.

## Known contract and endpoint gaps before the upstream comparison

- The prose contract names `GET /api/v1/test_sheets/:sheet_id/ranked_results`
  but deliberately omits a response JSON schema. A generated Swift output type
  and a meaningful stub response cannot be specified until #110 supplies it.
- The iOS app currently calculates/display ranks locally and uploads pair scores;
  it has no `ranked_results` call. The generated-client migration needs an
  explicit integration decision for that endpoint, without changing capture or
  scoring behavior.
- The prose manifest example includes `created_at`, `printer_profile`, and
  `capture_profile`, while `MeasurementCore.SheetManifest` does not model them.
  The published document must decide whether those fields are required,
  optional, or intentionally excluded from the mobile surface.
- The prose contract lists allowed capture rejection and judgment values as text
  rather than a machine-readable enum. Compare the spec's enum values and wire
  spelling during implementation.
- The upstream GitHub API returned a rate-limit response on 2026-10-31 in this
  environment, so this run has no inspectable copy of #110 to compare. This is
  external evidence pending, not evidence that the contracts match.

## Implementation exit evidence

Before opening the implementation PR, update this file and
`tmp/paid-agent-verification.json` with:

1. the exact OpenAPI document source, revision, and vendored path or fetch URL;
2. the generated sources/configuration and package dependency revisions;
3. a concrete response fixture and permanent stub test for every generated
   operation, including ranked results; and
4. the observed prose-to-spec delta list, including each endpoint absent from
   either source.
