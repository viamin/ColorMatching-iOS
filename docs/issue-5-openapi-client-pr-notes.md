# Issue #5: generated OpenAPI client — test plan and PR notes

## Acceptance-criterion verification plan

| Criterion | Smallest credible verification | Status in this tests-only change |
| --- | --- | --- |
| Generated client uses the vendored upstream contract for manifest, recent sheets, capture creation, measurements, judgments, and ranked results | `APIClientTests.testVendoredOpenAPISpecDefinesEveryAppConsumedOperation` parses the vendored document and requires all six paths | Red: the document has not yet been vendored |
| The app can decode its manifest and recent-sheet discovery flow using generated types against local responses | `APIClientTests.testFetchManifestDecodesPublishedManifestFromStubbedResponse` and `APIClientTests.testFetchRecentSheetsDecodesPublishedNullableTitleFromStubbedResponse` use `URLProtocol` stubs; the implementation change must preserve these tests while replacing the models | Passing against the current adapter; repeat after generation |
| Capture, measurement, and judgment requests remain compatible | Existing `APIClientTests` request-body tests use local `URLProtocol` stubs; extend them during implementation to assert the OpenAPI-generated response types | Passing request coverage, response-type coverage pending implementation |
| Ranked-results surface is generated and wired | Add a local-stub test once the generated operation is exposed by the adapter | Not yet represented by a callable APIClient method |
| `swift test --disable-sandbox` is green after generation | Run from `iOS/` after dependencies, generator plugin, vendored document, and adapter are committed | Not runnable in the red phase because the required spec test intentionally fails |

## Published contract deltas to record in the implementation PR

Evidence was inspected from `viamin/color_matching` main at commit
`47057afd58f7d46b4d4b740ca7d2d08947774471`, which closes upstream issue #110.

- The server now publishes its OpenAPI document at `GET /api/v1/openapi.json`;
  this repository's prose contract has no machine-readable source or pin.
- `GET /ranked_results` is now a concrete response with
  `schema_version: lps-ranked-results/v1`, aggregate capture timestamps/counts,
  algorithm versions, and ranked pair results. The prose contract only described
  this endpoint narratively.
- Measurement and judgment uploads return `200` JSON success documents containing
  the capture identifier and accepted counts. The prose contract specified no
  response body and the current client accepts any `2xx` then discards it.
- Capture metadata declares `iso` as an integer and makes device model, lens,
  image dimensions, app version, and timestamp required. The existing Swift
  model represents ISO as `Float` and makes several documented fields optional.
- The published capture request permits both the app's nested `metadata` shape and
  an older flat shape. The generated client should select the nested form used by
  this app rather than expose both forms to UI code.
- Recent-sheet `title` is explicitly required-but-nullable in the published
  schema, which matches the current optional Swift property.
- The actual manifest's printer profile uses fields such as
  `printer_make_model`, `paper_type`, and `ink_type`; it does not match the
  prose example's `id`, `name`, `paper`, `ink`, and `settings` shape. The app's
  analysis model currently ignores those fields, so retain only an adapter if
  those fields become UI-visible.

## Endpoint gaps

The upstream OpenAPI schema currently declares only the top-level required
properties for manifest and ranked-results response objects. It covers the
routes needed by this app, but nested response fields are not fully typed by the
published schema. The implementation PR should either use generated additional
properties behind a narrow adapter or request upstream schema expansion before
claiming fully typed manifest/ranked-result payloads.
