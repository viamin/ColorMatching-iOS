# Issue #5 generated OpenAPI client: test plan and contract evidence

This test-writing run deliberately leaves the implementation untouched. The permanent XCTest coverage in `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift` uses `MockURLProtocol`; it never contacts a live Phoenix server.

## Acceptance-criterion map

| Criterion | Smallest credible verification | Current result |
| --- | --- | --- |
| Generated client covers manifest and recent sheets | Permanent local-stub XCTest asserts both paths and typed response values | Red: the calls use hand-written `APIClient` and Codable models. |
| Generated client covers capture creation, measurement upload, and judgment upload | Existing permanent local-stub XCTest methods assert requests and responses for the three write operations | Red for generation: requests currently use hand-written models. |
| Generated client covers ranked results | Permanent local-stub XCTest carries a representative published response and requires a typed generated operation | Red: no ranked-results operation exists in `APIClient`. |
| Package has generator/runtime and a vendored/fetched OpenAPI document | Code review of `iOS/Package.swift`, OpenAPI input, and generated source at implementation PR head | Not run in this tests-only phase. |
| `swift test --disable-sandbox` | Run after implementation, using the permanent local-stub XCTest suite | Not run: Swift is not installed in this environment. |

## Upstream evidence and contract deltas

Evidence was inspected from `viamin/color_matching` commit `47057afd58f7d46b4d4b740ca7d2d08947774471`: its router exposes all six requested paths, and `TestSheetJSON` and `CaptureController` define the response payloads.

- The prose contract describes ranked results only narratively. The published API returns a typed `lps-ranked-results/v1` response with result rankings, aggregate score statistics, judgment provenance, capture timestamps, and a printer profile.
- The prose manifest’s printer profile has `id`, `name`, `paper`, `ink`, and `settings`. The API provides printer/device metadata instead: `printer_make_model`, `paper_type`, `ink_type`, `icc_profile`, `print_settings`, driver details, calibration fields, and notes.
- The prose leaves successful measurement and judgment uploads bodyless. The API returns acknowledgement JSON with `capture_id` and the accepted measurement/pair-score or judgment counts.
- The prose calls the capture response ID `capture_123`; the API serializes a persisted numeric capture ID as a string. Generated code must not assume a prefixed identifier.
- No endpoint gap was found for the six issue surfaces: recent sheets, manifest, capture creation, measurements, judgments, and ranked results are all registered under `/api/v1`.
