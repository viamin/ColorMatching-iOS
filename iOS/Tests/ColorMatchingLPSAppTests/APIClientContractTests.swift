import Foundation
import MeasurementCore
import XCTest
@testable import ColorMatchingLPSAppCore

final class APIClientContractTests: XCTestCase {
    override func tearDown() {
        ContractStubURLProtocol.handler = nil
        super.tearDown()
    }

    func testFetchManifestDecodesProseContractFixture() async throws {
        var capturedRequest: URLRequest?
        ContractStubURLProtocol.handler = { request in
            capturedRequest = request
            return (Self.okResponse(for: request), Data(Self.manifestFixture.utf8))
        }

        let url = try XCTUnwrap(URL(string: "https://example.test/api/v1/test_sheets/sheet_123/manifest"))
        let manifest = try await makeClient().fetchManifest(from: url)

        XCTAssertEqual(capturedRequest?.httpMethod, "GET")
        XCTAssertEqual(capturedRequest?.url?.path, "/api/v1/test_sheets/sheet_123/manifest")
        XCTAssertEqual(capturedRequest?.value(forHTTPHeaderField: "Authorization"), "Bearer token")
        assertManifestContents(manifest)
    }

    func testFetchManifestBySheetCodeBuildsManifestPath() async throws {
        var capturedRequest: URLRequest?
        ContractStubURLProtocol.handler = { request in
            capturedRequest = request
            return (Self.okResponse(for: request), Data(Self.minimalManifestFixture.utf8))
        }

        let manifest = try await makeClient().fetchManifest(
            baseURL: URL(string: "https://example.test")!,
            sheetCode: "sheet_1"
        )

        XCTAssertEqual(capturedRequest?.url?.path, "/api/v1/test_sheets/sheet_1/manifest")
        XCTAssertEqual(manifest.sheetID, "sheet_1")
    }

    func testFetchRecentSheetsDecodesSheetsIncludingNullTitle() async throws {
        var capturedRequest: URLRequest?
        ContractStubURLProtocol.handler = { request in
            capturedRequest = request
            return (Self.okResponse(for: request), Data(Self.recentSheetsFixture.utf8))
        }

        let sheets = try await makeClient().fetchRecentSheets(baseURL: URL(string: "https://example.test")!)

        XCTAssertEqual(capturedRequest?.httpMethod, "GET")
        XCTAssertEqual(capturedRequest?.url?.path, "/api/v1/test_sheets/recent")
        XCTAssertEqual(capturedRequest?.value(forHTTPHeaderField: "Authorization"), "Bearer token")
        XCTAssertEqual(sheets.count, 2)
        XCTAssertEqual(sheets[0].sheetID, "sheet_123")
        XCTAssertEqual(sheets[0].title, "July LPS comparison sheet")
        XCTAssertEqual(sheets[0].manifestURL.absoluteString, "https://example.test/api/v1/test_sheets/sheet_123/manifest")
        XCTAssertEqual(sheets[1].sheetID, "sheet_456")
        XCTAssertNil(sheets[1].title)
    }

    private func assertManifestContents(_ manifest: SheetManifest) {
        XCTAssertEqual(manifest.schemaVersion, "lps-sheet-manifest/v1")
        XCTAssertEqual(manifest.sheetVersion, "lps-letter-grid-v1")
        XCTAssertEqual(manifest.sheetID, "sheet_123")
        XCTAssertEqual(manifest.manifestURL.absoluteString, "https://example.test/api/v1/test_sheets/sheet_123/manifest")
        XCTAssertEqual(manifest.page.units, "mm")
        XCTAssertEqual(manifest.page.width, 215.9, accuracy: 0.0001)
        XCTAssertEqual(manifest.page.height, 279.4, accuracy: 0.0001)
        assertRegistrationMarkers(manifest.registrationMarkers)
        assertPatches(manifest.patches)
        assertPairs(manifest.pairs)
    }

    private func assertRegistrationMarkers(_ markers: [RegistrationMarker]) {
        XCTAssertEqual(markers.count, 1)
        XCTAssertEqual(markers.first?.role, "top_left")
        XCTAssertEqual(markers.first?.shape, "solid_square")
        XCTAssertEqual(markers.first?.rect, Rect(x: 12, y: 12, width: 8, height: 8))
    }

    private func assertPatches(_ patches: [Patch]) {
        XCTAssertEqual(patches.count, 1)
        let patch = patches[0]
        XCTAssertEqual(patch.id, "patch_1")
        XCTAssertEqual(patch.role, "pair_color")
        XCTAssertEqual(patch.pairID, "pair_1")
        XCTAssertEqual(patch.pairSide, "first")
        XCTAssertNil(patch.referenceRole)
        XCTAssertEqual(patch.sourceColor, "#FF0000")
        XCTAssertEqual(patch.safeInsetMM, 1.5, accuracy: 0.0001)
        XCTAssertEqual(patch.rect, Rect(x: 16, y: 38, width: 16, height: 10))
    }

    private func assertPairs(_ pairs: [PairManifest]) {
        XCTAssertEqual(pairs.count, 1)
        let pair = pairs[0]
        XCTAssertEqual(pair.id, "pair_1")
        XCTAssertEqual(pair.firstPatchID, "patch_1")
        XCTAssertEqual(pair.secondPatchID, "patch_2")
        XCTAssertEqual(pair.sourceColors, ["#FF0000", "#00FF00"])
        XCTAssertEqual(pair.gridRow, 0)
        XCTAssertEqual(pair.gridCol, 1)
    }

    private func makeClient() -> APIClient {
        APIClient(token: "token", session: ContractStubURLProtocol.stubbedSession())
    }

    private static func okResponse(for request: URLRequest) -> HTTPURLResponse {
        HTTPURLResponse(
            url: request.url!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
    }

    private static let manifestFixture = ##"""
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

    private static let minimalManifestFixture = ##"""
    {
      "schema_version": "lps-sheet-manifest/v1",
      "sheet_version": "lps-letter-grid-v1",
      "sheet_id": "sheet_1",
      "manifest_url": "https://example.test/api/v1/test_sheets/sheet_1/manifest",
      "page": {"units": "mm", "width": 210, "height": 297},
      "registration_markers": [],
      "patches": [],
      "pairs": []
    }
    """##

    private static let recentSheetsFixture = ##"""
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
