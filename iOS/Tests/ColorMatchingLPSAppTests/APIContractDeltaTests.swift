import Foundation
import MeasurementCore
import XCTest
@testable import ColorMatchingLPSAppCore

/// Characterization and contract-delta tests for the migration tracked in
/// https://github.com/viamin/ColorMatching-iOS/issues/5.
///
/// "The published schema says X" below is sourced from `viamin/color_matching`
/// commit `094bd6d3443ddacbda7e63354299867eb5bdfa9f` (merged via
/// viamin/color_matching#113, which closed viamin/color_matching#110):
/// `lib/color_matching_web/api_schemas.ex` for declared shapes and
/// `lib/color_matching_web/controllers/test_sheet_json.ex` for what the
/// server actually renders. Full writeup in
/// docs/color-matching-api-contract-deltas.md.
///
/// This app has no `swift-openapi-generator` client yet (that lands in the
/// implementation follow-up), so these tests exercise the existing
/// hand-written `APIClient` to pin down deltas that the generated client
/// will need to account for.
final class APIContractDeltaTests: XCTestCase {
    override func tearDown() {
        DeltaMockURLProtocol.handler = nil
        super.tearDown()
    }

    // MARK: - Deltas between today's hand-written client and the published schema

    /// RED: `ColorMatchingWeb.ApiSchemas.MeasurementUploadRequest` only
    /// declares `measurements` and `pair_scores` as top-level properties.
    /// This client also sends a top-level `scoring_algorithm_version`, which
    /// has no home in the published schema (the schema carries algorithm
    /// version per-pair instead, via `pair_scores[].algorithm_version`). A
    /// generated request body type will have no slot for this field.
    func testUploadMeasurementsRequestBodyMatchesPublishedSchemaKeys() async throws {
        var capturedBody: Data?
        DeltaMockURLProtocol.handler = { request in
            capturedBody = request.httpBodyStream.flatMap(Self.readBody) ?? request.httpBody
            return (HTTPURLResponse(url: request.url!, statusCode: 204, httpVersion: nil, headerFields: nil)!, Data())
        }

        let rgb = RGB(r: 0.2, g: 0.3, b: 0.4)
        let stats = ChannelStats(median: rgb, mean: rgb, standardDeviation: RGB(r: 0.01, g: 0.01, b: 0.01), min: rgb, max: rgb, sampleCount: 9, clippingFraction: 0)
        try await client().uploadMeasurements(
            captureID: "cap_1",
            baseURL: URL(string: "https://example.test")!,
            measurements: [PatchMeasurement(patchID: "patch_1", linearRGBMedian: rgb, normalizedLinearRGBMedian: rgb, stats: stats)],
            scores: [PairScore(pairID: "pair_1", distance: 0.1, similarity: 0.9, algorithmVersion: LPSScorer.algorithmVersion)]
        )

        let json = try XCTUnwrap(Self.jsonObject(from: capturedBody) as? [String: Any])
        let publishedSchemaTopLevelKeys: Set<String> = ["measurements", "pair_scores"]
        XCTAssertEqual(
            Set(json.keys),
            publishedSchemaTopLevelKeys,
            "MeasurementUploadRequest in color_matching's published OpenAPI schema has no scoring_algorithm_version property; a generated client will drop this field"
        )
    }

    /// RED: `ColorMatchingWeb.ApiSchemas.MeasurementUploadRequest`'s
    /// `measurements[]` items require `normalized_linear_rgb_median`, but
    /// `PatchMeasurement.normalizedLinearRGBMedian` is optional and Swift's
    /// synthesized `Encodable` omits the key entirely when it is `nil`. A
    /// capture with only raw measurements produces a request body the
    /// published schema disallows.
    func testMeasurementUploadKeepsRequiredNormalizedKeyWhenNil() async throws {
        var capturedBody: Data?
        DeltaMockURLProtocol.handler = { request in
            capturedBody = request.httpBodyStream.flatMap(Self.readBody) ?? request.httpBody
            return (HTTPURLResponse(url: request.url!, statusCode: 204, httpVersion: nil, headerFields: nil)!, Data())
        }

        let rgb = RGB(r: 0.2, g: 0.3, b: 0.4)
        let stats = ChannelStats(median: rgb, mean: rgb, standardDeviation: RGB(r: 0.01, g: 0.01, b: 0.01), min: rgb, max: rgb, sampleCount: 9, clippingFraction: 0)
        try await client().uploadMeasurements(
            captureID: "cap_1",
            baseURL: URL(string: "https://example.test")!,
            measurements: [PatchMeasurement(patchID: "patch_1", linearRGBMedian: rgb, normalizedLinearRGBMedian: nil, stats: stats)],
            scores: []
        )

        let json = try XCTUnwrap(Self.jsonObject(from: capturedBody) as? [String: Any])
        let measurement = try XCTUnwrap((json["measurements"] as? [[String: Any]])?.first)
        XCTAssertNotNil(
            measurement["normalized_linear_rgb_median"],
            "normalized_linear_rgb_median is required by the published MeasurementUploadRequest schema even though PatchMeasurement allows nil"
        )
    }

    // MARK: - Baseline characterization against real server payload shapes
    // (regression guard for the eventual swift-openapi-generator migration)

    /// GREEN today: pins decoding of the manifest payload actually rendered
    /// by `ColorMatchingWeb.TestSheetJSON.manifest/1`, including the
    /// `printer_profile` / `capture_profile` keys that exist on the wire but
    /// have no corresponding property on `SheetManifest` today (see delta
    /// doc item 2). If a future change adds those properties, this fixture
    /// should be extended to assert on them instead of just tolerating them.
    func testManifestDecodesActualServerPayloadShape() throws {
        let json = """
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

        let manifest = try JSONDecoder.deltaSnakeCase.decode(SheetManifest.self, from: Data(json.utf8))

        XCTAssertEqual(manifest.sheetID, "sheet_123")
        XCTAssertEqual(manifest.sheetVersion, "lps-letter-grid-v1")
        XCTAssertEqual(manifest.patches.first?.id, "pair_1#first")
        XCTAssertEqual(manifest.pairs.first?.id, "pair_1")
    }

    /// GREEN today: pins decoding of the `recent` list shape actually
    /// rendered by `ColorMatchingWeb.TestSheetJSON.recent/1`, where `title`
    /// is always `null` server-side.
    func testRecentSheetsDecodesActualServerPayloadShape() async throws {
        DeltaMockURLProtocol.handler = { request in
            let body = """
            {"sheets": [{"sheet_id": "sheet_123", "manifest_url": "https://example.test/api/v1/test_sheets/sheet_123/manifest", "title": null}]}
            """
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data(body.utf8))
        }

        let sheets = try await client().fetchRecentSheets(baseURL: URL(string: "https://example.test")!)

        XCTAssertEqual(sheets.first?.sheetID, "sheet_123")
        XCTAssertNil(sheets.first?.title)
    }

    private func client() -> APIClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [DeltaMockURLProtocol.self]
        return APIClient(token: "token", session: URLSession(configuration: configuration))
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

private extension JSONDecoder {
    static var deltaSnakeCase: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
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
