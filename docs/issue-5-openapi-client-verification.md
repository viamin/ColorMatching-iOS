# Issue #5 OpenAPI client verification plan

This test-writing change establishes the checks that the implementation PR must
satisfy. The generated client must preserve the companion app's existing user
flow while making the published server contract a build-time dependency.

## Criterion map

| Criterion | Smallest credible verification | Evidence at this revision |
| --- | --- | --- |
| Package uses `swift-openapi-generator` and `swift-openapi-runtime` | Focused package-declaration test | `OpenAPIClientAdoptionTests.testPackageDeclaresTheOpenAPIClientToolchain` (red until implementation) |
| Manifest and recent sheets work through local server stubs | Permanent Swift integration test using `URLProtocol` | `APIClientTests.testFetchesManifestAndRecentSheetsFromLocalStubbedResponses` |
| Create capture, upload measurements, and upload judgments retain request wire shapes | Permanent Swift integration tests using `URLProtocol` | Existing `APIClientTests` request tests |
| Ranked results are generated and exercised through a local stub | Permanent Swift integration test | Not yet possible: the prose contract has no ranked-results response schema and the generated operation name must come from the fetched OpenAPI document. Add this in the implementation run after vendoring/fetching the spec. |
| Hand-written API transport/models are replaced | Focused source/package review plus compilation | Not yet run; implementation must remove the duplicate transport models and compile generated types. |
| `swift test --disable-sandbox` is green | Full Swift test command | Not run in this container: no Swift executable is installed. |

## Upstream contract evidence and deltas

The upstream dependency is complete: [viamin/color_matching#110](https://github.com/viamin/color_matching/issues/110) is closed and its router serves the document at `GET /api/v1/openapi.json`.

Compared with `docs/color-matching-api-contract.md`, upstream's documented
OpenAPI conformance tests show these deltas that the implementation PR must
confirm against the fetched JSON rather than preserving prose assumptions:

- `CaptureRequest` has two accepted request variants (`anyOf`), while the prose
  presents one payload shape.
- `PairScoreRequest` requires only `pair_id` and `algorithm_version` and
  accepts three compatibility variants (`anyOf`); the prose presents
  `distance` and `similarity` as unconditional fields.
- RGB payloads also accept three variants. The hand-written `RGB` model assumes
  only the `{r, g, b}` object form.
- Ranked results has an endpoint but the prose deliberately omits its response
  schema. This is the endpoint gap: model and stub assertions must be derived
  from the published document during implementation.

The implementation PR description should report the exact fetched-spec
revision or checksum, the generated target/configuration, and the final
ranked-results response shape used by the stub test.
