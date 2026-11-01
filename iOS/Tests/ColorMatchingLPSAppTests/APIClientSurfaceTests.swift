import Foundation
import MeasurementCore
import XCTest
@testable import ColorMatchingLPSAppCore

/// Wire-level regression guards for the app-facing API surface.
///
/// These tests pin the HTTP behavior the app depends on (paths, bearer auth,
/// snake_case JSON payloads, decoding of the payloads the Phoenix server
/// actually renders). They pass against the hand-written `APIClient` today and
/// MUST keep passing after the API layer is re-backed by the generated
/// OpenAPI client (issue #5): the migration must not change the wire contract
/// or the decoded domain values.
///
/// The manifest and recent-sheets fixtures mirror the JSON rendered by
/// `ColorMatchingWeb.TestSheetJSON` in viamin/color_matching (the published
/// spec from viamin/color_matching#110), not the older prose examples in
/// `docs/color-matching-api-contract.md` — e.g. `printer_profile` carries the
/// real fields (`printer_make_model`, `paper_type`, `ink_type`) and patch ids
/// are `<pair_id>#<side>` strings.
final class APIClientSurfaceTests: XCTestCase {
    override func tearDown() {
        StubURLProtocol.handler = nil
        super.tearDown()
    }

    func testFetchManifestDecodesServerRenderedManifest() async throws {
        var capturedRequest: URLRequest?
        StubURLProtocol.handler = { request in
            capturedRequest = request
            return (
                HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                Data(Self.serverRenderedManifestJSON.utf8)
            )
        }

        let manifest = try await client().fetchManifest(
            baseURL: URL(string: "https://example.test")!,
            sheetCode: "sheet_1"
        )

        XCTAssertEqual(capturedRequest?.url?.path, "/api/v1/test_sheets/sheet_1/manifest")
        XCTAssertEqual(capturedRequest?.value(forHTTPHeaderField: "Authorization"), "Bearer token")
        XCTAssertEqual(manifest.schemaVersion, "lps-sheet-manifest/v1")
        XCTAssertEqual(manifest.sheetID, "sheet_1")
        XCTAssertEqual(manifest.sheetVersion, "lps-letter-grid-v1")
        XCTAssertEqual(manifest.page.units, "mm")
        XCTAssertEqual(manifest.registrationMarkers.first?.role, "top_left")
        XCTAssertEqual(manifest.patches.map(\.id), ["pair_1#first", "pair_1#second"])
        XCTAssertNil(manifest.patches.first?.referenceRole)
        XCTAssertEqual(manifest.patches.first?.sourceColor, "#FF0000")
        XCTAssertEqual(manifest.pairs.first?.firstPatchID, "pair_1#first")
        XCTAssertEqual(manifest.pairs.first?.secondPatchID, "pair_1#second")
        XCTAssertEqual(manifest.pairs.first?.sourceColors, ["#FF0000", "#00FF00"])
        XCTAssertEqual(manifest.manifestURL.path, "/api/v1/test_sheets/sheet_1/manifest")
    }

    func testFetchRecentSheetsDecodesNullableTitleAndRelativeManifestURL() async throws {
        var capturedRequest: URLRequest?
        StubURLProtocol.handler = { request in
            capturedRequest = request
            return (
                HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                Data(Self.recentSheetsJSON.utf8)
            )
        }

        let sheets = try await client().fetchRecentSheets(baseURL: URL(string: "https://example.test")!)

        XCTAssertEqual(capturedRequest?.url?.path, "/api/v1/test_sheets/recent")
        XCTAssertEqual(capturedRequest?.value(forHTTPHeaderField: "Authorization"), "Bearer token")
        XCTAssertEqual(sheets.count, 2)
        XCTAssertEqual(sheets[0].sheetID, "sheet_1")
        XCTAssertNil(sheets[0].title)
        XCTAssertEqual(sheets[0].manifestURL.path, "/api/v1/test_sheets/sheet_1/manifest")
        XCTAssertEqual(sheets[1].sheetID, "sheet_2")
        XCTAssertEqual(sheets[1].title, "July LPS comparison sheet")
    }

    func testFetchManifestThrowsOnErrorResponseStatus() async throws {
        StubURLProtocol.handler = { request in
            (
                HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!,
                Data(#"{"errors": {"detail": "Sheet not found"}}"#.utf8)
            )
        }

        do {
            _ = try await client().fetchManifest(
                baseURL: URL(string: "https://example.test")!,
                sheetCode: "missing_sheet"
            )
            XCTFail("Expected fetchManifest to throw on a 404 response")
        } catch let error as APIError {
            XCTAssertEqual(String(describing: error), "badStatus")
        }
    }

    private func client() -> APIClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return APIClient(token: "token", session: URLSession(configuration: configuration))
    }

    /// Mirrors `ColorMatchingWeb.TestSheetJSON.manifest/1`, including the
    /// `printer_profile` field names the Phoenix app actually renders and the
    /// path-only `manifest_url`.
    private static let serverRenderedManifestJSON = #"""
    {
      "schema_version": "lps-sheet-manifest/v1",
      "sheet_id": "sheet_1",
      "sheet_version": "lps-letter-grid-v1",
      "manifest_url": "/api/v1/test_sheets/sheet_1/manifest",
      "created_at": "2026-07-25T12:00:00Z",
      "page": {"units": "mm", "width": 215.9, "height": 279.4},
      "registration_markers": [
        {"role": "top_left", "shape": "solid_square", "rect": {"x": 12, "y": 12, "width": 8, "height": 8}},
        {"role": "top_right", "shape": "solid_square", "rect": {"x": 195.9, "y": 12, "width": 8, "height": 8}},
        {"role": "bottom_right", "shape": "solid_square", "rect": {"x": 195.9, "y": 259.4, "width": 8, "height": 8}},
        {"role": "bottom_left", "shape": "solid_square", "rect": {"x": 12, "y": 259.4, "width": 8, "height": 8}}
      ],
      "printer_profile": {
        "printer_make_model": "Research printer",
        "paper_type": "paper name",
        "ink_type": "ink set",
        "icc_profile": null,
        "print_settings": {},
        "driver_name": null,
        "driver_version": null,
        "calibration_date": null,
        "calibration_version": null,
        "notes": null
      },
      "capture_profile": {
        "expected_illuminant": "low_pressure_sodium",
        "preferred_camera": "built_in_wide_angle_rear",
        "scoring_algorithm_version": "lps-distance-v1"
      },
      "patches": [
        {
          "id": "pair_1#first",
          "role": "pair_color",
          "pair_id": "pair_1",
          "pair_side": "first",
          "reference_role": null,
          "source_color": "#FF0000",
          "safe_inset_mm": 1.5,
          "rect": {"x": 16, "y": 38, "width": 16, "height": 10}
        },
        {
          "id": "pair_1#second",
          "role": "pair_color",
          "pair_id": "pair_1",
          "pair_side": "second",
          "reference_role": null,
          "source_color": "#00FF00",
          "safe_inset_mm": 1.5,
          "rect": {"x": 40, "y": 38, "width": 16, "height": 10}
        }
      ],
      "pairs": [
        {
          "id": "pair_1",
          "first_patch_id": "pair_1#first",
          "second_patch_id": "pair_1#second",
          "source_colors": ["#FF0000", "#00FF00"],
          "grid_row": 0,
          "grid_col": 1
        }
      ]
    }
    """#

    private static let recentSheetsJSON = #"""
    {
      "sheets": [
        {
          "sheet_id": "sheet_1",
          "manifest_url": "/api/v1/test_sheets/sheet_1/manifest",
          "title": null
        },
        {
          "sheet_id": "sheet_2",
          "manifest_url": "/api/v1/test_sheets/sheet_2/manifest",
          "title": "July LPS comparison sheet"
        }
      ]
    }
    """#
}

private final class StubURLProtocol: URLProtocol {
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
