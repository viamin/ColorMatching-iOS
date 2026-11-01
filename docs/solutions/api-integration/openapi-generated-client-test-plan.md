---
title: "OpenAPI generated-client migration verification plan"
date: "2026-11-01"
category: "api-integration"
module: "iOS"
problem_type: "test_plan"
component: "ColorMatchingLPSAppCore API client"
tags:
  - "openapi"
  - "swift"
  - "generated-client"
  - "contract-testing"
---

# OpenAPI Generated-Client Migration Verification Plan

This is the red-phase plan for issue #5. The implementation run must preserve
the local `URLProtocol` seam and replace the hand-written request/response
types behind it with generated OpenAPI types.

## Acceptance-criterion map

| Criterion | Smallest credible verification | Current result |
| --- | --- | --- |
| Package uses `swift-openapi-generator` and `swift-openapi-runtime`, with a reviewable v1 specification | `GeneratedOpenAPIConfigurationTests.testPackageDeclaresGeneratedClientDependenciesAndV1Specification` | Red until the implementation vendors/fetches the specification and wires both dependencies. |
| Generated client supports manifest, recent sheets, capture creation, measurement upload, judgment upload, and ranked results | The same configuration test asserts all six v1 operation paths in the vendored specification; implementation must add generated-client local-stub tests for each operation. | Red: no vendored spec or generated client exists. |
| Existing app behavior for manifest lookup and recent sheets remains correct | `APIClientTests.testFetchesManifestAndRecentSheetsFromStubbedResponses` | Not run: the container has no Swift toolchain; expected to be green against deterministic local responses. |
| Generated client is exercised without a live server | Local `URLProtocol` tests in `ColorMatchingLPSAppTests`; extend the existing create/upload tests to invoke generated operations in the implementation run. | Not run: the container has no Swift toolchain. Generated-client coverage is not yet present. |
| PR explains prose-contract versus real-spec deltas and endpoint gaps | Human/external evidence: compare `docs/color-matching-api-contract.md` with the vendored artifact fetched from `viamin/color_matching#110`, then record findings in the PR body. | Not run in this tests-only change. |

## External evidence already checked

`viamin/color_matching#110` is closed and states that the spec is served at
`GET /api/v1/openapi.json`. This repository does not currently vendor that
document, and the current `APIClient` has no ranked-results operation. The
implementation run must fetch or vendor the actual artifact before declaring
the migration complete; this plan intentionally does not infer schema details
from the prose contract.

## Expected contract comparison focus

Compare authentication, nullability, required fields, date-time encoding,
operation IDs, and the six iOS paths. In particular, the prose contract names
ranked results but does not define its response schema, so that endpoint is an
explicit potential gap rather than an assumption to encode in Swift.
