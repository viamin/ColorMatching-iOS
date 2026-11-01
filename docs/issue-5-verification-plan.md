# Issue #5 verification plan

## Acceptance criteria

| Criterion | Smallest credible verification | Status in test-writing phase |
| --- | --- | --- |
| Generated client has the manifest, recent-sheets, capture, measurements, judgments, and ranked-results surfaces | Permanent local-stub XCTest coverage in `APIClientTests`; each assertion checks the request path/payload or decoded response. | Partial: manifest/recent and the existing capture/measurement/judgment cases are covered; ranked-results coverage is pending the generated surface. |
| `swift-openapi-generator` and `swift-openapi-runtime` are wired to a vendored published document | `APIClientTests.testGeneratedClientConfigurationIsCheckedIn` checks the dependency declarations, generator plugin, and `iOS/OpenAPI/color_matching.json`. | Intentionally red until implementation adds the generated client. |
| No live server is needed for generated-client tests | `MockURLProtocol` supplies every response exercised by `APIClientTests`. | Passed for current local-stub tests. |
| `swift test --disable-sandbox` is green | Run the command after generated client wiring is implemented. | Not run as a green criterion during the red phase. |
| PR description records prose-contract deltas and endpoint gaps | Inspect the vendored server document at the implementation commit and paste the deltas below into the PR description. | Human/external evidence required. |

## Upstream contract deltas found before implementation

The upstream `color_matching` controller/schema source at commit `47057afd58f7d46b4d4b740ca7d2d08947774471` differs from the prose contract in these material ways:

- `ranked_results` is a real typed response (`lps-ranked-results/v1`) with aggregate score and capture/judgment provenance; the prose contract describes it but gives no response schema.
- `printer_profile` uses `printer_make_model`, `paper_type`, `ink_type`, `icc_profile`, and print-driver/calibration fields. The prose example instead uses `id`, `name`, `paper`, `ink`, and `settings`.
- Recent sheets currently render `title: null`; the client must retain the nullable field.
- Measurement and judgment uploads return 200 JSON acknowledgement bodies (`capture_id` plus counts), whereas the prose contract does not specify a response and the handwritten client assumes 204/no body.
- Capture identifiers are decimal strings produced from server integer IDs, not the illustrative `capture_123` values in the prose contract.

Endpoint coverage is complete for the six `/api/v1` surfaces this app uses. The upstream API also exposes `/api/illuminant_measurements` and `/api/multi_image_mapping`; they are outside this app's scope and remain intentionally ungenerated for this issue.
