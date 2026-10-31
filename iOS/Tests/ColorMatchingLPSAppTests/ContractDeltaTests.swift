import Foundation
import MeasurementCore
import XCTest
@testable import ColorMatchingLPSAppCore

/// Red-phase coverage for issue #5 ("Replace hand-written API layer with a generated
/// OpenAPI Swift client"). These tests pin down concrete deltas between
/// `docs/color-matching-api-contract.md` and the real `viamin/color_matching` API
/// (inspected via its router, `TestSheetJSON`, `CaptureController`, and `api_schemas.ex`
/// after issue viamin/color_matching#110 / PR #113 shipped the OpenAPI spec).
///
/// These are expected to fail (or skip) until the generated client lands; they document
/// the gaps the generated client must close, and should be deleted or rewritten against
/// the generated types during implementation rather than kept as permanent duplicates of
/// `APIClientTests`.
final class ContractDeltaTests: XCTestCase {
    override func tearDown() {
        ContractDeltaMockURLProtocol.handler = nil
        super.tearDown()
    }

    // MARK: - Manifest: fields the real API sends that `SheetManifest` drops

    func testManifestRoundTripPreservesPrinterProfile() throws {
        let manifest = try Self.decodeManifestFixture()
        let reencoded = try Self.jsonObject(from: JSONEncoder.snakeCase.encode(manifest))

        XCTAssertNotNil(
            reencoded["printer_profile"],
            "real TestSheetController#manifest includes printer_profile (printer_make_model, paper_type, ink_type, ...); SheetManifest has no property for it, so a decode/encode round trip silently drops it"
        )
    }

    func testManifestRoundTripPreservesCaptureProfile() throws {
        let manifest = try Self.decodeManifestFixture()
        let reencoded = try Self.jsonObject(from: JSONEncoder.snakeCase.encode(manifest))

        XCTAssertNotNil(
            reencoded["capture_profile"],
            "real TestSheetController#manifest includes capture_profile (expected_illuminant, preferred_camera, scoring_algorithm_version); SheetManifest has no property for it"
        )
    }

    // MARK: - Measurement upload: shape drift against api_schemas.ex MeasurementUploadRequest

    func testUploadMeasurementsOmitsUndocumentedTopLevelScoringAlgorithmVersion() async throws {
        let json = try await Self.capturedMeasurementUploadBody(normalizedMedian: RGB(r: 0.15, g: 0.12, b: 0.02))

        XCTAssertNil(
            json["scoring_algorithm_version"],
            "api_schemas.ex MeasurementUploadRequest has no top-level scoring_algorithm_version field (only measurements/pair_scores); the hand-written client sends one anyway, which strict request validation may reject"
        )
    }

    func testUploadMeasurementsIncludesRequiredNormalizedMedianWhenNotComputed() async throws {
        let json = try await Self.capturedMeasurementUploadBody(normalizedMedian: nil)
        let measurement = try XCTUnwrap((json["measurements"] as? [[String: Any]])?.first)

        XCTAssertNotNil(
            measurement["normalized_linear_rgb_median"],
            "api_schemas.ex MeasurementUploadRequest marks normalized_linear_rgb_median as required per measurement; Swift's synthesized Encodable omits the key entirely when the optional is nil, so an un-normalized measurement would fail real-server validation"
        )
    }

    // MARK: - Endpoint gaps: documented in the real router but not callable from APIClient

    func testFetchRankedResultsIsNotYetImplemented() throws {
        throw XCTSkip(
            "GET /api/v1/test_sheets/:sheet_id/ranked_results exists server-side (TestSheetController#ranked_results, schema lps-ranked-results/v1) but APIClient has no fetchRankedResults method. Tracked by #5."
        )
    }

    func testUploadResponsesDiscardServerReportedCounts() throws {
        throw XCTSkip(
            "CaptureController#upload_measurements returns {capture_id, measurement_count, pair_score_count} and #upload_judgments returns {capture_id, judgment_count}; APIClient.uploadMeasurements/uploadJudgments ignore the response body entirely. Tracked by #5."
        )
    }

    // MARK: - Fixtures & helpers

    private static func decodeManifestFixture() throws -> SheetManifest {
        let fixture = """
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
            "id": 1,
            "printer_make_model": "Epson SureColor P900",
            "paper_type": "Premium Luster",
            "ink_type": "UltraChrome Pro12",
            "icc_profile": "SC-P900_PremiumLuster.icc",
            "print_settings": {},
            "driver_name": "Epson Print Layout",
            "driver_version": "3.1",
            "calibration_date": "2026-05-01",
            "calibration_version": "v2",
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
        return try JSONDecoder.snakeCase.decode(SheetManifest.self, from: Data(fixture.utf8))
    }

    private static func capturedMeasurementUploadBody(normalizedMedian: RGB?) async throws -> [String: Any] {
        var capturedBody: Data?
        ContractDeltaMockURLProtocol.handler = { request in
            capturedBody = request.httpBodyStream.flatMap(readBody) ?? request.httpBody
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data(#"{"capture_id":"cap_1","measurement_count":1,"pair_score_count":1}"#.utf8))
        }

        let rgb = RGB(r: 0.2, g: 0.3, b: 0.4)
        let stats = ChannelStats(median: rgb, mean: rgb, standardDeviation: RGB(r: 0.01, g: 0.01, b: 0.01), min: rgb, max: rgb, sampleCount: 9, clippingFraction: 0)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ContractDeltaMockURLProtocol.self]
        let client = APIClient(token: "token", session: URLSession(configuration: configuration))

        try await client.uploadMeasurements(
            captureID: "cap_1",
            baseURL: URL(string: "https://example.test")!,
            measurements: [PatchMeasurement(patchID: "patch_1", linearRGBMedian: rgb, normalizedLinearRGBMedian: normalizedMedian, stats: stats)],
            scores: [PairScore(pairID: "pair_1", distance: 0.1, similarity: 0.9, algorithmVersion: LPSScorer.algorithmVersion)]
        )

        return try jsonObject(from: capturedBody)
    }

    private static func jsonObject(from data: Data?) throws -> [String: Any] {
        let object = try JSONSerialization.jsonObject(with: XCTUnwrap(data))
        return try XCTUnwrap(object as? [String: Any])
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

private final class ContractDeltaMockURLProtocol: URLProtocol {
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

private extension JSONDecoder {
    static var snakeCase: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

private extension JSONEncoder {
    static var snakeCase: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}
