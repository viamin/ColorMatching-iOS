# OpenAPI client migration evidence

This evidence is for #5. It was checked against the OpenAPI implementation
published by `viamin/color_matching#110` at commit
`47057afd58f7d46b4d740ca7d2d08947774471`.

## Acceptance criteria and smallest credible verification

| Criterion | Verification | Status in test-writing phase |
| --- | --- | --- |
| Generated client is used for the manifest, recent sheets, capture creation, measurement upload, judgment upload, and ranked results | Permanent URLProtocol tests in `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift`; each operation must get a local published-spec response fixture and assert the generated client request and decoded response. | Pending implementation. This change adds manifest/recent-sheets coverage; the current app has no generated target and no ranked-results client operation. |
| Hand-written API models are replaced while client-only models remain | Compile the iOS package and inspect the generated target plus the app-core adapter. | Pending implementation; requires human/source inspection in addition to compilation. |
| No live server is required for client tests | URLProtocol stubs only; test code has no network dependency. | Partially covered now for manifest, recent sheets, capture creation, measurement upload, and judgment upload. Ranked results is blocked by the missing facade operation. |
| `swift test --disable-sandbox` is green | Run that exact command after the generated package and source are added. | Not run in this environment: the Swift toolchain is unavailable. |

## Contract deltas found

The published spec/server behavior differs from `docs/color-matching-api-contract.md` in these material ways:

- Measurement and judgment uploads return `200` JSON receipt objects with
  `capture_id` and accepted-row counts. The prose contract specified no response
  body and the existing tests used `204`.
- Capture IDs are decimal strings produced from database IDs, rather than the
  prose example's opaque `capture_123` value.
- Ranked results is specified as `lps-ranked-results/v1` and includes capture
  provenance, scoring algorithm versions, aggregate score values, source colors,
  and the current judgment. The prose contract only described this endpoint in
  prose.
- The published capture schema accepts either nested `metadata`/`quality` (the
  iOS shape) or a legacy flat request shape. It requires image width and height
  in the nested metadata form.
- The server's OpenAPI `Manifest` schema currently declares only a subset of
  the manifest fields rendered by the endpoint. Generation must retain the
  published JSON document or supplement that schema before replacing the
  app's complete `SheetManifest` decoding.

## Endpoint gap

The app currently lacks a public ranked-results call. The implementation phase
must add one and add its local-stub regression test before this issue can pass.
