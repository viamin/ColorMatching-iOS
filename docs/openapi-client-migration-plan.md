# OpenAPI Generated Client Migration — Verification Plan And Blocker Report

Tracks issue #5, "Replace hand-written API layer with a generated OpenAPI Swift client." This is a test-writing-phase record: it maps each acceptance criterion to its smallest credible verification and reports why no implementation or test code was added in this run.

## Acceptance Criterion → Verification Mapping

| Deliverable | Smallest credible verification | Status this run |
| --- | --- | --- |
| Add `swift-openapi-generator` + `swift-openapi-runtime`; fetch or vendor the OpenAPI document from viamin/color_matching#110 | Inspect `iOS/Package.swift` for the two package dependencies and a vendored `openapi.yaml`/`openapi.json` sourced from the real spec | Blocked — see below |
| Generate the client for manifest/recent-sheets/capture/measurement/judgment/ranked-results surfaces | Build output under `.build/plugins/.../GeneratedSources` contains `Types.swift`/`Client.swift` covering those operation IDs | Blocked — depends on prior row |
| Replace hand-written API models with generated types; keep client-only models as-is | Diff of `iOS/Sources/ColorMatchingLPSAppCore/APIClient.swift` shows request/response structs removed in favor of generated `Components.Schemas.*` / `Operations.*` types | Blocked — depends on prior rows |
| Swift tests exercising the generated client against local stubbed responses | `iOS/Tests/ColorMatchingLPSAppTests/*.swift` using a stub `ClientTransport` (no live server) | Blocked — depends on prior rows |
| PR description records prose-contract vs. published-spec deltas and endpoint gaps | Manual diff of `docs/color-matching-api-contract.md` against the vendored spec, written into the PR body | Blocked — the real spec was never obtained, so no diff exists yet |

## Blocker

This run cannot produce the generated client, so it cannot produce tests that exercise it either, for two independent, verified reasons:

1. **The dependency (viamin/color_matching#110) is not reachable from this sandbox.** The GitHub API proxy available here (`$GITHUB_API_URL`) is scoped to this repository only:

   ```
   $ curl "$GITHUB_API_URL/repos/viamin/color_matching/issues/110" ...
   {"error":"Repository mismatch"}
   ```

   There is no other network path to viamin/color_matching from this environment, so the published OpenAPI document cannot be fetched or vendored here. Fabricating a stand-in spec from `docs/color-matching-api-contract.md` would defeat the point of the issue — the generated client would validate against hand-authored assumptions instead of the real server contract, silently reintroducing the exact drift risk this migration exists to eliminate.

2. **No Swift toolchain is available in this sandbox** (`swift --version` → `command not found`). `swift-openapi-generator` is a SwiftPM build plugin; nothing that depends on it — adding it to `Package.swift`, vendoring the spec, or writing tests against its generated output — can be compiled or run here to confirm correctness. CI (`.github/workflows/ci.yml`) runs this on `macos-latest`; that step is unavailable locally.

Given the TDD-boundary rule for this run (test/doc paths only, implementation changes rejected at commit) and the ban on treating compile/syntax failures as valid red-phase evidence: adding a test file that references not-yet-generated types (`Operations.*`, `Components.Schemas.*`, a generated `Client`) would fail the whole-package build — not a targeted assertion failure — and would take the currently-green `MeasurementCoreTests`/`ColorMatchingLPSAppTests` suites down with it. That is a syntax/infrastructure failure, explicitly excluded from permitted red-phase evidence, so no such test was added.

## What Is Verifiable Today

The existing hand-written contract and its coverage remain accurate and unaffected:

- `docs/color-matching-api-contract.md` — current prose contract, unchanged.
- `iOS/Sources/ColorMatchingLPSAppCore/APIClient.swift` — current hand-written client, unchanged.
- `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift` — existing coverage of capture creation, measurement upload, and judgment upload request encoding against a mocked `URLProtocol`, unchanged and still green.

## Recommended Next Steps Once Unblocked

1. Obtain the real OpenAPI document published by viamin/color_matching#110 (via a session with network/cross-repo access, or by vendoring a copy supplied directly by the user) and commit it under `iOS/` alongside an `openapi-generator-config.yaml`.
2. Diff the vendored spec against `docs/color-matching-api-contract.md`; record every field/endpoint/enum delta.
3. Add `swift-openapi-generator` + `swift-openapi-runtime` to `iOS/Package.swift`, wire the plugin, and confirm `swift test` builds the generated sources on a machine with a Swift toolchain (or `macos-latest` CI).
4. Only then write/port the stubbed-transport tests described in the table above, and replace the hand-written models in `APIClient.swift`.
5. Carry the contract-delta list from step 2 into the PR description, per the issue's exit criteria.
