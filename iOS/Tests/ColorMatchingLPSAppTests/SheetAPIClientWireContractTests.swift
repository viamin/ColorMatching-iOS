import Foundation
import MeasurementCore
import XCTest
@testable import ColorMatchingLPSAppCore

final class SheetAPIClientWireContractTests: XCTestCase {
    override func tearDown() {
        WireContractURLProtocol.handler = nil
        super.tearDown()
    }

    func testFetchManifestBySheetCodeRequestsManifestPathWithBearerToken() async throws {
        var capturedRequest: URLRequest?
        WireContractURLProtocol.handler = { request in
            capturedRequest = request
            return (
                HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                Data(Self.minimalManifestJSON.utf8)
            )
        }

        let manifest = try await client().fetchManifest(
            baseURL: URL(string: "https://api.example.test")!,
            sheetCode: "sheet_1"
        )

        XCTAssertEqual(capturedRequest?.httpMethod, "GET")
        XCTAssertEqual(capturedRequest?.url?.path, "/api/v1/test_sheets/sheet_1/manifest")
        XCTAssertEqual(capturedRequest?.value(forHTTPHeaderField: "Authorization"), "Bearer token")
        XCTAssertEqual(manifest.sheetID, "sheet_1")
        XCTAssertEqual(manifest.patches.count, 1)
        XCTAssertEqual(manifest.pairs.first?.firstPatchID, "patch_1")
    }

    func testFetchManifestFromAbsoluteURLUsesProvidedOrigin() async throws {
        var capturedRequest: URLRequest?
        WireContractURLProtocol.handler = { request in
            capturedRequest = request
            return (
                HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                Data(Self.minimalManifestJSON.utf8)
            )
        }

        let manifest = try await client().fetchManifest(
            from: URL(string: "https://sheets.example.test/api/v1/test_sheets/sheet_9/manifest")!
        )

        XCTAssertEqual(
            capturedRequest?.url?.absoluteString,
            "https://sheets.example.test/api/v1/test_sheets/sheet_9/manifest"
        )
        XCTAssertEqual(capturedRequest?.value(forHTTPHeaderField: "Authorization"), "Bearer token")
        XCTAssertEqual(manifest.sheetID, "sheet_1")
    }

    func testFetchRecentSheetsRequestsRecentPath() async throws {
        var capturedRequest: URLRequest?
        WireContractURLProtocol.handler = { request in
            capturedRequest = request
            return (
                HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                Data(#"{"sheets":[]}"#.utf8)
            )
        }

        _ = try await client().fetchRecentSheets(baseURL: URL(string: "https://api.example.test")!)

        XCTAssertEqual(capturedRequest?.httpMethod, "GET")
        XCTAssertEqual(capturedRequest?.url?.path, "/api/v1/test_sheets/recent")
        XCTAssertEqual(capturedRequest?.value(forHTTPHeaderField: "Authorization"), "Bearer token")
    }

    private func client() -> APIClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [WireContractURLProtocol.self]
        return APIClient(token: "token", session: URLSession(configuration: configuration))
    }

    private static let minimalManifestJSON = """
    {
      "schema_version": "lps-sheet-manifest/v1",
      "sheet_version": "lps-letter-grid-v1",
      "sheet_id": "sheet_1",
      "manifest_url": "https://api.example.test/api/v1/test_sheets/sheet_1/manifest",
      "page": {"units": "mm", "width": 215.9, "height": 279.4},
      "registration_markers": [],
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
}

private final class WireContractURLProtocol: URLProtocol {
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
