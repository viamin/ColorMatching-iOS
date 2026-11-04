# Issue #5 OpenAPI Client Verification Plan

This is the test-writing evidence for the generated-client migration. The
implementation run must retain the local `URLProtocol` stubs; no test may call
the Phoenix server.

| Criterion | Smallest credible verification | Evidence at this test-only head |
| --- | --- | --- |
| Generated package and vendored contract | Focused architectural test verifies the generator/runtime dependencies and all six consumed paths in the vendored contract. | `OpenAPIContractTests.swift:testVendoredContractContainsEveryConsumedSheetAndCaptureOperation` (red: no contract exists); `OpenAPIContractTests.swift:testPackageAndAPIClientUseOpenAPIGeneratedTypes` (red: package and client are hand-written). |
| Generated typed client replaces API models | Focused architectural test rejects the existing hand-written transport model declarations and requires `OpenAPIRuntime`. | `OpenAPIContractTests.swift:testPackageAndAPIClientUseOpenAPIGeneratedTypes` (red). |
| Local-stub generated-client behavior | Permanent unit/service tests use `MockURLProtocol` to verify request/response behavior for manifest, recent sheets, capture creation, measurement upload, and judgment upload. The implementation should preserve the public adapter API while delegating to generated operations. | `APIClientTests.swift` (five local-stub tests). They could not be executed in this container because the Swift toolchain is unavailable. Ranked-results needs a public adapter and local-stub test in the implementation run. |
| Contract deltas and endpoint gaps in the PR | Human/external evidence: compare the committed document against `GET /api/v1/openapi.json` or the server's generated JSON at the pinned upstream revision. | Not runnable in this isolated test-writing phase; record the comparison in the implementation PR description. |

## Published-contract delta checklist

The upstream OpenAPI source makes the following differences from the prose
contract material to the migration and must be reconciled before merge:

- The manifest schema only requires `schema_version`, `sheet_id`, and
  `capture_profile`; the prose contract assumes the full page, marker, patch,
  pair, printer-profile, and creation metadata shape.
- `ranked_results` is documented with only `schema_version` and `sheet_id`,
  while the prose contract promises source colors, scores, labels, capture
  provenance, printer profile, and scoring-algorithm version.
- Capture creation accepts either legacy top-level fields or the nested
  `metadata` form. Its documented capture metadata requires image dimensions
  but makes exposure, ISO, focus, and white-balance optional.
- Measurement upload documents RGB as an array, object, or JSON string and
  requires normalized RGB; it does not document the current client-side
  statistics or top-level scoring-algorithm version.
- Measurement and judgment uploads return acknowledgement bodies in the spec;
  the prose contract does not specify responses.

The implementation PR must state whether these are intended compatibility
forms or endpoint/documentation gaps, cite the upstream revision used to
vendor the document, and not claim the comparison is complete until the
actual generated JSON has been inspected.
