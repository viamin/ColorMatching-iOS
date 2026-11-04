# Issue #5: OpenAPI Swift Client Verification Plan

This document is the run evidence and proposed PR-description content for
issue #5. It is intentionally written before implementation so each acceptance
criterion has a credible, inspectable verifier rather than relying on a broad
suite.

## Criterion map

| Criterion | Smallest credible verification | Evidence at this tests-only head |
| --- | --- | --- |
| Add `swift-openapi-generator` and `swift-openapi-runtime`, and fetch or vendor the server document | A committed `color-matching.openapi.json` parses and declares every companion path. Package resolution and a generated-client compile prove the dependencies are actually wired. | `APIClientTests.testVendoredOpenAPIDocumentDefinesEveryCompanionEndpoint` is red because the source artifact has not been vendored yet. |
| Generate all used surfaces: manifest, recent sheets, capture creation, measurement upload, judgment upload, ranked results | Keep a typed facade around the generated client and run it against `MockURLProtocol` fixtures for every operation. The generated code's compilation is also a drift check. | Existing upload/create fixture tests and `APIClientTests.testFetchManifestAndRecentSheetsDecodeLocalStubResponses`; ranked-results coverage is blocked on the generated facade. |
| Replace hand-written API models while retaining client-only models | Inspect the diff: `APIClient.swift` must contain adapters only, while request/response API schema types originate in generated sources. Compile the app target. | Not runnable in the tests-only phase. |
| Swift tests use local stubbed responses, not a live server | `MockURLProtocol` assertions validate request paths/payloads and decode deterministic fixtures. | `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift`; no test opens a network connection. |
| PR records prose-contract versus published-spec deltas and endpoint gaps | Human/external review against `viamin/color_matching#110`, the served `/api/v1/openapi.json`, and this delta record. | Deltas below; runtime JSON could not be fetched in this isolated environment because the deployment hostname is not published in the repository. |

## Published-spec evidence

`viamin/color_matching#110` closed on 2026-10-30 and states that the
machine-readable document is served at `GET /api/v1/openapi.json`. The upstream
router at that revision declares all six iOS routes:

- `GET /api/v1/test_sheets/recent`
- `GET /api/v1/test_sheets/:sheet_id/manifest`
- `GET /api/v1/test_sheets/:sheet_id/ranked_results`
- `POST /api/v1/test_sheets/:sheet_id/captures`
- `POST /api/v1/captures/:capture_id/measurements`
- `POST /api/v1/captures/:capture_id/judgments`

The implementation PR must download the served document from a known deployment
or vendor a snapshot whose source URL and SHA-256 are recorded beside it. The
red vendoring test is the guard that makes this missing dependency visible.

## Contract deltas and endpoint gaps found

The prose contract is richer than the OpenAPI schema modules merged by upstream
issue #110. These are not guesses about server behavior; they are gaps in what
the published machine-readable schema currently promises to generated clients.

- The manifest schema requires only `schema_version`, `sheet_id`, and
  `capture_profile.scoring_algorithm_version`. The prose contract additionally
  describes sheet/version URLs, page geometry, markers, printer profile,
  patches, and pairs. A generated client will therefore model most of the
  manifest as unconstrained or absent unless the served document has been
  expanded after the upstream source review.
- The ranked-results schema requires only `schema_version` and `sheet_id`.
  The prose contract expects source colors, scores, labels, capture provenance,
  printer profile, and scoring algorithm version. This is the most important
  endpoint gap because the app has no ranked-results client method today.
- The published measurement-upload schema does not require
  `scoring_algorithm_version`, permits RGB in multiple compatibility formats,
  and does not describe the prose contract's nested `stats` object. It does
  support `distance` as a compatibility pair-score input.
- Capture creation remains intentionally backward-compatible: the published
  schema accepts both flat and nested request bodies, while the iOS prose
  contract specifies the nested `metadata` plus `quality` body.
- The published write endpoints document response objects for measurement and
  judgment uploads (`capture_id` and counts), whereas the hand-written iOS
  client currently discards successful response bodies. The generated adapter
  should decide explicitly whether those acknowledgements are retained.
- The prose contract constrains capture rejection and judgment vocabularies;
  the upstream schemas currently model them as unconstrained strings.

Before merging implementation, re-fetch the real served JSON and update this
record if it differs from the upstream source modules above. Any missing
ranked-result fields should either be added upstream or documented as a
generation limitation; it must not be silently represented as a complete typed
model.
