---
module: iOS/ColorMatchingLPSAppCore
tags: [openapi, code-generation, api-client, testing]
problem_type: migration-plan
---

# OpenAPI Generated Client Migration — Test-First Contract (Issue #5)

Status: **red phase (tests-first)**. This document pins the contract that the
implementation run must satisfy to turn the committed tests green, records the
acceptance-criterion → verification mapping, and captures the contract deltas
and endpoint gaps discovered while comparing the app's hand-written API layer
against `docs/color-matching-api-contract.md`. It is the source material for
the migration PR description.

## Pinned implementation contract

The tests committed in this phase (`iOS/Tests/ColorMatchingLPSAppTests/`)
intentionally fail to compile until the implementation run lands the following.
Every name below is pinned by a test; the implementation must match it.

### Package layout

| Item | Pinned value |
| --- | --- |
| Generated module name | `ColorMatchingOpenAPI` (SwiftPM `openapi-generator` target) |
| Vendored spec path | `iOS/OpenAPI/color-matching.yaml` (fetched from viamin/color_matching#110 during implementation) |
| Runtime dependency | `swift-openapi-runtime` (`OpenAPIRuntime` product), also added to the `ColorMatchingLPSAppTests` target |
| Generator | `swift-openapi-generator` plugin invoked from the `ColorMatchingOpenAPI` target |

Pinned by `OpenAPIClientCanaryTests.swift`: the generated module must expose a
public `Client` initializable with `serverURL:` + any `ClientTransport`, and
the runtime must expose `URLSessionTransport(configuration: .init(session:))`
so stubbed `URLSession`s can be injected (that is how every contract test
stubs responses without a live server).

### Facade surface (`ColorMatchingLPSAppCore.APIClient`)

`APIClient` stays the app's facade; its internals are replaced by the
generated client. Existing public signatures (already pinned by
`APIClientTests.swift`, which must keep passing unchanged) are retained:

- `init(token: String?, session: URLSession)` — the injected session must be
  routed into the generated client's transport so `URLProtocol` stubs work.
- `fetchManifest(from:)`, `fetchManifest(baseURL:sheetCode:)`,
  `fetchRecentSheets(baseURL:)`, `createCapture(sheetID:baseURL:metadata:quality:)`,
  `uploadMeasurements(captureID:baseURL:measurements:scores:)`,
  `uploadJudgments(captureID:baseURL:judgments:)`

New members pinned by `OpenAPIClientContractTests.swift`:

- `fetchRankedResults(sheetID:baseURL:) async throws -> RankedResults` with
  `RankedResults.scoringAlgorithmVersion: String` and `RankedResults.pairs:
  [RankedPairResult]`; `RankedPairResult` exposes `pairID`, `sourceColors:
  [String]`, `distance`, `similarity`, `label: String?`, `captureID: String?`.
- `APIError.unauthorized` — a 401 response must surface as this case (distinct
  typed error per failure mode; matches the repo error-handling style).

### Model replacement rules

- API-only hand-written Codable models (`RecentSheet`,
  `CaptureSessionResponse`, the private upload request DTOs in
  `APIClient.swift`) are replaced by generated types; the facade maps them to
  view-facing structs that keep the exact member names the tests and
  `ContentView` use (`sheetID`, `manifestURL`, `title`, `captureID`).
- `CaptureMetadata` / `WhiteBalanceGains` remain facade input types (they
  describe client-side camera state); their **wire encoding** must come from
  generated request schemas, not the hand-written encoder.
- Purely client-side models in `MeasurementCore` (`SheetManifest`, `Patch`,
  `PairManifest`, `PatchMeasurement`, `ChannelStats`, `PairScore`,
  `CaptureQuality`, `CaptureRejection`) stay as-is; the facade decodes
  generated manifest/measurement types and maps into them.
- `PairJudgment` stays the facade input for judgment upload (member names
  `pairID`, `judgment`).

## Contract deltas and endpoint gaps (prose contract → generated client)

These were discovered writing the tests and must be re-verified against the
**published spec** (viamin/color_matching#110) during the implementation run;
the PR description must record the final list.

1. **Upstream spec not reachable from the authoring environment.** The GitHub
   proxy in this environment only serves this repository
   (`{"error":"Repository mismatch"}` for `viamin/color_matching`). The spec
   must be fetched/vendored during the implementation run; until then the
   generated-type test fixtures are derived from the prose contract only.
2. **Ranked results: prose has no schema.** The contract describes
   `GET /api/v1/test_sheets/:sheet_id/ranked_results` in prose only ("source
   colors, scores, labels, capture provenance, printer profile, and scoring
   algorithm version"). The app never implemented it (endpoint gap — no
   `rankedResults` method exists today). The test fixture
   (`rankedResultsJSON`) is a provisional shape; reconcile with the published
   spec and record the delta.
3. **Direct manifest URL fetch is now template-bound.** `fetchManifest(from:)`
   previously accepted any URL. A generated operation can only express
   `/api/v1/test_sheets/{id}/manifest` against the URL's origin, so arbitrary
   cross-origin manifest URLs (e.g. a CDN JSON file) are no longer
   representable. The test pins the template-shaped form. Behavior narrowing
   to note in the PR description.
4. **Content negotiation headers appear on the wire.** The generated client
   sends `Accept: application/json` and requires stubbed responses to carry
   `Content-Type: application/json` (tests assert the former and set the
   latter). The prose contract never mentions either header.
5. **Response status codes are unspecified in prose.** Tests pin 200 (fetches),
   201 (capture creation), 204 (uploads). The published spec must document
   these exact codes or the generated client will treat responses as
   undocumented and the tests will rightly fail (drift made visible — the
   point of this migration).
6. **Stats upload schema is a subset of `ChannelStats`.** The upload payload
   carries only `sample_count`, `clipping_fraction`, `mean`,
   `standard_deviation`; the client-side `median`, `min`, `max` fields never
   leave the device. Tests pin the exact key set.
7. **Manifest fields parsed but unused by the app.** `created_at`,
   `printer_profile`, `capture_profile`, `registration_markers.shape/role`,
   `safe_inset_mm`, `reference_role` are all in the contract's example but
   ignored by the current client model. Generated types will parse them; the
   facade currently drops them. Note in the PR description (future feature
   surface).
8. **Timestamp wire format.** Hand encoder used `iso8601` without fractional
   seconds; the OpenAPI runtime encodes `format: date-time` per RFC 3339
   (fractional seconds allowed). The test only asserts a timestamp string is
   present; the server must accept RFC 3339. Delta to confirm against the
   spec's `date-time` handling.
9. **Auth.** Prose allows unauthenticated development requests; tests pin
   `Authorization: Bearer <token>` on every surface (including GETs), which
   the generated client must emit when a token is configured.

## Acceptance-criteria → verification mapping

| AC (issue #5) | Verification kind | Evidence at this head |
| --- | --- | --- |
| Generator + runtime added; spec fetched/vendored | Compile-time canary test | `iOS/Tests/ColorMatchingLPSAppTests/OpenAPIClientCanaryTests.swift` (red: module absent) |
| Generated client for manifest, recent sheets, capture creation, measurement upload, judgment upload, ranked results | Stubbed-response unit tests | `OpenAPIClientContractTests.swift` — one test per surface + direct-URL manifest |
| Hand-written API models replaced; client-side models kept | Same tests: wire-format key-set assertions + decode into client models | `OpenAPIClientContractTests.swift` (create-capture/measurements/judgments key sets; manifest mapping) plus existing `APIClientTests.swift` regression net |
| Swift tests against local stubbed responses (no live server) | Permanent unit/service tests (URLProtocol stubs) | All tests above; no network I/O |
| PR description records contract deltas + endpoint gaps | Human/external evidence | This document, "Contract deltas" section (to be finalized against the published spec and copied into the PR description) |
| Exit: `swift test --disable-sandbox` green | Automated suite | Deferred to implementation run (red phase by design) |

## Red-phase failure inventory (expected)

At this commit the `ColorMatchingLPSAppTests` target does not compile. That is
the intended red-phase signal; each missing symbol maps to deliverable work:

- `import ColorMatchingOpenAPI` / `import OpenAPIRuntime` — modules absent
  until the package declares generator + runtime and the spec is vendored.
- `APIClient.fetchRankedResults` — ranked-results surface (gap #2).
- `RankedResults` / `RankedPairResult` — facade types for the new surface.
- `APIError.unauthorized` — typed auth-error surface.
- After implementation: any stub/response shape mismatch (status codes,
  header, key-set assertions) is a contract-drift failure by design; the
  implementation run resolves it by aligning the vendored spec and recording
  the delta, not by weakening the tests.

## Environment constraints observed while writing tests

- No Swift toolchain exists in the authoring container (`swift: command not
  found`), so tests were validated by review only; CI (macOS, `swift test`)
  is the executor.
- No database or live server is required by any committed test.
