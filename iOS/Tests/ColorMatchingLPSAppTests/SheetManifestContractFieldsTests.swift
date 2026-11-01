import Foundation
import MeasurementCore
import XCTest
@testable import ColorMatchingLPSAppCore

// Issue #5: docs/color-matching-api-contract.md documents `printer_profile`
// and `capture_profile` on the manifest response (used for provenance and for
// discovering the capture-time scoring algorithm version), but `SheetManifest`
// has no properties for either, so the fields are silently dropped on decode
// today. This test documents the expected shape against a contract-shaped
// stubbed response; it will not compile until `SheetManifest` gains
// `printerProfile` and `captureProfile`.
final class SheetManifestContractFieldsTests: XCTestCase {
    override func tearDown() {
        MockManifestURLProtocol.handler = nil
        super.tearDown()
    }

    func testFetchManifestDecodesPrinterAndCaptureProfile() async throws {
        let payload = Data(
            """
            {
              "schema_version": "lps-sheet-manifest/v1",
              "sheet_version": "lps-letter-grid-v1",
              "sheet_id": "sheet_123",
              "manifest_url": "https://example.test/api/v1/test_sheets/sheet_123/manifest",
              "created_at": "2026-07-25T12:00:00Z",
              "page": {"units": "mm", "width": 215.9, "height": 279.4},
              "registration_markers": [
                {"role": "top_left", "shape": "solid_square", "rect": {"x": 12, "y": 12, "width": 8, "height": 8}}
              ],
              "printer_profile": {
                "id": "printer_profile_1",
                "name": "Research printer",
                "paper": "paper name",
                "ink": "ink set",
                "settings": {}
              },
              "capture_profile": {
                "expected_illuminant": "low_pressure_sodium",
                "preferred_camera": "built_in_wide_angle_rear",
                "scoring_algorithm_version": "lps-distance-v1"
              },
              "patches": [
                {
                  "id": "patch_1",
                  "role": "pair_color",
                  "pair_id": "pair_1",
                  "pair_side": "first",
                  "reference_role": null,
                  "source_color": "#FF0000",
                  "safe_inset_mm": 1.5,
                  "rect": {"x": 16, "y": 38, "width": 16, "height": 10}
                }
              ],
              "pairs": [
                {
                  "id": "pair_1",
                  "first_patch_id": "patch_1",
                  "second_patch_id": "patch_2",
                  "source_colors": ["#FF0000", "#00FF00"],
                  "grid_row": 0,
                  "grid_col": 1
                }
              ]
            }
            """.utf8
        )

        MockManifestURLProtocol.handler = { request in
            (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, payload)
        }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockManifestURLProtocol.self]
        let client = APIClient(session: URLSession(configuration: configuration))

        let manifest = try await client.fetchManifest(baseURL: URL(string: "https://example.test")!, sheetCode: "sheet_123")

        XCTAssertEqual(manifest.printerProfile?.id, "printer_profile_1")
        XCTAssertEqual(manifest.printerProfile?.name, "Research printer")
        XCTAssertEqual(manifest.captureProfile?.expectedIlluminant, "low_pressure_sodium")
        XCTAssertEqual(manifest.captureProfile?.scoringAlgorithmVersion, "lps-distance-v1")
    }
}

private final class MockManifestURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        do {
            let (response, data) = try XCTUnwrap(Self.handler)(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
