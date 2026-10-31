import Foundation
import MeasurementCore
import XCTest
import ColorMatchingLPSAppCore

private protocol RankedResultsFetching {
    func fetchRankedResults(sheetID: String, baseURL: URL) async throws -> [PairScore]
}

private struct RankedResultsNotImplemented: LocalizedError {
    var errorDescription: String? {
        "APIClient.fetchRankedResults(sheetID:baseURL:) is not implemented yet; the generated OpenAPI client must expose ranked results (issue #5)"
    }
}

private extension RankedResultsFetching {
    func fetchRankedResults(sheetID: String, baseURL: URL) async throws -> [PairScore] {
        throw RankedResultsNotImplemented()
    }
}

extension APIClient: RankedResultsFetching {}

final class APIClientWireContractTests: XCTestCase {
    override func tearDown() {
        WireStubURLProtocol.handler = nil
        super.tearDown()
    }

    func testFetchManifestBySheetCodeDecodesProseContractManifest() async throws {
        let payload = """
        {
          "schema_version": "lps-sheet-manifest/v1",
          "sheet_version": "lps-letter-grid-v1",
          "sheet_id": "sheet_1",
          "manifest_url": "https://example.test/api/v1/test_sheets/sheet_1/manifest",
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
            },
            {
              "id": "patch_2",
              "role": "pair_color",
              "pair_id": "pair_1",
              "pair_side": "second",
              "reference_role": null,
              "source_color": "#00FF00",
              "safe_inset_mm": 1.5,
              "rect": {"x": 36, "y": 38, "width": 16, "height": 10}
            },
            {
              "id": "patch_ref",
              "role": "reference",
              "pair_id": null,
              "pair_side": null,
              "reference_role": "white",
              "source_color": null,
              "safe_inset_mm": 1.0,
              "rect": {"x": 56, "y": 38, "width": 12, "height": 10}
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
        var capturedRequest: URLRequest?
        WireStubURLProtocol.handler = { request in
            capturedRequest = request
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data(payload.utf8))
        }

        let manifest = try await APIClient(token: "token", session: Self.stubbedSession())
            .fetchManifest(baseURL: URL(string: "https://example.test")!, sheetCode: "sheet_1")

        XCTAssertEqual(capturedRequest?.url?.path, "/api/v1/test_sheets/sheet_1/manifest")
        XCTAssertEqual(capturedRequest?.value(forHTTPHeaderField: "Authorization"), "Bearer token")
        XCTAssertEqual(manifest.schemaVersion, "lps-sheet-manifest/v1")
        XCTAssertEqual(manifest.sheetVersion, "lps-letter-grid-v1")
        XCTAssertEqual(manifest.sheetID, "sheet_1")
        XCTAssertEqual(manifest.manifestURL, URL(string: "https://example.test/api/v1/test_sheets/sheet_1/manifest"))
        XCTAssertEqual(manifest.page.units, "mm")
        XCTAssertEqual(manifest.page.width, 215.9)
        XCTAssertEqual(manifest.page.height, 279.4)
        XCTAssertEqual(manifest.registrationMarkers.first?.role, "top_left")
        XCTAssertEqual(manifest.registrationMarkers.first?.shape, "solid_square")
        XCTAssertEqual(manifest.registrationMarkers.first?.rect, Rect(x: 12, y: 12, width: 8, height: 8))
        XCTAssertEqual(manifest.patches.map(\.id), ["patch_1", "patch_2", "patch_ref"])
        XCTAssertEqual(manifest.patches[0].role, "pair_color")
        XCTAssertEqual(manifest.patches[0].pairID, "pair_1")
        XCTAssertEqual(manifest.patches[0].pairSide, "first")
        XCTAssertEqual(manifest.patches[0].sourceColor, "#FF0000")
        XCTAssertEqual(manifest.patches[0].safeInsetMM, 1.5)
        XCTAssertEqual(manifest.patches[0].rect, Rect(x: 16, y: 38, width: 16, height: 10))
        XCTAssertEqual(manifest.patches[2].role, "reference")
        XCTAssertEqual(manifest.patches[2].referenceRole, "white")
        XCTAssertNil(manifest.patches[2].pairID)
        XCTAssertEqual(manifest.pairs, [
            PairManifest(
                id: "pair_1",
                gridRow: 0,
                gridCol: 1,
                firstPatchID: "patch_1",
                secondPatchID: "patch_2",
                sourceColors: ["#FF0000", "#00FF00"]
            )
        ])
    }

    func testFetchRecentSheetsDecodesSheetsIncludingUntitledSheet() async throws {
        let payload = """
        {
          "sheets": [
            {
              "sheet_id": "sheet_1",
              "manifest_url": "https://example.test/api/v1/test_sheets/sheet_1/manifest",
              "title": "July LPS comparison sheet"
            },
            {
              "sheet_id": "sheet_2",
              "manifest_url": "https://example.test/api/v1/test_sheets/sheet_2/manifest",
              "title": null
            }
          ]
        }
        """
        var capturedRequest: URLRequest?
        WireStubURLProtocol.handler = { request in
            capturedRequest = request
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data(payload.utf8))
        }

        let sheets = try await APIClient(token: "token", session: Self.stubbedSession())
            .fetchRecentSheets(baseURL: URL(string: "https://example.test")!)

        XCTAssertEqual(capturedRequest?.url?.path, "/api/v1/test_sheets/recent")
        XCTAssertEqual(capturedRequest?.value(forHTTPHeaderField: "Authorization"), "Bearer token")
        XCTAssertEqual(sheets.map(\.sheetID), ["sheet_1", "sheet_2"])
        XCTAssertEqual(sheets.first?.title, "July LPS comparison sheet")
        XCTAssertEqual(sheets.first?.manifestURL, URL(string: "https://example.test/api/v1/test_sheets/sheet_1/manifest"))
        XCTAssertEqual(sheets.last?.sheetID, "sheet_2")
        XCTAssertNil(sheets.last?.title)
        XCTAssertEqual(sheets.last?.manifestURL, URL(string: "https://example.test/api/v1/test_sheets/sheet_2/manifest"))
    }

    func testFetchRecentSheetsThrowsOnNonSuccessStatus() async throws {
        WireStubURLProtocol.handler = { request in
            (HTTPURLResponse(url: request.url!, statusCode: 503, httpVersion: nil, headerFields: nil)!, Data(#"{"error":"unavailable"}"#.utf8))
        }

        do {
            _ = try await APIClient(token: nil, session: Self.stubbedSession())
                .fetchRecentSheets(baseURL: URL(string: "https://example.test")!)
            XCTFail("expected a non-success status to throw after the generated-client swap")
        } catch {
        }
    }

    func testFetchRankedResultsDecodesRankedPairScores() async throws {
        let payload = """
        {
          "results": [
            {"pair_id": "pair_1", "distance": 0.035, "similarity": 0.965, "algorithm_version": "lps-distance-v1"},
            {"pair_id": "pair_2", "distance": 0.21, "similarity": 0.79, "algorithm_version": "lps-distance-v1"}
          ]
        }
        """
        var capturedRequest: URLRequest?
        WireStubURLProtocol.handler = { request in
            capturedRequest = request
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data(payload.utf8))
        }

        let fetcher: RankedResultsFetching = APIClient(token: "token", session: Self.stubbedSession())
        let ranked = try await fetcher.fetchRankedResults(sheetID: "sheet_1", baseURL: URL(string: "https://example.test")!)

        XCTAssertEqual(capturedRequest?.url?.path, "/api/v1/test_sheets/sheet_1/ranked_results")
        XCTAssertEqual(capturedRequest?.value(forHTTPHeaderField: "Authorization"), "Bearer token")
        XCTAssertEqual(ranked, [
            PairScore(pairID: "pair_1", distance: 0.035, similarity: 0.965, algorithmVersion: "lps-distance-v1"),
            PairScore(pairID: "pair_2", distance: 0.21, similarity: 0.79, algorithmVersion: "lps-distance-v1"),
        ])
    }

    private static func stubbedSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [WireStubURLProtocol.self]
        return URLSession(configuration: configuration)
    }
}

private final class WireStubURLProtocol: URLProtocol {
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
