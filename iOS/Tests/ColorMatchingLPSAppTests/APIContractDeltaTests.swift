import Foundation
import MeasurementCore
import XCTest
@testable import ColorMatchingLPSAppCore

/// Exercises `APIClient` against fixtures shaped like the *real* published
/// `color_matching` OpenAPI contract (viamin/color_matching#110 / PR #113),
/// not the hand-written prose contract in `docs/color-matching-api-contract.md`.
///
/// See `docs/openapi-contract-deltas.md` for the full list of deltas this
/// suite is derived from. Some tests here are expected to fail today — they
/// pin down known drift between what this app sends and what the real
/// schema documents, ahead of the generated-client migration.
final class APIContractDeltaTests: XCTestCase {
    override func tearDown() {
        DeltaMockURLProtocol.handler = nil
        super.tearDown()
    }

    // MARK: - Passing regression locks (real response shapes decode today)

    func testManifestDecodesRealPublishedShapeIncludingUndeclaredPrinterAndCaptureProfile() async throws {
        DeltaMockURLProtocol.handler = { request in
            (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Self.realManifestFixture)
        }

        let manifest = try await client().fetchManifest(from: URL(string: "https://example.test/api/v1/test_sheets/sheet_123/manifest")!)

        XCTAssertEqual(manifest.schemaVersion, "lps-sheet-manifest/v1")
        XCTAssertEqual(manifest.sheetID, "sheet_123")
        XCTAssertEqual(manifest.patches.count, 2)
        XCTAssertEqual(manifest.pairs.first?.id, "pair_1")
    }

    func testRecentSheetsDecodesRealShapeWithNullTitle() async throws {
        DeltaMockURLProtocol.handler = { request in
            (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data(#"""
            {"sheets": [{"sheet_id": "sheet_123", "manifest_url": "https://example.test/api/v1/test_sheets/sheet_123/manifest", "title": null}]}
            """#.utf8))
        }

        let sheets = try await client().fetchRecentSheets(baseURL: URL(string: "https://example.test")!)

        XCTAssertEqual(sheets.first?.sheetID, "sheet_123")
        XCTAssertNil(sheets.first?.title)
    }

    func testCreateCaptureDecodesRealCaptureCreatedResponse() async throws {
        DeltaMockURLProtocol.handler = { request in
            (HTTPURLResponse(url: request.url!, statusCode: 201, httpVersion: nil, headerFields: nil)!, Data(#"{"capture_id":"42"}"#.utf8))
        }

        let response = try await client().createCapture(
            sheetID: "sheet_1",
            baseURL: URL(string: "https://example.test")!,
            metadata: Self.metadata,
            quality: CaptureQuality(detectedMarkerCount: 4, blurScore: 0.75, rejections: [])
        )

        XCTAssertEqual(response.captureID, "42")
    }

    // MARK: - Red: known drift from the real contract (viamin/color_matching#110)

    /// `MeasurementUploadRequest` in the real spec only allows top-level
    /// `measurements` and `pair_scores`, with each measurement limited to
    /// `patch_id`, `linear_rgb_median`, `normalized_linear_rgb_median`.
    /// `APIClient.uploadMeasurements` sends an undocumented top-level
    /// `scoring_algorithm_version` and an undocumented per-measurement
    /// `stats` object. This fails until the request body is trimmed to the
    /// published schema (docs/openapi-contract-deltas.md, delta #1).
    func testUploadMeasurementsBodyMatchesPublishedMeasurementUploadRequestSchema() async throws {
        var capturedBody: Data?
        DeltaMockURLProtocol.handler = { request in
            capturedBody = request.httpBodyStream.flatMap(Self.readBody) ?? request.httpBody
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data(#"{"capture_id":"1","measurement_count":1,"pair_score_count":1}"#.utf8))
        }

        let rgb = RGB(r: 0.2, g: 0.3, b: 0.4)
        let stats = ChannelStats(median: rgb, mean: rgb, standardDeviation: RGB(r: 0.01, g: 0.01, b: 0.01), min: rgb, max: rgb, sampleCount: 9, clippingFraction: 0)
        try await client().uploadMeasurements(
            captureID: "cap_1",
            baseURL: URL(string: "https://example.test")!,
            measurements: [PatchMeasurement(patchID: "patch_1", linearRGBMedian: rgb, normalizedLinearRGBMedian: rgb, stats: stats)],
            scores: [PairScore(pairID: "pair_1", distance: 0.1, similarity: 0.9, algorithmVersion: "lps-distance-v1")]
        )

        let json = try XCTUnwrap(Self.jsonObject(from: capturedBody) as? [String: Any])
        XCTAssertEqual(
            Set(json.keys), ["measurements", "pair_scores"],
            "real MeasurementUploadRequest schema declares no top-level scoring_algorithm_version"
        )
        let measurement = try XCTUnwrap((json["measurements"] as? [[String: Any]])?.first)
        XCTAssertEqual(
            Set(measurement.keys), ["patch_id", "linear_rgb_median", "normalized_linear_rgb_median"],
            "real MeasurementUploadRequest schema declares no per-measurement stats object"
        )
    }

    private func client() -> APIClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [DeltaMockURLProtocol.self]
        return APIClient(token: "token", session: URLSession(configuration: configuration))
    }

    private static var metadata: CaptureMetadata {
        CaptureMetadata(
            deviceModel: "iPhone",
            lens: "wide",
            exposureDurationSeconds: 0.01,
            iso: 100,
            focusLensPosition: 0.4,
            whiteBalanceGains: WhiteBalanceGains(red: 1.1, green: 1.0, blue: 1.2),
            imageWidth: 100,
            imageHeight: 200,
            appVersion: "0.1.0",
            timestamp: Date(timeIntervalSince1970: 0)
        )
    }

    /// Shaped exactly like `ColorMatchingWeb.TestSheetJSON.manifest/2` in
    /// viamin/color_matching (commit 05062f5381a6f76413cc2bdf1cb2cc08a1b70ff7),
    /// including the `printer_profile`/`capture_profile` fields the real
    /// `Manifest` OpenAPI schema leaves undeclared (delta #5).
    private static var realManifestFixture: Data {
        Data(#"""
        {
          "schema_version": "lps-sheet-manifest/v1",
          "sheet_id": "sheet_123",
          "sheet_version": "lps-letter-grid-v1",
          "manifest_url": "https://example.test/api/v1/test_sheets/sheet_123/manifest",
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
            "print_settings": null,
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
            {"id": "pair_1#first", "role": "pair_color", "pair_id": "pair_1", "pair_side": "first", "reference_role": null, "source_color": "#FF0000", "safe_inset_mm": 1.5, "rect": {"x": 16, "y": 38, "width": 16, "height": 10}},
            {"id": "pair_1#second", "role": "pair_color", "pair_id": "pair_1", "pair_side": "second", "reference_role": null, "source_color": "#00FF00", "safe_inset_mm": 1.5, "rect": {"x": 36, "y": 38, "width": 16, "height": 10}}
          ],
          "pairs": [
            {"id": "pair_1", "first_patch_id": "pair_1#first", "second_patch_id": "pair_1#second", "source_colors": ["#FF0000", "#00FF00"], "grid_row": 0, "grid_col": 1}
          ]
        }
        """#.utf8)
    }

    private static func jsonObject(from data: Data?) throws -> Any {
        try JSONSerialization.jsonObject(with: XCTUnwrap(data))
    }

    private static func readBody(_ stream: InputStream) -> Data {
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 1024)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            if count > 0 {
                data.append(buffer, count: count)
            } else {
                break
            }
        }
        return data
    }
}

private final class DeltaMockURLProtocol: URLProtocol {
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
