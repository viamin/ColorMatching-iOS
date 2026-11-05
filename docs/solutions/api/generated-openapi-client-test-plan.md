---
module: iOS API client
tags: [openapi, swift, contract-testing]
problem_type: test-plan
---

# Generated OpenAPI client verification plan

Issue #5 is in its tests-only phase. The tests deliberately establish the
minimum acceptance contract before implementation:

| Criterion | Smallest credible verification | Status in this phase |
| --- | --- | --- |
| Generator, runtime, and a vendored/fetched spec are configured | `GeneratedClientConfigurationTests.testPackageConfiguresOpenAPIGeneratorRuntimeAndGenerationPlugin` inspects the package manifest | Red: no generated-client package configuration exists yet |
| Manifest and recent-sheet reads work against a local response | `APIClientTests.testFetchManifestDecodesStubbedManifest` and `APIClientTests.testFetchRecentSheetsDecodesStubbedResponse` | Green characterization coverage; implementation must switch these calls to generated types |
| Create capture, upload measurements, and upload judgments work against local responses | Existing `APIClientTests` request/response tests | Green characterization coverage; implementation must switch the request types to generated types |
| Ranked results are generated and wired into the app | Unit test using a local stubbed ranked-results response, to be added with the generated operation | Not runnable until the generated operation and server schema are available |
| Contract deltas are captured in the PR | Human inspection of the fetched `GET /api/v1/openapi.json` artifact against `docs/color-matching-api-contract.md` | Pending implementation PR evidence |

## Published-server deltas found from the authoritative server source

The published API adds concrete response bodies for successful measurement and
judgment uploads (`capture_id` plus counts); the prose contract incorrectly
models both as `204 No Content`. Ranked results are no longer an unspecified
description: they have schema version `lps-ranked-results/v1`, aggregation
metadata, score statistics, observations, and capture provenance. The manifest
printer profile also uses printer metadata fields rather than the prose
contract's `id` and `name`. These deltas must be confirmed against the vendored
OpenAPI JSON during implementation, rather than treating this prose document as
the source of truth.
