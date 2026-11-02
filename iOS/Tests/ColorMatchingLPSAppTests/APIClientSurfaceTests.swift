import Foundation
import MeasurementCore
import XCTest
@testable import ColorMatchingLPSAppCore

// Wire-format keepers for the app-facing API surfaces (issue #5).
// These pass against the hand-written transport today and must keep passing
// once APIClient is rewired onto the generated OpenAPI client: the swap must
// not change method, path, auth header, or the decoded client-side models.
final class APIClientSurfaceTests: XCTestCase {
    override func tearDown() {
        StubURLProtocol.handler = nil
        super.tearDown()
    }

    func testFetchManifestDecodesFullSheetManifest() async throws {
        var capturedRequest: URLRequest?
        StubURLProtocol.handler = { request in
            capturedRequest = request
            return (
                HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                Data(Self.manifestJSON.utf8)
            )
        }

        let manifest = try await client().fetchManifest(
            baseURL: URL(string: "https://example.test")!,
            sheetCode: "abc123"
        )

        XCTAssertEqual(capturedRequest?.httpMethod, "GET")
        XCTAssertEqual(capturedRequest?.url?.path, "/api/v1/test_sheets/abc123/manifest")
        XCTAssertEqual(capturedRequest?.value(forHTTPHeaderField: "Authorization"), "Bearer token")
        XCTAssertEqual(manifest.schemaVersion, "lps-sheet-manifest/v1")
        XCTAssertEqual(manifest.sheetVersion, "lps-letter-grid-v1")
        XCTAssertEqual(manifest.sheetID, "abc123")
        XCTAssertEqual(manifest.manifestURL.absoluteString, "https://example.test/api/v1/test_sheets/abc123/manifest")
        XCTAssertEqual(manifest.page.units, "mm")
        XCTAssertEqual(manifest.page.width, 215.9, accuracy: 0.001)
        XCTAssertEqual(manifest.page.height, 279.4, accuracy: 0.001)
        XCTAssertEqual(manifest.registrationMarkers.map(\.role), ["top_left", "bottom_right"])
        XCTAssertEqual(manifest.registrationMarkers.first?.shape, "solid_square")
        XCTAssertEqual(manifest.registrationMarkers.first?.rect, Rect(x: 12, y: 12, width: 8, height: 8))

        XCTAssertEqual(manifest.patches.count, 2)
        let first = try XCTUnwrap(manifest.patches.first)
        XCTAssertEqual(first.id, "pair_1#first")
        XCTAssertEqual(first.role, "pair_color")
        XCTAssertEqual(first.pairID, "pair_1")
        XCTAssertEqual(first.pairSide, "first")
        XCTAssertEqual(first.sourceColor, "#FF0000")
        XCTAssertEqual(first.safeInsetMM, 1.5, accuracy: 0.001)
        XCTAssertEqual(first.rect, Rect(x: 16, y: 38, width: 16, height: 10))

        XCTAssertEqual(manifest.pairs.count, 1)
        let pair = try XCTUnwrap(manifest.pairs.first)
        XCTAssertEqual(pair.id, "pair_1")
        XCTAssertEqual(pair.firstPatchID, "pair_1#first")
        XCTAssertEqual(pair.secondPatchID, "pair_1#second")
        XCTAssertEqual(pair.sourceColors, ["#FF0000", "#00FF00"])
        XCTAssertEqual(pair.gridRow, 0)
        XCTAssertEqual(pair.gridCol, 1)
    }

    func testFetchRecentSheetsDecodesTitlesIncludingNull() async throws {
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
        XCTAssertEqual(sheets.count, 2)
        XCTAssertEqual(sheets[0].sheetID, "abc123")
        XCTAssertEqual(sheets[0].manifestURL.absoluteString, "https://example.test/api/v1/test_sheets/abc123/manifest")
        XCTAssertNil(sheets[0].title)
        XCTAssertEqual(sheets[1].sheetID, "def456")
        XCTAssertEqual(sheets[1].title, "July LPS sheet")
    }

    func testFetchManifestThrowsWhenServerRejects() async throws {
        StubURLProtocol.handler = { request in
            (
                HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!,
                Data(#"{"errors":{"detail":"Unauthorized"}}"#.utf8)
            )
        }

        do {
            _ = try await client().fetchManifest(baseURL: URL(string: "https://example.test")!, sheetCode: "abc123")
            XCTFail("Expected a 401 response to surface as an error, not an empty manifest.")
        } catch {
            // Error type intentionally not pinned: it may change when the
            // generated OpenAPI client replaces the hand-written transport.
        }
    }

    private func client() -> APIClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return APIClient(token: "token", session: URLSession(configuration: configuration))
    }

    private static let manifestJSON = """
    {
      "schema_version": "lps-sheet-manifest/v1",
      "sheet_version": "lps-letter-grid-v1",
      "sheet_id": "abc123",
      "manifest_url": "https://example.test/api/v1/test_sheets/abc123/manifest",
      "created_at": "2026-07-25T12:00:00Z",
      "page": {"units": "mm", "width": 215.9, "height": 279.4},
      "registration_markers": [
        {"role": "top_left", "shape": "solid_square", "rect": {"x": 12, "y": 12, "width": 8, "height": 8}},
        {"role": "bottom_right", "shape": "solid_square", "rect": {"x": 195.9, "y": 263.4, "width": 8, "height": 8}}
      ],
      "printer_profile": {"printer_make_model": "Research printer", "paper_type": "paper name", "ink_type": "ink set", "icc_profile": null},
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
          "rect": {"x": 36, "y": 38, "width": 16, "height": 10}
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
    """

    private static let recentSheetsJSON = """
    {
      "sheets": [
        {"sheet_id": "abc123", "manifest_url": "https://example.test/api/v1/test_sheets/abc123/manifest", "title": null},
        {"sheet_id": "def456", "manifest_url": "https://example.test/api/v1/test_sheets/def456/manifest", "title": "July LPS sheet"}
      ]
    }
    """
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
