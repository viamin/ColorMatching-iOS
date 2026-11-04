# OpenAPI client migration test plan

This records criterion-level verification for issue #5 before the implementation
run. The permanent Swift tests use `MockURLProtocol`; they make no live server
request and therefore run in CI.

| Criterion | Smallest credible verification | Status in this tests-only change |
| --- | --- | --- |
| Generated client dependencies and checked-in/fetched OpenAPI document | Inspect `iOS/Package.swift`, the vendored/fetch script, and generated target after implementation | Not run — implementation-owned |
| Generated operations for manifest, recent sheets, capture creation, measurement upload, judgment upload, and ranked results | Compile the generated target and exercise each operation against `MockURLProtocol` stubs | Not run — ranked-results facade and generated target do not exist yet |
| Replace hand-written API models while retaining client-only models | Source inspection plus the focused client tests after the wrapper is rewired | Not run — implementation-owned |
| Stubbed generated-client tests | `APIClientTests` covers manifest and recent-sheet response decoding, plus capture, measurement, and judgment requests; the implementation run must add ranked-results coverage through the generated client | Partially covered |
| Contract deltas in the PR description | Human inspection of the PR body against the published `/api/v1/openapi.json` contract | Not run — external/human evidence required |

## Published-contract deltas found before implementation

- Manifest responses include `created_at`, `printer_profile`, and `capture_profile`.
  The current `SheetManifest` drops those fields, so the generated client must
  preserve them or explicitly map the app's required subset.
- The prose contract's printer profile sample uses `id`, `name`, `paper`, `ink`,
  and `settings`; the server publishes `printer_make_model`, `paper_type`,
  `ink_type`, plus optional ICC, driver, calibration, and notes fields.
- Successful measurement and judgment uploads return JSON acceptance payloads
  with the capture ID and accepted counts. The current hand-written client
  discards their bodies.
- Ranked results are available as `lps-ranked-results/v1`, including aggregate
  score, observation, capture-provenance, and printer-profile data. The app
  currently has no API facade or UI consumer for this endpoint.
- Server capture identifiers are decimal strings. The current client accepts a
  string, which is compatible.
