# OpenAPI client migration: PR notes

## Acceptance-criterion verification plan

| Criterion | Smallest credible verification | Status in this tests-only PR |
| --- | --- | --- |
| Add the generator/runtime and obtain the upstream document | Package resolution plus a committed, pinned OpenAPI document; inspect the package and document at the implementation PR head. | Not run: implementation is intentionally out of scope for this red phase. |
| Generate all six app surfaces | Compile calls to generated operations for manifest, recent sheets, capture creation, measurement upload, judgment upload, and ranked results. | Red: `APIClientTests.testFetchRankedResultsDecodesPublishedContractResponse` identifies the currently missing sixth surface. |
| Replace server-owned hand-written models | Compile the app against generated request/response types; inspect the removed hand-written models. | Not run: implementation is intentionally out of scope for this red phase. |
| Exercise generated client with local stubs | Permanent `URLProtocol` service tests for every operation, with no live server dependency. | Partial: current tests cover capture creation and both uploads; this PR adds manifest and recent-sheet stubs. Ranked-results coverage is red until the generated operation exists. |
| Record contract deltas and endpoint gaps | Human/external evidence from the upstream OpenAPI source and generated `/api/v1/openapi.json`; include these notes in the implementation PR description. | Recorded below; deployment URL was not resolvable in this environment, so the checked-in upstream source is the inspectable evidence. |

## Upstream evidence

The upstream OpenAPI work is closed in [viamin/color_matching#110](https://github.com/viamin/color_matching/issues/110). Its current default-branch commit is `47057afd58f7d46b4d4b740ca7d2d08947774471` (2026-10-31). The service exposes the document at `GET /api/v1/openapi.json`; this test environment could not resolve the deployed host, so this PR used the source at that commit as external evidence.

## Prose-contract deltas to include in the implementation PR

- The published capture endpoint accepts the prose contract's nested `metadata` and `quality` shape, but also accepts a legacy flat request shape. The generated client should use the nested shape.
- Measurement uploads no longer document a required top-level `scoring_algorithm_version`; each pair score requires `algorithm_version` and one of `score`, `similarity`, or `distance`. The server's measurement schema requires normalized RGB values, while the prose contract permits that field to be absent.
- Measurement and judgment uploads return `200` JSON count payloads (`capture_id` plus accepted row counts), rather than the prose contract's `204` empty response.
- Capture metadata specifies positive integer ISO and image dimensions; the local hand-written model currently permits floating ISO.
- The prose contract described ranked results only narratively. The published endpoint returns `lps-ranked-results/v1` with aggregate counts, timestamps, scoring algorithm versions, printer profile, and per-pair ranking data. There is no current app-client operation for it.
- The published manifest schema formally guarantees only its compatibility version, sheet ID, and capture scoring-algorithm version. It does not yet fully constrain all geometry and presentation fields that the iOS app consumes. This is an upstream schema-coverage gap to call out rather than paper over with hand-written types.
