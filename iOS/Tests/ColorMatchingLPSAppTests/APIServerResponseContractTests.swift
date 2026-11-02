import Foundation
import MeasurementCore
import XCTest
@testable import ColorMatchingLPSAppCore

final class APIServerResponseContractTests: XCTestCase {
    override func tearDown() {
        ServerResponseStubURLProtocol.handler = nil
        super.tearDown()
    }

    func testFetchManifestDecodesPublishedManifestFixture() async throws {
        stub(status: 200, json: PublishedServerFixtures.manifest)

        let manifest = try await client().fetchManifest(
            baseURL: URL(string: "https://example.test")!,
            sheetCode: "sheet_1"
        )

        XCTAssertEqual(manifest.schemaVersion, "lps-sheet-manifest/v1")
        XCTAssertEqual(manifest.sheetID, "sheet_1")
        XCTAssertEqual(manifest.page.width, 215.9)
        XCTAssertEqual(manifest.patches.map(\.id), ["pair_1#first", "pair_1#second"])
        XCTAssertEqual(manifest.patches.first?.pairID, "pair_1")
        XCTAssertEqual(manifest.pairs.first?.firstPatchID, "pair_1#first")
    }

    func testFetchRecentSheetsDecodesRealServerFixtureWithNullTitle() async throws {
        stub(status: 200, json: PublishedServerFixtures.recentSheets)

        let sheets = try await client().fetchRecentSheets(baseURL: URL(string: "https://example.test")!)

        XCTAssertEqual(sheets.count, 1)
        XCTAssertEqual(sheets.first?.sheetID, "sheet_1")
        XCTAssertEqual(sheets.first?.manifestURL.absoluteString, "https://example.test/api/v1/test_sheets/sheet_1/manifest")
        XCTAssertNil(sheets.first?.title)
    }

    func testCreateCaptureDecodesRealServerCreatedResponse() async throws {
        stub(status: 201, json: #"{"capture_id":"41"}"#)

        let response = try await client().createCapture(
            sheetID: "sheet_1",
            baseURL: URL(string: "https://example.test")!,
            metadata: PublishedServerFixtures.captureMetadata,
            quality: CaptureQuality(detectedMarkerCount: 4, blurScore: 0.75, rejections: [])
        )

        XCTAssertEqual(response.captureID, "41")
    }

    func testUploadMeasurementsAcceptsRealServerOKJSONResponse() async throws {
        stub(status: 200, json: #"{"capture_id":"41","measurement_count":1,"pair_score_count":1}"#)

        try await client().uploadMeasurements(
            captureID: "41",
            baseURL: URL(string: "https://example.test")!,
            measurements: [PublishedServerFixtures.measurement],
            scores: [PairScore(pairID: "pair_1", distance: 0.035, similarity: 0.965, algorithmVersion: LPSScorer.algorithmVersion)]
        )
    }

    func testUploadJudgmentsAcceptsRealServerOKJSONResponse() async throws {
        stub(status: 200, json: #"{"capture_id":"41","judgment_count":1}"#)

        try await client().uploadJudgments(
            captureID: "41",
            baseURL: URL(string: "https://example.test")!,
            judgments: [PairJudgment(pairID: "pair_1", judgment: "near_match")]
        )
    }

    func testFetchManifestSurfacesUnauthorizedStatusAsError() async throws {
        stub(status: 401, json: #"{"errors":{"detail":"Unauthorized"}}"#)

        do {
            _ = try await client().fetchManifest(baseURL: URL(string: "https://example.test")!, sheetCode: "sheet_1")
            XCTFail("Expected an error for a 401 response.")
        } catch {
            XCTAssertTrue(error is APIError)
        }
    }

    private func client() -> APIClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ServerResponseStubURLProtocol.self]
        return APIClient(token: "token", session: URLSession(configuration: configuration))
    }

    private func stub(status: Int, json: String) {
        ServerResponseStubURLProtocol.handler = { request in
            (HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!, Data(json.utf8))
        }
    }
}

private enum PublishedServerFixtures {
    static let manifest = """
    {
      "schema_version": "lps-sheet-manifest/v1",
      "sheet_id": "sheet_1",
      "sheet_version": "lps-letter-grid-v1",
      "manifest_url": "https://example.test/api/v1/test_sheets/sheet_1/manifest",
      "created_at": "2026-07-25T12:00:00Z",
      "page": {"units": "mm", "width": 215.9, "height": 279.4},
      "registration_markers": [
        {"role": "top_left", "shape": "solid_square", "rect": {"x": 12, "y": 12, "width": 8, "height": 8}}
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
    """

    static let recentSheets = """
    {
      "sheets": [
        {
          "sheet_id": "sheet_1",
          "manifest_url": "https://example.test/api/v1/test_sheets/sheet_1/manifest",
          "title": null
        }
      ]
    }
    """

    static let captureMetadata = CaptureMetadata(
        deviceModel: "iPhone",
        lens: "built_in_wide_angle",
        exposureDurationSeconds: 0.016,
        iso: 100,
        focusLensPosition: 0.42,
        whiteBalanceGains: WhiteBalanceGains(red: 1.2, green: 1.0, blue: 1.4),
        imageWidth: 4032,
        imageHeight: 3024,
        appVersion: "0.1.0",
        timestamp: Date(timeIntervalSince1970: 0)
    )

    static let measurement: PatchMeasurement = {
        let rgb = RGB(r: 0.12, g: 0.10, b: 0.02)
        let stats = ChannelStats(
            median: rgb,
            mean: rgb,
            standardDeviation: RGB(r: 0.01, g: 0.01, b: 0.004),
            min: rgb,
            max: rgb,
            sampleCount: 900,
            clippingFraction: 0
        )
        return PatchMeasurement(
            patchID: "pair_1#first",
            linearRGBMedian: rgb,
            normalizedLinearRGBMedian: rgb,
            stats: stats
        )
    }()
}

private final class ServerResponseStubURLProtocol: URLProtocol {
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
