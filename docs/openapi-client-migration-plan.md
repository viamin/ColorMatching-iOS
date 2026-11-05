# OpenAPI client migration plan

This is the implementation-run acceptance map for issue #5. It is based on
`viamin/color_matching#110`, whose controller operation declarations and
published application source are the upstream evidence until the served
`/api/v1/openapi.json` document is vendored here.

| Criterion | Smallest credible verification | Current result |
| --- | --- | --- |
| Generated client fetches and decodes a test-sheet manifest | Permanent URLProtocol unit test with a local manifest response | `APIClientTests.testFetchManifestDecodesPublishedServerShape` passes against the current hand-written client; implementation must exercise the generated operation. |
| Generated client fetches and decodes recent sheets | Permanent URLProtocol unit test with a local recent-sheets response | `APIClientTests.testFetchRecentSheetsDecodesPublishedServerShape` passes against the current hand-written client; implementation must exercise the generated operation. |
| Generated client creates a capture and uploads measurements and judgments | Permanent URLProtocol unit tests assert method, path, authorization, and request payloads | Existing `APIClientTests.testCreateCaptureEncodesMetadataAndQuality`, `testUploadMeasurementsEncodesScoresWithAlgorithmVersion`, and `testUploadJudgmentsEncodesPathAndPayload` pass. Replace their hand-written client calls with generated operations. |
| Generated client retrieves typed ranked results | Permanent URLProtocol unit test decodes an `lps-ranked-results/v1` fixture | Red: `APIClientTests.testGeneratedClientExposesRankedResultsEndpoint` fails because no typed operation exists. |
| Swift package contains generated-client dependencies and vendored/fetched source spec | Inspect `iOS/Package.swift`, generator configuration, and the tracked OpenAPI artifact | Not run in this tests-only phase. |
| Hand-written server API models are replaced while client-only models remain | Inspect the implementation diff and compile the app | Not run in this tests-only phase. |

## Contract deltas found before implementation

The prose contract describes ranked results only narratively. The current
upstream `TestSheetJSON.ranked_results/1` response is a concrete
`lps-ranked-results/v1` schema containing sheet-level capture timestamps and
counts, printer profile, algorithm-version list, and ranked pair results with
score statistics, source colors, labels, and provenance. The iOS client has no
ranked-results operation today.

The prose contract shows successful measurement and judgment uploads as empty
responses. The upstream capture controller returns `200` JSON responses with
`capture_id` plus `measurement_count`/`pair_score_count` or `judgment_count`.
The generated client must use those declared responses rather than preserve the
empty-response assumption.

The prose contract's sample printer profile (`id`, `name`, `paper`, `ink`, and
`settings`) does not match the upstream response fields (`printer_make_model`,
`paper_type`, `ink_type`, `icc_profile`, `print_settings`, driver and
calibration fields). `SheetManifest` currently ignores the profile, but any
generated manifest model will expose the upstream shape.

## Endpoint gap

No endpoint gap was found in the upstream controller declarations for the six
app surfaces: manifest, recent sheets, capture creation, measurement upload,
judgment upload, and ranked results. The gap is entirely in the iOS client:
ranked results is not currently called or modeled.
