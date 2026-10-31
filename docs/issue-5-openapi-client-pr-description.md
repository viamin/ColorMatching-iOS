# PR description: generated OpenAPI Swift client

## What this PR will change

- Vendor the provider OpenAPI document fetched from `GET /api/v1/openapi.json`.
- Add `swift-openapi-generator` and `swift-openapi-runtime`, generate only the sheet/capture client surface, and replace the hand-written transport Codable types.
- Retain measurement-analysis models that are purely local to the iOS app.
- Exercise each used operation against `URLProtocol` stub responses; CI will not require a live Phoenix server.

## Acceptance-criterion verification plan

| Criterion | Smallest credible verification | Evidence location |
| --- | --- | --- |
| Generator, runtime, and vendored document | Focused package/spec integration test | `iOS/Tests/ColorMatchingLPSAppTests/OpenAPIClientIntegrationRequirementsTests.swift` |
| All six used API operations have generated definitions | Focused spec-path integration test | `OpenAPIClientIntegrationRequirementsTests.swift` |
| Generated client decodes and encodes against local responses | Permanent Swift unit tests with `URLProtocol` | `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift` |
| Manual API models are removed | Code review of generated target and transport adapter | Human inspection at implementation PR head |
| Provider document represents the actual server contract | Fetch the published `GET /api/v1/openapi.json` document during implementation | External evidence; no live server in CI |

## Contract deltas found

Source inspected: `viamin/color_matching` issue #110 and its current `main` router, API schemas, and JSON controllers on 2026-10-31.

- The prose contract said a capture body is a required `metadata` and `quality` envelope. The published schema accepts either legacy top-level metadata or `metadata`, and does not require `quality` or its fields.
- The prose contract requires `scoring_algorithm_version`, measurement `stats`, and allows optional normalized RGB. The published measurement schema does not define the top-level scoring version or stats, requires normalized RGB, and permits RGB in array, object, or JSON-string forms.
- The prose contract describes `204` responses for measurement and judgment uploads. The published API returns `200` JSON acknowledgement bodies containing counts and `capture_id`.
- The prose contract fully describes manifest and ranked-results fields. The published schemas currently require only a small subset: manifest `schema_version`, `sheet_id`, and `capture_profile.scoring_algorithm_version`; ranked results `schema_version` and `sheet_id`.
- The prose printer-profile shape (`id`, `name`, `paper`, `ink`, `settings`) differs from the server renderer (`printer_make_model`, `paper_type`, `ink_type`, and calibration/driver fields). This must be reconciled before replacing manifest types.

## Endpoint gaps discovered

No route gap remains: the provider router exposes recent sheets, manifest, capture creation, measurement upload, judgment upload, and ranked results. Schema-detail gaps above block a fully typed replacement until the provider expands the OpenAPI component definitions.
