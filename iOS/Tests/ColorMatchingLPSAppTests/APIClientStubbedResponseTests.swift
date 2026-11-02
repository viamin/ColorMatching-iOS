import Foundation
import MeasurementCore
import XCTest
@testable import ColorMatchingLPSAppCore

/// Exercises the app's API surfaces against locally stubbed HTTP responses
/// (no live server), pinning the documented contract shapes from
/// `docs/color-matching-api-contract.md`. These tests are the harness the
/// generated OpenAPI client must keep passing after issue #5's migration:
/// manifest and recent-sheets surfaces are covered here; capture creation,
/// measurement upload, and judgment upload are covered by `APIClientTests`.
final class APIClientStubbedResponseTests: XCTestCase {
    override func tearDown() {
        StubURLProtocol.handler = nil
        super.tearDown()
    }

    func testFetchManifestByCodeRequestsContractPathAndDecodesDocumentedManifest() async throws {
        var capturedRequest: URLRequest?
        StubURLProtocol.handler = { request in
            capturedRequest = request
            return (
                HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                Data(Self.documentedManifestJSON.utf8)
            )
        }

        let manifest = try await client().fetchManifest(
            baseURL: URL(string: "https://example.test")!,
            sheetCode: "sheet_123"
        )

        XCTAssertEqual(capturedRequest?.url?.path, "/api/v1/test_sheets/sheet_123/manifest")
        XCTAssertEqual(capturedRequest?.value(forHTTPHeaderField: "Authorization"), "Bearer token")
        XCTAssertEqual(manifest.schemaVersion, "lps-sheet-manifest/v1")
        XCTAssertEqual(manifest.sheetVersion, "lps-letter-grid-v1")
        XCTAssertEqual(manifest.sheetID, "sheet_123")
        XCTAssertEqual(manifest.manifestURL.absoluteString, "https://example.test/api/v1/test_sheets/sheet_123/manifest")
        XCTAssertEqual(manifest.page.units, "mm")
        XCTAssertEqual(manifest.page.width, 215.9, accuracy: 0.001)
        XCTAssertEqual(manifest.page.height, 279.4, accuracy: 0.001)

        let marker = try XCTUnwrap(manifest.registrationMarkers.first)
        XCTAssertEqual(marker.role, "top_left")
        XCTAssertEqual(marker.shape, "solid_square")
        XCTAssertEqual(marker.rect.width, 8, accuracy: 0.001)

        let patch = try XCTUnwrap(manifest.patches.first)
        XCTAssertEqual(patch.id, "patch_1")
        XCTAssertEqual(patch.role, "pair_color")
        XCTAssertEqual(patch.pairID, "pair_1")
        XCTAssertEqual(patch.pairSide, "first")
        XCTAssertNil(patch.referenceRole)
        XCTAssertEqual(patch.sourceColor, "#FF0000")
        XCTAssertEqual(patch.safeInsetMM, 1.5, accuracy: 0.001)
        XCTAssertEqual(patch.rect.x, 16, accuracy: 0.001)
        XCTAssertEqual(patch.rect.height, 10, accuracy: 0.001)

        let pair = try XCTUnwrap(manifest.pairs.first)
        XCTAssertEqual(pair.id, "pair_1")
        XCTAssertEqual(pair.firstPatchID, "patch_1")
        XCTAssertEqual(pair.secondPatchID, "patch_2")
        XCTAssertEqual(pair.sourceColors, ["#FF0000", "#00FF00"])
        XCTAssertEqual(pair.gridRow, 0)
        XCTAssertEqual(pair.gridCol, 1)
    }

    func testFetchRecentSheetsDecodesEntriesAndOptionalTitles() async throws {
        var capturedRequest: URLRequest?
        StubURLProtocol.handler = { request in
            capturedRequest = request
            return (
                HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                Data(Self.documentedRecentSheetsJSON.utf8)
            )
        }

        let sheets = try await client().fetchRecentSheets(baseURL: URL(string: "https://example.test")!)

        XCTAssertEqual(capturedRequest?.url?.path, "/api/v1/test_sheets/recent")
        XCTAssertEqual(sheets.map(\.id), ["sheet_123", "sheet_456"])
        XCTAssertEqual(sheets.map(\.sheetID), ["sheet_123", "sheet_456"])
        XCTAssertNil(sheets.first?.title, "Prose contract allows title to be null when the Phoenix app has no display name.")
        XCTAssertEqual(sheets.last?.title, "July LPS comparison sheet")
        XCTAssertEqual(
            sheets.first?.manifestURL.absoluteString,
            "https://example.test/api/v1/test_sheets/sheet_123/manifest"
        )
    }

    func testFetchManifestSurfacesBadStatusErrors() async throws {
        StubURLProtocol.handler = { request in
            (HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!, Data())
        }

        do {
            _ = try await client().fetchManifest(
                from: URL(string: "https://example.test/api/v1/test_sheets/sheet_123/manifest")!
            )
            XCTFail("Expected manifest fetch to throw on HTTP 401.")
        } catch {
            guard case APIError.badStatus = error else {
                return XCTFail("Expected APIError.badStatus, got \(error).")
            }
        }
    }
}

private extension APIClientStubbedResponseTests {
    func client() -> APIClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return APIClient(token: "token", session: URLSession(configuration: configuration))
    }

    /// The manifest example from `docs/color-matching-api-contract.md`, verbatim,
    /// including fields (`created_at`, `printer_profile`, `capture_profile`) the
    /// published spec must also type.
    static let documentedManifestJSON = """
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
    """

    /// The recent-sheets example from `docs/color-matching-api-contract.md`,
    /// plus a second entry to pin the nullable `title` decode.
    static let documentedRecentSheetsJSON = """
    {
      "sheets": [
        {
          "sheet_id": "sheet_123",
          "manifest_url": "https://example.test/api/v1/test_sheets/sheet_123/manifest",
          "title": null
        },
        {
          "sheet_id": "sheet_456",
          "manifest_url": "https://example.test/api/v1/test_sheets/sheet_456/manifest",
          "title": "July LPS comparison sheet"
        }
      ]
    }
    """
}

/// Local stub transport shared by these tests; no live server is contacted.
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
