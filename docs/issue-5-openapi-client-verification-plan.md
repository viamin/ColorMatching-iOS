# Issue #5 verification plan

This is the tests-only plan for replacing the iOS hand-written API layer with a
generated OpenAPI client. The implementation change is intentionally deferred
until these tests have been reviewed.

| Acceptance criterion | Smallest credible verification | Status in this PR |
| --- | --- | --- |
| Add the generator/runtime and vendor or fetch the provider document | Inspect `iOS/Package.swift`, the checked-in OpenAPI input, and generated-source build output. | Not run: implementation-phase work. |
| Generate the manifest, recent sheets, capture, measurement, judgment, and ranked-results surfaces | Compile the generated operation calls. Exercise each against URL-protocol stubs that return provider-shaped JSON. | Partially covered: `APIClientTests.testSheetCaptureWorkflowUsesProviderResponseShapes` covers the five surfaces currently called by the app. Ranked results is an app endpoint gap and needs a generated-client test when the app adopts it. |
| Replace hand-written API models while retaining client-only models | Review the generated-source target and verify `MeasurementCore` remains the source for image-analysis models. | Not run: implementation-phase work. |
| Swift tests against local stubbed responses | Run `swift test --disable-sandbox` and inspect the workflow test. It uses `MockURLProtocol`; no live service is contacted. | To be run after implementation. |
| PR description records provider-contract deltas and endpoint gaps | Human review of this delta record and the resulting PR body. | Recorded below; human/external evidence still required. |

## Provider contract deltas found

The comparison used `viamin/color_matching` issue #110's merged router,
`ApiSchemas`, and controller JSON rendering as the published source of truth.

- The actual capture endpoint accepts both the prose contract's nested
  `metadata`/`quality` form and a flattened compatibility form. Its schema does
  not require `quality` when nested metadata is supplied.
- Successful measurement and judgment uploads return `200` JSON count payloads,
  not the prose contract's empty `204` responses. The stubbed workflow uses
  those response bodies.
- The actual measurement schema does not require `scoring_algorithm_version`
  and does not declare the client-only statistics fields. It allows RGB values
  as arrays, objects, or JSON strings.
- The prose `printer_profile` example (`id`, `name`, `paper`, `ink`,
  `settings`) differs from the response renderer's detailed print-profile
  fields (`printer_make_model`, `paper_type`, `ink_type`, and others).
- Ranked results is now a real authenticated route with
  `lps-ranked-results/v1`, but the current iOS app has no call site for it.
  The implementation must generate that operation; product adoption remains a
  separate behavior decision.

## Endpoint gaps

The provider's OpenAPI schemas are intentionally shallow for the iOS surfaces:
the manifest schema only requires `schema_version`, `sheet_id`, and the capture
profile version, while ranked-results requires only its schema version and sheet
ID. The implementation should preserve the generated types at this boundary and
avoid treating undocumented extra fields as stable app-facing models.
