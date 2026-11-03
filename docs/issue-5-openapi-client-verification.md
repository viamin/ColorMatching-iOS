---
module: ios
tags: [openapi, api-client, verification]
problem_type: implementation-plan
---

# Issue #5: generated OpenAPI client verification

## Acceptance-criterion map

| Criterion | Smallest credible verification | Location | Red-phase status |
| --- | --- | --- | --- |
| Add `swift-openapi-generator` and `swift-openapi-runtime`, and vendor the upstream document | A focused package/spec test asserts both package dependencies and the six required paths in `OpenAPI/openapi.json`. | `iOS/Tests/ColorMatchingLPSAppTests/OpenAPIContractTests.swift` | Fails until the dependency declarations and vendored document land. |
| Generate the client for manifest, recent sheets, capture creation, measurements, judgments, and ranked results | The same vendored-spec test enumerates each app surface. The implementation run must compile the generated interface as part of `swift test --disable-sandbox`. | `OpenAPIContractTests.swift` | Fails until the document is vendored. |
| Replace hand-written API models while retaining client-only measurement models | Focused stubbed-response tests require the public client to return the typed acknowledgement responses that the published spec defines, rather than discard them. A review of the generated-client adapter is required because whether a model is client-only is architectural judgement. | `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift` | Fails: the current methods return `Void`. |
| Generated client works against local stubs | `MockURLProtocol` supplies the published measurement and judgment acknowledgement bodies; no live service is contacted. | `APIClientTests.swift` | Fails until typed generated responses are wired through. |
| PR records prose/spec deltas and endpoint gaps | Inspectable external evidence from upstream issue #110 and its current source spec; this section records the comparison. | This document | Recorded below; human review remains required for final PR wording. |

## Published-spec evidence and contract deltas

Upstream issue [viamin/color_matching#110](https://github.com/viamin/color_matching/issues/110) is closed. Its current implementation serves `GET /api/v1/openapi.json` and defines the companion routes in the router. The source for the spec and schema definitions is inspectable at [ApiSpec](https://github.com/viamin/color_matching/blob/main/lib/color_matching_web/api_spec.ex), [router](https://github.com/viamin/color_matching/blob/main/lib/color_matching_web/router.ex), and [API schemas](https://github.com/viamin/color_matching/blob/main/lib/color_matching_web/api_schemas.ex).

Compared with `docs/color-matching-api-contract.md`:

- Measurement and judgment uploads return `200` JSON acknowledgements with the capture ID and accepted-row counts; the prose contract says `204` with no body.
- The prose requires `scoring_algorithm_version` and measurement `stats`; the published measurement schema instead requires the two RGB medians and pair-score `algorithm_version`, and does not declare either prose field.
- Capture creation accepts the prose's nested `metadata`/`quality` shape, but also permits a legacy flat shape. Its required nested metadata fields are device, lens, image dimensions, app version, and timestamp; quality is not required by the published schema.
- The prose describes a detailed manifest and leaves ranked-result shape unspecified. The published schema currently guarantees only manifest `schema_version`, `sheet_id`, and `capture_profile.scoring_algorithm_version`, and only ranked-results `schema_version` and `sheet_id`.

## Endpoint gaps requiring implementation-run disposition

- The generated manifest type cannot replace the app's analysis `SheetManifest` without either expanding the upstream schema to include page geometry, markers, patches, and pairs, or retaining a clearly separated client-side analysis model plus mapping. This is an upstream-spec completeness gap, not an endpoint absence.
- Ranked results are published in the spec but have no current `APIClient` method or app call site. The generated surface should still be built and covered by a local stub; deciding whether to display it is outside this issue's non-goals.
- The upstream OpenAPI document is generated dynamically by Phoenix. Vendor the response fetched from `/api/v1/openapi.json` with a reproducible refresh command or plugin input; the implementation run must pin its source revision/checksum in the PR description.
