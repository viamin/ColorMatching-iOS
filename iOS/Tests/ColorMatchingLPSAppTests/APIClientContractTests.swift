import Foundation
import MeasurementCore
import XCTest
@testable import ColorMatchingLPSAppCore

final class APIClientContractTests: XCTestCase {
    override func tearDown() {
        ContractStubURLProtocol.handler = nil
        super.tearDown()
    }

    func testFetchManifestDecodesContractManifest() async throws {
        ContractStubURLProtocol.handler = { _ in
            Self.ok(ContractFixtures.manifest)
        }

        let manifest = try await client().fetchManifest(
            baseURL: URL(string: "https://example.test")!,
            sheetCode: "sheet_123"
        )

        XCTAssertEqual(manifest.schemaVersion, "lps-sheet-manifest/v1")
        XCTAssertEqual(manifest.sheetVersion, "lps-letter-grid-v1")
        XCTAssertEqual(manifest.sheetID, "sheet_123")
        XCTAssertEqual(manifest.manifestURL, URL(string: "https://example.test/api/v1/test_sheets/sheet_123/manifest"))
        XCTAssertEqual(manifest.page.units, "mm")
        XCTAssertEqual(manifest.page.width, 215.9)
        XCTAssertEqual(manifest.page.height, 279.4)
        XCTAssertEqual(manifest.registrationMarkers.first?.role, "top_left")
        XCTAssertEqual(manifest.registrationMarkers.first?.shape, "solid_square")
        XCTAssertEqual(manifest.registrationMarkers.first?.rect, Rect(x: 12, y: 12, width: 8, height: 8))
        XCTAssertEqual(
            manifest.patches,
            [
                Patch(
                    id: "patch_1",
                    role: "pair_color",
                    pairID: "pair_1",
                    pairSide: "first",
                    referenceRole: nil,
                    sourceColor: "#FF0000",
                    safeInsetMM: 1.5,
                    rect: Rect(x: 16, y: 38, width: 16, height: 10)
                )
            ]
        )
        XCTAssertEqual(
            manifest.pairs,
            [
                PairManifest(
                    id: "pair_1",
                    gridRow: 0,
                    gridCol: 1,
                    firstPatchID: "patch_1",
                    secondPatchID: "patch_2",
                    sourceColors: ["#FF0000", "#00FF00"]
                )
            ]
        )
    }

    func testFetchManifestSendsGETWithAuthorizationAndContractPath() async throws {
        var capturedRequest: URLRequest?
        ContractStubURLProtocol.handler = { request in
            capturedRequest = request
            return Self.ok(ContractFixtures.manifest)
        }

        _ = try await client().fetchManifest(
            baseURL: URL(string: "https://example.test")!,
            sheetCode: "sheet_123"
        )

        XCTAssertEqual(capturedRequest?.httpMethod, "GET")
        XCTAssertEqual(capturedRequest?.url?.path, "/api/v1/test_sheets/sheet_123/manifest")
        XCTAssertEqual(capturedRequest?.value(forHTTPHeaderField: "Authorization"), "Bearer token")
    }

    func testFetchRecentSheetsDecodesSheetsIncludingNullTitle() async throws {
        ContractStubURLProtocol.handler = { _ in
            Self.ok(ContractFixtures.recentSheets)
        }

        let sheets = try await client().fetchRecentSheets(baseURL: URL(string: "https://example.test")!)

        XCTAssertEqual(sheets.map(\.sheetID), ["sheet_123", "sheet_456"])
        XCTAssertEqual(sheets[0].title, "July LPS comparison sheet")
        XCTAssertNil(sheets[1].title)
        XCTAssertEqual(sheets[1].manifestURL, URL(string: "https://example.test/api/v1/test_sheets/sheet_456/manifest"))
    }

    private func client() -> APIClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ContractStubURLProtocol.self]
        return APIClient(token: "token", session: URLSession(configuration: configuration))
    }

    private static func ok(_ payload: String) -> (HTTPURLResponse, Data) {
        return (
            HTTPURLResponse(url: URL(string: "https://example.test")!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
            Data(payload.utf8)
        )
    }
}

private enum ContractFixtures {
    static let manifest = ##"""
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
    """##

    static let recentSheets = ##"""
    {
      "sheets": [
        {
          "sheet_id": "sheet_123",
          "manifest_url": "https://example.test/api/v1/test_sheets/sheet_123/manifest",
          "title": "July LPS comparison sheet"
        },
        {
          "sheet_id": "sheet_456",
          "manifest_url": "https://example.test/api/v1/test_sheets/sheet_456/manifest",
          "title": null
        }
      ]
    }
    """##
}

private final class ContractStubURLProtocol: URLProtocol {
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
