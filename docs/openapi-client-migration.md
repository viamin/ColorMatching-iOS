# OpenAPI client migration: acceptance plan and contract deltas

This document is the PR-description source for issue #5. It was prepared in
the tests-only phase; implementation must update the verification results
after wiring the generated client.

## Acceptance-criterion plan

| Criterion | Smallest credible verification | Location/status in this phase |
| --- | --- | --- |
| Add generator/runtime and vendor the server document | Permanent unit test reads the vendored document and asserts all six operations exist. | `APIClientTests.testVendoredOpenAPISpecDeclaresEveryCompanionOperation` — red until the document is vendored. |
| Generate and wire manifest, recent sheets, capture, measurement, judgment, and ranked-results operations | Compile the generated target and run the focused URLProtocol suite. The suite must invoke the generated-client-backed app adapter, not a live server. | Existing write-operation stubs plus `testFetchManifestAcceptsThePublishedMinimumResponse` and `testFetchRecentSheetsDecodesAStubbedResponse`; ranked-results stub must be added with the generated operation in the implementation phase. |
| Remove hand-written API transport models while retaining client-only measurement models | Source review of `APIClient.swift` and generated target, plus a successful Swift compile. | Human/code-review evidence required after implementation. |
| Exercise generated client with local stubbed responses | Focused permanent XCTest URLProtocol tests. | `APIClientTests.swift`; no external server is contacted. |
| Record prose-contract deltas and endpoint gaps | Inspect the upstream #110 OpenAPI source and the vendored JSON, then record the reconciled result in the PR description. | Findings below; requires implementation-time confirmation against the exact vendored JSON. |

## Upstream evidence inspected

- `viamin/color_matching` issue #110 was closed by PR #113 at commit
  `094bd6d3443ddacbda7e63354299867eb5bdfa9f`.
- Its controller declares all required companion routes: manifest, recent
  sheets, capture creation, measurement upload, judgment upload, and ranked
  results.
- The server exposes the document at `GET /api/v1/openapi.json`. The document
  must be fetched from that endpoint and committed as
  `iOS/OpenAPI/color-matching-openapi.json` (or the test updated to the chosen
  stable vendored location) so generation is reproducible in CI.

## Contract deltas found before implementation

1. The prose manifest example requires page geometry, markers, patches, pairs,
   printer profile, and capture profile. The published `Manifest` OpenAPI
   schema currently requires only `schema_version`, `sheet_id`, and
   `capture_profile.scoring_algorithm_version`. Generated manifest models will
   therefore not promise the fields the app needs to analyze a sheet.
2. The prose contract describes ranked results as containing source colors,
   scores, labels, capture provenance, printer profile, and scoring algorithm
   version. The published `RankedResults` schema currently requires only
   `schema_version` and `sheet_id`; this is an endpoint-schema gap that needs
   server follow-up before the iOS app can safely consume typed ranked results.
3. The prose measurement request includes top-level
   `scoring_algorithm_version` and per-measurement `stats`. The published
   `MeasurementUploadRequest` documents only measurements and pair scores; its
   measurement items require normalized and unnormalized RGB payloads, and its
   pair scores require `algorithm_version` plus one of `score`, `similarity`,
   or `distance`. The generated request must follow the published contract,
   and any needed statistics/version fields need a server-spec decision.
4. The prose contract says measurement and judgment uploads return `204`; the
   published spec declares `200` JSON acknowledgement bodies containing the
   capture ID and accepted row count. The app adapter should decode those
   generated responses.
5. The published capture request supports both a legacy flat shape and the
   prose nested `metadata` shape. Its `CaptureMetadata` requires image width
   and height, which are optional in the current hand-written Swift model.
   The app must provide them before using the generated request.

## Endpoint gaps

The server routes are present, but the manifest and ranked-results schemas are
not sufficiently complete for the client behavior described by the prose
contract. This is not resolvable by client generation alone. The implementation
PR must either link a server issue for schema expansion or explicitly limit the
generated surface to fields the published schema guarantees.
