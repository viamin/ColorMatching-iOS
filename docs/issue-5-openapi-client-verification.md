# Issue #5 verification plan and contract audit

This test-writing change establishes the acceptance-criterion evidence plan for
the generated OpenAPI Swift client. Production code is intentionally deferred to
the implementation phase.

| Criterion | Smallest credible verification | Status in this change |
| --- | --- | --- |
| Generator, runtime, and published document are wired into SwiftPM | `GeneratedOpenAPIClientRequirementsTests.testPackageDeclaresOpenAPIGeneratorAndRuntimeDependencies` | Red: dependencies are not present yet. |
| Generated client covers manifest, recent sheets, capture creation, measurement upload, judgment upload, and ranked results | `GeneratedOpenAPIClientRequirementsTests.testGeneratedClientCoversEveryCompanionAPISurface` | Red: ranked-results adapter and generated client are absent. |
| App uses generated types for API data | Focused code review of the generated adapter and removal of duplicate wire models, backed by the same requirements test | Not run: implementation phase. |
| Client works without a live server | Permanent stubbed unit tests in `APIClientTests`; the existing create/measurement/judgment tests plus the manifest/recent tests added here | Stubbed tests are ready; execution is blocked because this container has no Swift toolchain. |
| Prose-contract deltas and endpoint gaps are disclosed | Human/external evidence: compare the vendored/fetched OpenAPI document with `docs/color-matching-api-contract.md` in the implementation PR description | Blocked pending an inspectable published document. |

## Upstream evidence and provisional delta record

On 2026-11-05, `viamin/color_matching#110` was closed by
[`viamin/color_matching#113`](https://github.com/viamin/color_matching/pull/113).
That change serves the generated specification at `GET /api/v1/openapi.json`.
The public `main` tree does not contain a versioned OpenAPI/Swagger JSON file:
the document is generated at runtime. The implementation PR must fetch that
endpoint, vendor the exact response (including its source revision or checksum),
and generate from the vendored file so client regeneration is reproducible.

The inspected upstream schema source at merge commit
`094bd6d3443ddacbda7e63354299867eb5bdfa9f` already identifies these deltas
from `docs/color-matching-api-contract.md`:

- The manifest schema guarantees only `schema_version`, `sheet_id`, and
  `capture_profile.scoring_algorithm_version`; the prose contract assumes many
  additional manifest fields. The adapter must tolerate the published minimum
  shape or the server spec must be tightened.
- The prose contract makes capture metadata fields optional in the app model,
  while the published schema requires `image_width` and `image_height` and types
  `iso` as an integer (the app's current model uses `Float`).
- The published capture request accepts both the nested `metadata`/`quality`
  form from the prose contract and a legacy flat form. Generated usage must pick
  the nested form, preserving current behavior.
- The published measurement schema requires both median RGB fields, does not
  declare the prose contract's top-level `scoring_algorithm_version` or nested
  `stats`, and permits pair scores as `score`, `similarity`, or `distance` with
  `algorithm_version`. The adapter needs an explicit compatibility decision;
  blindly retaining the hand-written body would hide the mismatch.
- The published API has concrete response schemas for measurement and judgment
  uploads, whereas the hand-written client discards their bodies after a `204`.
  The implementation must confirm the actual documented success status and
  consume or intentionally discard the generated response.
- `ranked_results` is documented upstream with a minimum `schema_version` of
  `lps-ranked-results/v1` and `sheet_id`, but the app has no API method for it.
  This is the known endpoint gap that the generated adapter must close.

The upstream issue also names two `/api` endpoints outside this companion app's
scope; they are not an iOS client requirement.
