---
module: "iOS API client"
tags:
  - openapi
  - swift
  - api-client
problem_type: "implementation-plan"
---

# Issue #5 generated OpenAPI client verification plan

This is the test-phase plan for replacing the hand-written `/api/v1` client. The
published provider issue, [viamin/color_matching#110](https://github.com/viamin/color_matching/issues/110), is closed. Its current router exposes all requested
operations:

- `GET /api/v1/test_sheets/:sheet_id/manifest`
- `GET /api/v1/test_sheets/recent`
- `POST /api/v1/test_sheets/:sheet_id/captures`
- `POST /api/v1/captures/:capture_id/measurements`
- `POST /api/v1/captures/:capture_id/judgments`
- `GET /api/v1/test_sheets/:sheet_id/ranked_results`

## Acceptance-criterion verification map

| Criterion | Smallest credible verification | Permanent evidence |
| --- | --- | --- |
| Generator/runtime and provider document are wired in | Unit contract guard parses `iOS/OpenAPI/color_matching.json` and checks package declarations | `iOS/Tests/ColorMatchingLPSAppTests/OpenAPIContractTests.swift` |
| Every used API surface is represented by the source spec | Unit contract guard asserts all six HTTP operations are present | `OpenAPIContractTests.testVendoredOpenAPISpecDeclaresEveryAppOperation` |
| Generated client performs app requests with local responses | Permanent transport tests use `URLProtocol` stubs for manifest, recent sheets, capture creation, measurement upload, and judgment upload. Add the ranked-result assertion with the generated facade implementation. | `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift` |
| Prose-contract versus provider-spec deltas are captured in the PR | Human review of the fetched provider JSON at the pinned source revision; record the resulting comparison in the PR body | External evidence; not automatable from a prose contract alone |
| `swift test --disable-sandbox` passes | Run after implementation and report command output in PR evidence | CI/local command result |

## Known contract delta before implementation

The prose contract describes ranked results only in narrative form: it gives no
response schema. The provider router does publish the endpoint, but its actual
response must be taken from the served OpenAPI document. The implementation must
vendor that document at `iOS/OpenAPI/color_matching.json`, pin its upstream commit,
and record the concrete ranked-results schema and any other field/requiredness
deltas in the PR description.

The prose manifest example includes `created_at`, `printer_profile`, and
`capture_profile`, while the existing iOS `SheetManifest` model currently only
decodes the geometry and pair data it consumes. The generated type integration
must preserve the client-side projection used by measurement analysis while
removing server-owned hand-written API models.

## Red-phase status

`OpenAPIContractTests` intentionally fails until the implementation phase adds
the vendored provider document and `swift-openapi-generator` / `swift-openapi-runtime`
package dependencies. The existing and newly added `APIClientTests` compile and
exercise local stubbed HTTP responses; they become generated-client transport
coverage when the API facade is rewired.
