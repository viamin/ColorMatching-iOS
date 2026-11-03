# Issue #5 OpenAPI client: test plan and PR evidence

This is the tests-only phase for issue #5. It establishes local-stub coverage
before the generated-client implementation is allowed to change package or
source files.

## Criterion map

| Criterion | Smallest credible verification | Current evidence | Phase status |
| --- | --- | --- | --- |
| Add `swift-openapi-generator` and `swift-openapi-runtime`; fetch or vendor the upstream document | Inspect `iOS/Package.swift`, the checked-in OpenAPI document, and generated output after `swift package resolve` | Upstream issue [viamin/color_matching#110](https://github.com/viamin/color_matching/issues/110) is closed; its source exposes `GET /api/v1/openapi.json`. This phase may not alter package or implementation files. | Not run |
| Generate the six app surfaces | Permanent local-stub tests covering manifest, recent sheets, capture creation, measurement upload, judgment upload, and ranked results | Existing local stubs cover create/upload endpoints at `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift:12`, `:92`, and `:117`; this change adds manifest/recent coverage at `:49` and `:74`. Ranked-results coverage remains a required implementation-phase addition because the current hand-written client has no operation for it. | Not run |
| Replace hand-written API models while retaining client-only models | Review generated type imports and compile the app | No implementation changes are allowed in this phase. | Not run |
| Swift tests use local stubbed responses, not a live server | Run the focused `APIClientTests` target with `URLProtocol` stubs | `MockURLProtocol` at `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift:165` intercepts every request. The container has no `swift` executable, so execution is deferred to CI/the implementation run. | Not run |
| PR description records prose-contract deltas and endpoint gaps | Human inspection of this section against the vendored upstream OpenAPI JSON at the implementation PR head | Baseline comparison recorded below; final comparison must cite the exact vendored spec revision. | Not run |

## Prose-contract delta baseline

Upstream issue #110's controller test enumerates the required paths, including
all six used by this app: manifest, recent sheets, capture creation,
measurement upload, judgment upload, and ranked results. The upstream spec is
served dynamically at `/api/v1/openapi.json`; no running upstream service or
vendored JSON is available in this tests-only workspace, so a definitive
schema-by-schema comparison must wait for the implementation PR to vendor a
specific response.

Known compatibility points to validate when that document is vendored:

- The prose manifest includes `created_at`, `printer_profile`, and
  `capture_profile`, while the current client-side `SheetManifest` only decodes
  the fields needed for analysis. Generated schema types must not force
  client-only analysis code to model unused server metadata.
- The prose `ranked_results` endpoint specifies no response schema. The
  published OpenAPI response schema is therefore the authority and may expose
  an endpoint gap in the current client, which has no ranked-results operation.
- The existing client sends string values for capture rejections and judgments.
  Generated enums or validation constraints from the published spec must be
  adopted without changing the capture/scoring behavior.
- The current API wrapper treats every successful upload as bodyless. The
  generated operation response status/body declarations must be checked before
  preserving that behavior.

## Implementation-phase completion commands

Run from `iOS/` after dependencies and generated sources are added:

```sh
swift test --disable-sandbox
```

The implementation PR must replace the `Not run` entries above with actual
command results and the pinned upstream OpenAPI revision.
