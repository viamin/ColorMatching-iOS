# OpenAPI client migration: acceptance plan and contract deltas

This is the test-phase evidence and PR-description source for #5. The
implementation run must replace the prose-backed transport types with generated
types; this document does not claim that work is complete.

## Criterion verification plan

| Criterion | Smallest credible verification | Current evidence / status |
| --- | --- | --- |
| Add `swift-openapi-generator` and `swift-openapi-runtime`, and vendor the spec | Build the package after generation and inspect the pinned vendored `openapi.json` revision. | Not run: no dependency or vendored document is in this test-only change. |
| Generate the manifest, recent sheets, capture creation, measurements, judgments, and ranked-results surfaces | Run deterministic `URLProtocol` stub tests for each generated operation; the request path, authorization, encoding, and decoded response must be asserted. | Partial test coverage is committed in `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift`; ranked results cannot yet be modeled from the published schema. |
| Replace hand-written API models while retaining client-only models | Compile the app and assert its API boundary consumes generated operation inputs/outputs, while `MeasurementCore` types remain local. | Not run: implementation is intentionally prohibited during this test-writing phase. |
| Generated client tests use local stubs, not a live service | `swift test --disable-sandbox`, with each operation handled by `MockURLProtocol`; no test URL may contact a server. | The five currently implemented app operations have local-stub tests. The generated-client adaptation and ranked-results test remain pending. |
| PR records prose/spec deltas and endpoint gaps | Review this section against the upstream published spec at the pinned source revision and copy it into the implementation PR description. | External evidence captured below; final PR-description evidence is not yet available. |

## Tests added before implementation

`APIClientTests` now supplies stubbed responses for manifest and recent-sheet
reads, complementing the existing capture creation, measurement upload, and
judgment upload request tests. These are permanent boundary tests: when the
generated client replaces the current client, retain the URLProtocol stubbing
and assertions while adapting only the generated operation call syntax.

The test suite deliberately has no live-server dependency. It uses
`URLSessionConfiguration.protocolClasses` with `MockURLProtocol`.

## Published-spec comparison

Source inspected: `viamin/color_matching` main at
`094bd6d3443ddacbda7e63354299867eb5bdfa9f` (merged PR #113, closing #110),
not the hand-written contract. The server exposes its OpenAPI document at
`GET /api/v1/openapi.json`.

| Surface | Prose contract | Published spec | Migration consequence |
| --- | --- | --- | --- |
| Manifest | Describes the full sheet geometry, patches, pairs, printer profile, and capture profile needed by `SheetAnalyzer`. | `TestSheetManifest` only requires `schema_version`, `sheet_id`, and `capture_profile.scoring_algorithm_version`. | Gap: generated manifest output cannot replace the current `SheetManifest` until the server spec declares the actual fields it returns. |
| Recent sheets | `title` may be null. | `title` is required and nullable; `sheet_id` and `manifest_url` are required. | Compatible, but generated output must preserve nullable title. |
| Capture creation | Nested `metadata` and `quality`; prose permits optional image dimensions. | Accepts either legacy flat fields or nested `metadata`; nested metadata requires image width/height and identifies positive numeric constraints. | Tighten camera-call construction before migrating; generated input must always send dimensions when creating a capture. |
| Measurement upload | Requires `scoring_algorithm_version`, per-measurement `stats`, and pair-score `distance` plus `similarity`. | Does not declare top-level `scoring_algorithm_version` or `stats`; requires normalized RGB; RGB accepts arrays, objects, or JSON strings; pair score requires `algorithm_version` and one of `score`, `similarity`, or `distance`. | Gap: generated input must follow the server spec, and the client-only measurement statistics must not be assumed server payload. |
| Judgment upload | Matches a `judgments` array of pair ID and string judgment. | Same required shape, but no judgment-value enum. | Compatible shape; validation enum is an upstream-spec gap. |
| Ranked results | Narrative promises colors, scores, labels, capture provenance, printer profile, and algorithm version. | `RankedResults` only declares required `schema_version` (`lps-ranked-results/v1`) and `sheet_id`. | Blocking gap: no typed ranked result payload can be generated from this schema. |
| Write responses | Contract gives `201` for capture creation and no response body for uploads. | Capture returns a `CaptureCreatedResponse`; measurement and judgment uploads return count-bearing `200` response objects. | Generated operations must decode and deliberately discard or surface the upload receipts; the present hand-written client only validates status. |

## Endpoint gaps to resolve before the implementation PR can meet #5

- Expand `TestSheetManifest` to specify every manifest property consumed by
  `MeasurementCore`, including page geometry, registration markers, patches,
  and pairs.
- Expand `RankedResults` to specify the result entries promised by the prose
  contract.
- Decide and document whether server measurement `stats` and the top-level
  scoring algorithm version remain accepted; otherwise the iOS payload must be
  reduced to the published input.
- Add an enum for permitted judgment values if the server intends to constrain
  them.

Until those upstream changes exist, vendor the served JSON at a pinned commit
only for exploratory generation; do not represent the incomplete generated
models as a replacement for the app's runtime manifest or ranked-results data.
