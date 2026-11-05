---
module: ios
tags: [openapi, swift, api-client, issue-5]
problem_type: implementation-plan
---

# Issue #5 generated OpenAPI client PR evidence

## Acceptance-criterion verification plan

| Criterion | Smallest credible verification | Current test/evidence |
| --- | --- | --- |
| Package has the generator/runtime and a vendored upstream document | Unit test opens `iOS/OpenAPI/color_matching-openapi.json` and asserts the six required operations are present. | `APIClientTests.testVendoredOpenAPISpecDeclaresEveryCompanionOperation` (red until the document is vendored). |
| Generated client covers manifest, recent sheets, create capture, uploads, and ranked results | Local `URLProtocol` stubs exercise each generated client operation and decode its response/request. | Manifest/recent stubs are added now; the implementation run must replace the existing hand-written capture/upload tests and add ranked-results coverage using generated operation types. |
| Hand-written API models are replaced while client-side measurement models remain | Compile the app target after generated types replace API transport models; inspect the generated source and the deleted transport declarations in the PR diff. | Human/code-review evidence required in the implementation PR. |
| Tests do not need a live server | Run `swift test --disable-sandbox`; all client tests use `MockURLProtocol`. | `APIClientTests` uses only local stubbed responses. |
| PR documents prose-contract deltas and endpoint gaps | Compare the vendored upstream `openapi.json` with `docs/color-matching-api-contract.md`; record the result in the PR description. | External evidence required after vendoring the exact upstream document. |

## Upstream dependency and observed deltas

Upstream source currently exposes its machine-readable contract at `GET /api/v1/openapi.json` (viamin/color_matching#110). This test-writing change deliberately does not vendor it: the implementation run must fetch a pinned copy into `iOS/OpenAPI/color_matching-openapi.json` and record the source revision/checksum in its PR description.

The upstream schema source indicates these differences from the prose contract; they must be confirmed against the vendored JSON, rather than assumed from this note:

- The manifest schema formally requires only `schema_version`, `sheet_id`, and `capture_profile.scoring_algorithm_version`; the prose contract describes the page, markers, patches, and pairs that the iOS capture flow needs. This is an endpoint/schema completeness gap if the emitted OpenAPI document matches the source.
- The ranked-results schema formally requires only `schema_version` and `sheet_id`; the prose contract names result attributes but gives no response schema. This is an endpoint/schema completeness gap for a typed iOS result view.
- Measurement upload formally requires each measurement's normalized RGB value and does not declare the prose contract's top-level `scoring_algorithm_version` or measurement `stats`. Pair scores accept `score`, `similarity`, or `distance` (with `algorithm_version`), whereas the prose contract sends distance and similarity together.
- Measurement and judgment uploads return JSON count responses with HTTP 200, rather than the current app tests' empty HTTP 204 response assumption.
- Capture creation supports the prose nested `metadata`/`quality` shape, but the published schema also permits a legacy flattened request shape. `iso` is typed as an integer in the schema while the app model uses `Float`.

## Draft PR description for the implementation run

```markdown
## Summary

- Vendored `color_matching` OpenAPI JSON from `<upstream commit/URL and SHA-256>`.
- Added `swift-openapi-generator` and `swift-openapi-runtime`; generated only the six companion operations.
- Replaced hand-written transport Codable models with generated request/response types, retaining measurement-domain models.

## Contract deltas and gaps

- Confirmed/updated the five deltas listed in `docs/issue-5-openapi-client-pr.md` against `<vendored spec revision>`.
- Endpoint gaps: `<none, or list concrete missing response fields/operations>`.

## Verification

- `swift test --disable-sandbox`
- `APIClientTests` uses `MockURLProtocol`; no live API is contacted.
```
