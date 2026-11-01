import Foundation
import MeasurementCore
import XCTest
@testable import ColorMatchingLPSAppCore

/// Covers `fetchManifest` and `fetchRecentSheets`, which `APIClientTests` did not
/// exercise before. Fixtures mirror `docs/color-matching-api-contract.md` so these
/// keep working as a regression net once the hand-written models are replaced by
/// the generated OpenAPI client (#5).
final class APIClientReadEndpointsTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.handler = nil
        super.tearDown()
    }

    func testFetchManifestDecodesPublishedSheetManifestShape() async throws {
        var capturedRequest: URLRequest?
        MockURLProtocol.handler = { request in
            capturedRequest = request
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data(Self.manifestFixture.utf8))
        }

        let manifest = try await client().fetchManifest(baseURL: URL(string: "https://example.test")!, sheetCode: "sheet_123")

        XCTAssertEqual(capturedRequest?.url?.path, "/api/v1/test_sheets/sheet_123/manifest")
        XCTAssertEqual(capturedRequest?.httpMethod, "GET")
        XCTAssertEqual(capturedRequest?.value(forHTTPHeaderField: "Authorization"), "Bearer token")
        XCTAssertEqual(manifest.schemaVersion, "lps-sheet-manifest/v1")
        XCTAssertEqual(manifest.sheetVersion, "lps-letter-grid-v1")
        XCTAssertEqual(manifest.sheetID, "sheet_123")
        XCTAssertEqual(manifest.page.units, "mm")
        XCTAssertEqual(manifest.page.width, 215.9)
        XCTAssertEqual(manifest.page.height, 279.4)
        XCTAssertEqual(manifest.registrationMarkers.first?.role, "top_left")
        XCTAssertEqual(manifest.patches.first?.id, "patch_1")
        XCTAssertEqual(manifest.patches.first?.pairID, "pair_1")
        XCTAssertEqual(manifest.pairs.first?.sourceColors, ["#FF0000", "#00FF00"])
    }

    func testFetchRecentSheetsDecodesNullableTitle() async throws {
        var capturedRequest: URLRequest?
        MockURLProtocol.handler = { request in
            capturedRequest = request
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data(Self.recentSheetsFixture.utf8))
        }

        let sheets = try await client().fetchRecentSheets(baseURL: URL(string: "https://example.test")!)

        XCTAssertEqual(capturedRequest?.url?.path, "/api/v1/test_sheets/recent")
        XCTAssertEqual(capturedRequest?.httpMethod, "GET")
        XCTAssertEqual(sheets.map(\.sheetID), ["sheet_123", "sheet_456"])
        XCTAssertEqual(sheets.first?.title, "July LPS comparison sheet")
        XCTAssertNil(sheets.last?.title)
    }

    func testFetchManifestThrowsBadStatusOnServerError() async throws {
        MockURLProtocol.handler = { request in
            (HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!, Data())
        }

        await XCTAssertThrowsErrorAsync(try await client().fetchManifest(baseURL: URL(string: "https://example.test")!, sheetCode: "sheet_123")) { error in
            XCTAssertNotNil(error as? APIError)
        }
    }

    private func client() -> APIClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        return APIClient(token: "token", session: URLSession(configuration: configuration))
    }

    private static let manifestFixture = #"""
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
    """#

    private static let recentSheetsFixture = #"""
    {
      "sheets": [
        {"sheet_id": "sheet_123", "manifest_url": "https://example.test/api/v1/test_sheets/sheet_123/manifest", "title": "July LPS comparison sheet"},
        {"sheet_id": "sheet_456", "manifest_url": "https://example.test/api/v1/test_sheets/sheet_456/manifest", "title": null}
      ]
    }
    """#
}

private func XCTAssertThrowsErrorAsync<T>(
    _ expression: @autoclosure () async throws -> T,
    file: StaticString = #filePath,
    line: UInt = #line,
    _ errorHandler: (Error) -> Void = { _ in }
) async {
    do {
        _ = try await expression()
        XCTFail("Expected an error to be thrown", file: file, line: line)
    } catch {
        errorHandler(error)
    }
}

private final class MockURLProtocol: URLProtocol {
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
