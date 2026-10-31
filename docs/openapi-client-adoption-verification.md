# OpenAPI client adoption verification plan

This document is the run/PR evidence plan for #5. It is intentionally checked
in with the red tests so the implementation phase has concrete acceptance
criteria rather than a broad-suite proxy.

## Criterion map

| Criterion | Smallest credible verification | Location | Current phase |
| --- | --- | --- | --- |
| Generated client dependencies, plugin, vendored specification, and removal of hand-written transport models | Focused source-level XCTest checks the Swift package declaration and the client boundary | `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift` | Red: dependencies, plugin, vendored spec, generated target, and model removal are not present yet. |
| Manifest and recent-sheet operations use the published response shapes | Permanent local-stub XCTest decodes representative published responses; no server is contacted | `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift` | Green against the legacy boundary; retain while wiring the generated client. |
| Capture creation, measurement upload, and judgment upload use the published request/response status conventions | Permanent local-stub XCTest verifies the outgoing routes/payloads and published 201/200 responses | `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift` | Green for the legacy transport; the architecture check remains red until generated types replace it. |
| Ranked results is available through the app client | Focused source-level XCTest requires the app boundary to expose the endpoint, followed by a local-stub XCTest in implementation | `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift` | Red: no ranked-results client operation exists. |
| Contract deltas and endpoint gaps are inspectable by a reviewer | Human/external evidence: this document and the eventual PR description, checked against upstream #110 and its source | This file | Recorded below; published runtime `/api/v1/openapi.json` could not be fetched from this isolated environment, so the server-side source at the closed dependency was inspected instead. |

## Published-contract deltas

Evidence was inspected from the closed dependency [viamin/color_matching#110](https://github.com/viamin/color_matching/issues/110), its [router](https://raw.githubusercontent.com/viamin/color_matching/main/lib/color_matching_web/router.ex), [OpenAPI schemas](https://raw.githubusercontent.com/viamin/color_matching/main/lib/color_matching_web/api_schemas.ex), and [test-sheet JSON renderer](https://raw.githubusercontent.com/viamin/color_matching/main/lib/color_matching_web/controllers/test_sheet_json.ex) on 2026-10-31.

- `POST /captures/:capture_id/measurements` and `/judgments` return `200` JSON acknowledgement objects containing capture and count fields; the prose contract only showed request payloads and the former Swift tests assumed `204`.
- The published measurement schema accepts RGB arrays, `{r,g,b}` objects, or JSON-encoded RGB strings. It requires normalized RGB on a measurement, but does not describe the prose contract's nested statistics or top-level `scoring_algorithm_version`.
- Capture creation permits either the legacy flat capture request or the nested `metadata` request. The current app uses the nested variant.
- Ranked results is now a machine-described endpoint and returns `lps-ranked-results/v1`; the prose contract describes it only narratively, and the app has no operation for it.
- The currently published `Manifest` OpenAPI schema formally requires only `schema_version`, `sheet_id`, and `capture_profile`, although the server renderer currently supplies the richer manifest shape consumed by `MeasurementCore`. Generation therefore cannot safely replace the client-side manifest domain model until that schema is expanded or an explicit adapter is retained.

## Endpoint gap to resolve in implementation

The OpenAPI source currently exposes a deliberately shallow manifest and ranked-results schema. Before relying on generated models for all fields, fetch and vendor the served `GET /api/v1/openapi.json` artifact and confirm it includes the full response shapes. If it remains shallow, record the upstream schema gap in the PR and retain only the necessary client-side adapters; do not recreate the transport models by hand.
