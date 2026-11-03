# OpenAPI client verification plan

This document is the criterion-level test plan for #5. It is intentionally
committed during the tests-only phase; generated-client implementation and the
spec comparison happen in the follow-up implementation run.

| Criterion | Smallest credible verification | Current evidence / status |
| --- | --- | --- |
| Add `swift-openapi-generator`, `swift-openapi-runtime`, and the upstream OpenAPI document | Inspect `iOS/Package.swift`, vendored/fetched document, and generated-source regeneration command at the PR head. | Not run: implementation is outside the test-writing allowlist. |
| Generate the manifest, recent-sheet, capture, measurement, judgment, and ranked-results surfaces | Compile the app against generated operation/input/output types; retain one local-stub test per operation. | Not run: the current client has no ranked-results operation and generated types do not exist yet. |
| Replace hand-written API models, preserving client-only models | Inspect the API module and compile the app: transport DTOs must come from the generated client, while measurement-analysis models remain in `MeasurementCore`. | Not run: implementation is outside the test-writing allowlist. |
| Exercise generated client with local stubs | Permanent `APIClientTests` stubs: manifest and recent-sheet reads; capture, measurement, and judgment writes. Add ranked-results stub when that generated operation exists. | Partially covered by the permanent tests committed with this plan; ranked results is blocked on the generated surface. |
| Record contract deltas and endpoint gaps in the PR description | Human/external evidence: compare `docs/color-matching-api-contract.md` with the exact upstream #110 OpenAPI document, cite its revision, and paste the resulting delta/gap list into the PR body. | Not run: no published spec was discoverable from the public GitHub search at this run. |

## Existing prose-contract gap

The local prose contract defines ranked results only as a route plus a narrative
description. It does not define a response schema. The implementation PR must
not invent one: it must use the response published by the OpenAPI document or
record that endpoint as an upstream gap.
