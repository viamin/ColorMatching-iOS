import Foundation
import MeasurementCore
import XCTest
@testable import ColorMatchingLPSAppCore

/// Pins the hand-written client against the real spec from viamin/color_matching#110; see docs/openapi-contract-deltas.md.
final class APIContractDeltaTests: XCTestCase {
    override func tearDown() {
        ContractStubURLProtocol.handler = nil
        super.tearDown()
    }

    // MARK: - Measurement upload request shape

    /// RED: published MeasurementUploadRequest has no scoring_algorithm_version or per-measurement stats field.
    func testUploadMeasurementsRequestBodyMatchesPublishedSchemaFields() async throws {
        var capturedBody: Data?
        ContractStubURLProtocol.handler = { request in
            capturedBody = request.httpBodyStream.flatMap(Self.readBody) ?? request.httpBody
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data(#"{"capture_id":"42","measurement_count":1,"pair_score_count":1}"#.utf8))
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
        XCTAssertEqual(Set(json.keys), ["measurements", "pair_scores"], "published MeasurementUploadRequest has no top-level scoring_algorithm_version field")

        let measurement = try XCTUnwrap((json["measurements"] as? [[String: Any]])?.first)
        XCTAssertEqual(Set(measurement.keys), ["patch_id", "linear_rgb_median", "normalized_linear_rgb_median"], "published MeasurementUploadRequest measurement entries have no stats object")
    }

    // MARK: - Real confirmation responses (status 200 + JSON body, not 204)

    /// PIN: upload_measurements answers 200 + JSON body, never 204.
    func testUploadMeasurementsAcceptsRealServerConfirmationResponse() async throws {
        ContractStubURLProtocol.handler = { request in
            (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data(#"{"capture_id":"42","measurement_count":1,"pair_score_count":1}"#.utf8))
        }

        let rgb = RGB(r: 0.2, g: 0.3, b: 0.4)
        let stats = ChannelStats(median: rgb, mean: rgb, standardDeviation: RGB(r: 0.01, g: 0.01, b: 0.01), min: rgb, max: rgb, sampleCount: 9, clippingFraction: 0)
        try await client().uploadMeasurements(
            captureID: "cap_1",
            baseURL: URL(string: "https://example.test")!,
            measurements: [PatchMeasurement(patchID: "patch_1", linearRGBMedian: rgb, normalizedLinearRGBMedian: rgb, stats: stats)],
            scores: []
        )
    }

    /// PIN: upload_judgments answers 200 + JSON body, never 204.
    func testUploadJudgmentsAcceptsRealServerConfirmationResponse() async throws {
        ContractStubURLProtocol.handler = { request in
            (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data(#"{"capture_id":"42","judgment_count":1}"#.utf8))
        }

        try await client().uploadJudgments(
            captureID: "cap_1",
            baseURL: URL(string: "https://example.test")!,
            judgments: [PairJudgment(pairID: "pair_1", judgment: "near_match")]
        )
    }

    // MARK: - Manifest / recent-sheets decoding (previously untested surfaces)

    func testFetchManifestDecodesPublishedResponseShape() async throws {
        ContractStubURLProtocol.handler = { request in
            (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data(Self.fullManifestJSON.utf8))
        }

        let manifest = try await client().fetchManifest(baseURL: URL(string: "https://example.test")!, sheetCode: "sheet_123")

        XCTAssertEqual(manifest.schemaVersion, "lps-sheet-manifest/v1")
        XCTAssertEqual(manifest.sheetID, "sheet_123")
        XCTAssertEqual(manifest.patches.first?.id, "patch_1")
        XCTAssertEqual(manifest.pairs.first?.id, "pair_1")
    }

    func testFetchRecentSheetsDecodesNullableTitle() async throws {
        ContractStubURLProtocol.handler = { request in
            (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data(#"{"sheets":[{"sheet_id":"sheet_123","manifest_url":"https://example.test/api/v1/test_sheets/sheet_123/manifest","title":null}]}"#.utf8))
        }

        let sheets = try await client().fetchRecentSheets(baseURL: URL(string: "https://example.test")!)

        XCTAssertEqual(sheets.first?.sheetID, "sheet_123")
        XCTAssertNil(sheets.first?.title)
    }

    /// PIN: published Manifest schema only requires schema_version/sheet_id/scoring_algorithm_version, not the geometry fields SheetManifest needs.
    func testManifestPublishedSchemaOnlyGuaranteesScoringAlgorithmVersion() throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let minimalSpecJSON = Data(#"{"schema_version":"lps-sheet-manifest/v1","sheet_id":"sheet_123","capture_profile":{"scoring_algorithm_version":"lps-distance-v1"}}"#.utf8)

        XCTAssertThrowsError(try decoder.decode(SheetManifest.self, from: minimalSpecJSON))
    }

    // MARK: - Helpers

    private func client() -> APIClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ContractStubURLProtocol.self]
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

    private static let fullManifestJSON = #"""
    {
      "schema_version": "lps-sheet-manifest/v1",
      "sheet_version": "lps-letter-grid-v1",
      "sheet_id": "sheet_123",
      "manifest_url": "https://example.test/api/v1/test_sheets/sheet_123/manifest",
      "page": {"units": "mm", "width": 215.9, "height": 279.4},
      "registration_markers": [
        {"role": "top_left", "shape": "solid_square", "rect": {"x": 12, "y": 12, "width": 8, "height": 8}}
      ],
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
      ],
      "capture_profile": {"scoring_algorithm_version": "lps-distance-v1"}
    }
    """#
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
