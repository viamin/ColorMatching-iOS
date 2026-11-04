# OpenAPI Client Migration Evidence

This file supplies the PR evidence for issue #5 while the work is split into a
tests-only run followed by an implementation run. The implementation run must
replace this status with the actual generated-client result before merge.

## Acceptance criteria and verification plan

| Criterion | Smallest credible verification | Current status |
| --- | --- | --- |
| Vendor the OpenAPI document and generate the Swift client | `APIClientTests.testVendoredOpenAPISpecDeclaresEveryCompanionOperation` checks the checked-in document contains exactly the six app operations. A regeneration command in the implementation PR must produce no diff. | Red: `iOS/OpenAPI/color-matching-api.json` is not yet vendored. |
| Wire generated types for manifest, recent sheets, capture creation, measurement and judgment upload, and ranked results | Local-stub client tests exercise each operation; compile-time use of generated operation/input/output types is the drift detector. | Not yet implemented. The existing local-stub tests cover five current hand-written wrapper operations; ranked results has no app API method. |
| Preserve client-only measurement and scoring models | Focused `MeasurementCoreTests` remain the regression suite. | Existing coverage; implementation-run verification required. |
| No live server in CI | `MockURLProtocol` responds to all API-client tests, including the newly added manifest and recent-sheet tests. | Covered for the existing wrapper. |
| Record prose-contract deltas and endpoint gaps | Human review of this document against the upstream published artifact, pinned to its commit or checksum. | Blocked pending a fetchable published artifact. |

## Upstream artifact check — 2026-11-04

`viamin/color_matching#110` is closed, and its issue says the server should
serve `GET /api/v1/openapi.json`. The default branch does not contain an
OpenAPI/Swagger artifact that this repository can vendor, and no public
deployed base URL is recorded in the issue. Consequently this repository
cannot truthfully record differences between the prose contract and the real
machine-readable document yet.

The implementation run must fetch the response from the server endpoint (or
vendor an immutable upstream file) and record its source URL, revision or
SHA-256, and the concrete deltas below.

## Required delta review

Compare `docs/color-matching-api-contract.md` to the fetched OpenAPI document
for these known-risk areas:

- The prose contract leaves the `ranked_results` response undefined, so this
  endpoint is an existing client gap until the published schema specifies it.
- Confirm the exact enum wire values for capture rejections and judgments;
  generated Swift names may differ but JSON values must not.
- Confirm required versus nullable fields in capture metadata, manifest
  profiles, measurement payloads, pair scores, and recent-sheet titles.
- Confirm response status codes and error schemas for all six operations.
- Confirm whether authentication is mandatory for every operation; the prose
  contract allows unauthenticated development access but does not encode a
  security requirement.

## Test fixture convention

The implementation must vendor the source document as
`iOS/OpenAPI/color-matching-api.json`. Each of these required operations must
have a non-empty `operationId`, which is asserted by the tests:

- `GET /api/v1/test_sheets/{sheet_id}/manifest`
- `GET /api/v1/test_sheets/recent`
- `POST /api/v1/test_sheets/{sheet_id}/captures`
- `POST /api/v1/captures/{capture_id}/measurements`
- `POST /api/v1/captures/{capture_id}/judgments`
- `GET /api/v1/test_sheets/{sheet_id}/ranked_results`

Record the upstream operation-ID-to-generated-Swift-surface mapping in the
implementation PR. Do not silently infer operations from paths in production
code.
