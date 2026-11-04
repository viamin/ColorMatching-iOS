# OpenAPI Swift Client Migration Plan

This is the test-first implementation record for #5. It maps each acceptance criterion to a focused verification before the generated-client implementation begins.

| Criterion | Smallest credible verification | Current result |
| --- | --- | --- |
| `swift-openapi-generator` and `swift-openapi-runtime` are dependencies and the spec is vendored | `OpenAPIClientIntegrationRequirementsTests.testPackageDeclaresTheOpenAPIGeneratorRuntimeAndGeneratedClientTarget` and `testVendoredSpecificationContainsEveryEndpointUsedByTheCompanion` | Red: neither dependency nor vendor target exists. |
| Generated client covers manifest, recent sheets, capture creation, measurement/judgment uploads, and ranked results | The vendored-spec test asserts the six exact paths; the generated target must compile against it. | Red: no vendored OpenAPI document or generated target exists. |
| Existing app API use is wired through generated types | Local-stub facade tests in `APIClientTests` exercise manifest, recent sheets, capture creation, measurement upload, and judgment upload. The implementation must retain these behaviours while delegating to generated operations. | The facade remains hand-written; ranked results is not exposed today, so it cannot yet have a compile-safe behavior test. |
| Generated client has no-live-server tests | `APIClientTests` uses `MockURLProtocol` and synthetic JSON only. | Tests are written but not run here because the Swift toolchain is unavailable. |
| PR describes contract deltas and endpoint gaps | This file is the inspectable source record; the implementation PR must copy its findings into the PR body. | Recorded below. |

## Published-spec comparison

The upstream dependency is closed: [viamin/color_matching#110](https://github.com/viamin/color_matching/issues/110). Its router declares all six app routes, and its `GET /api/v1/openapi.json` endpoint is the source to vendor when the implementation lands.

Differences found by comparing the current prose contract with the OpenAPI schema source in `viamin/color_matching`:

- The prose document says measurement and judgment uploads return `204` with no body. The published schema declares `200` JSON responses containing `capture_id` and count fields.
- The prose request has a top-level `scoring_algorithm_version`. The published measurement schema does not declare that field; it requires `algorithm_version` per pair score and allows either `score`, `similarity`, or `distance`.
- The published capture request accepts both the prose nested `metadata` form and a compatibility flat form. Its `quality` fields are not required by the published schema.
- The prose document fully describes page geometry, markers, patches, and pairs. The published manifest schema currently requires only `schema_version`, `sheet_id`, and `capture_profile.scoring_algorithm_version`; it does not type the fields needed by `MeasurementCore`.
- The prose ranked-results endpoint has no response example. The published ranked-results schema currently requires only `schema_version` and `sheet_id`, so it cannot yet provide typed ranked rows, labels, provenance, printer profile, or scoring version promised by the prose contract.

## Endpoint gaps to resolve during implementation

1. Vendor the actual JSON served by `/api/v1/openapi.json` at a pinned upstream revision, then run the generated client plugin from that artifact.
2. Confirm whether the sparse manifest and ranked-results schemas are intentionally permissive. If they are not expanded upstream, keep the app-only analysis models separate and document any unavoidable decoding boundary rather than presenting them as generated API types.
3. Add a generated operation for ranked results once its response schema includes the values the app renders. This is an upstream contract gap, not a new endpoint request.
