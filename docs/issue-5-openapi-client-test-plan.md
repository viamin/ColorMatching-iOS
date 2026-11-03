---
module: ios
tags: [openapi, swift, generated-client, testing]
problem_type: test-plan
---

# Issue #5 OpenAPI client verification plan

This is the tests-first plan for replacing the iOS hand-written `/api/v1`
transport models. It deliberately uses URLProtocol stubs: CI must not require a
running Phoenix server or a database.

## Acceptance criteria and smallest verification

| Criterion | Verification | Evidence at this revision |
| --- | --- | --- |
| Generated client dependencies and a reviewable source spec are wired into the Swift package | Focused unit test reads the package declaration and requires a vendored OpenAPI JSON/YAML source. This is red until implementation. | `iOS/Tests/ColorMatchingLPSAppTests/OpenAPIAdoptionTests.swift:5` |
| Manifest and recent-sheet discovery preserve the published wire format through the generated client boundary | Permanent stubbed-client tests assert paths, bearer auth, and decoded values. | `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift:49`, `:69` |
| Capture creation, measurement upload, and judgment upload preserve the published wire format through the generated client boundary | Permanent stubbed-client tests assert paths and request payloads. | `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift:13`, `:89`, `:114` |
| Ranked-results is generated and decodes a local stub response | Add a permanent URLProtocol test when the generated operation is wired into the app-facing client. It is currently absent from `APIClient`. | Not run: no generated operation exists yet. |
| `swift test --disable-sandbox` is green | Run after implementation with the Swift toolchain available. | Not run: this container has no `swift` executable. |

## Published-spec comparison

The upstream dependency landed as `viamin/color_matching#113` (the issue text
references `#110`). At upstream `main` commit `47057af`, the machine-readable
document is served at `GET /api/v1/openapi.json`; the six iOS routes are all
declared and protected by `bearerAuth` (the spec endpoint itself is public).

Compared with `docs/color-matching-api-contract.md`:

- The prose describes ranked results only narratively. The published contract
  defines `lps-ranked-results/v1`, aggregation fields, judgment provenance, and
  per-pair score statistics. The current iOS client has no ranked-results
  operation.
- The prose says successful measurement and judgment uploads without defining a
  response body. The published contract returns a `200` JSON acknowledgement
  containing the capture ID and accepted counts; the current client accepts an
  empty `204`, so generated response handling must follow the spec.
- The prose manifest's printer profile (`id`, `name`, `paper`, `ink`,
  `settings`) differs from the published fields (`printer_make_model`,
  `paper_type`, `ink_type`, `icc_profile`, driver/calibration metadata, and
  `print_settings`). The current client silently ignores both profile variants.
- The app's local `SheetManifest` only keeps geometry required for capture. It
  should remain a client-side projection, while wire DTOs move to generated
  OpenAPI types.

## Implementation handoff

Vendor the exact JSON emitted by the upstream endpoint at
`iOS/OpenAPI/color-matching-api.json`, add the generator/runtime dependencies
and build plugin, then replace the transport DTOs in `APIClient.swift` with the
generated operation inputs and outputs. Keep `MeasurementCore` analysis models
as local projection models. Add the ranked-results URLProtocol test before
considering this plan complete.
