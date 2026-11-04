# Issue #5 OpenAPI client verification plan

This test-writing change records the acceptance-criterion evidence plan before
implementation. Tests use a local `URLProtocol` stub; CI must never need the
Phoenix service.

| Criterion | Smallest credible verification | Phase |
| --- | --- | --- |
| Generator/runtime dependency and fetched or vendored specification | `OpenAPIClientConfigurationTests` loads the vendored JSON and verifies all six companion routes; it also asserts both Swift OpenAPI packages are declared. | Red until implementation adds the dependencies and spec. |
| Generated types wired for manifest, recent sheets, capture creation, measurement upload, judgment upload, and ranked results | Permanent `APIClientTests` local-stub coverage exercises each wrapper surface and asserts decoded/generated response values plus request path/body. | Add ranked-results test with the generated wrapper during implementation; the current app exposes no ranked-results call. |
| Remove server API models while preserving client-only measurement models | Implementation review of `APIClient.swift` and compiler type-checking. | Human/source evidence, because a test cannot determine authorship of a type. |
| Generated client uses local stubbed responses | Permanent `APIClientTests` with `MockURLProtocol`; no live-server dependency. | Existing tests cover capture/measurement/judgment; this change adds manifest/recent coverage. |
| Contract-delta and endpoint-gap record | PR description must cite the source comparison below. | Human/external evidence. |

## Upstream comparison (2026-11-04)

The comparison source is `viamin/color_matching` issue #110's merged router,
OpenAPI schema modules, and JSON renderers. The deployment endpoint could not
be fetched in this environment because its hostname did not resolve, so this is
not a substitute for vendoring the published `GET /api/v1/openapi.json`
document during implementation.

- The prose contract's five write/read surfaces plus ranked results all exist in
  the upstream router. There is no endpoint gap for this app.
- The prose says measurement and judgment uploads return no content; the
  published schemas/controllers return `200` JSON summaries containing the
  capture ID and accepted-item counts.
- Capture creation remains compatible with the prose's nested `metadata` and
  `quality` payload, but the server additionally accepts a legacy flat shape.
- The prose describes ranked-results fields informally. The published response
  is `lps-ranked-results/v1` with aggregate capture timestamps/counts and
  per-pair score, judgment, provenance, and source-color fields.
- The published schema is less complete than its JSON renderer for manifest and
  ranked-results nested fields. Generated optionality must be inspected from the
  vendored JSON, and this limitation should be retained in the PR description.
