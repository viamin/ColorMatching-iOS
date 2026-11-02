import Foundation
import MeasurementCore
import XCTest
@testable import ColorMatchingLPSAppCore

/// Coverage against the real `/api/v1` response/request shapes published by
/// `viamin/color_matching#110` (https://github.com/viamin/color_matching/pull/113),
/// as opposed to the idealized examples in `docs/color-matching-api-contract.md`.
/// See `docs/color-matching-api-contract-deltas.md` for the full writeup.
///
/// This file mixes two kinds of tests, deliberately:
/// - Characterization tests that decode real-shaped fixtures through the
///   *current* hand-written `APIClient` and pass today, proving the
///   decode-tolerant parts of the contract already line up.
/// - Failing placeholder tests (`XCTFail`) for surfaces the issue #5 generated
///   client needs to add that the hand-written client has no symbols for at
///   all today. They decode the real fixture into a local, test-only type to
///   prove the fixture is faithful to the server, then fail on purpose so this
///   file goes green only once the generated client lands.
final class RealContractCoverageTests: XCTestCase {
    override func tearDown() {
        RealContractMockURLProtocol.handler = nil
        super.tearDown()
    }

    // MARK: - Characterization tests (pass today)

    func testFetchManifestDecodesRealServerShape() async throws {
        RealContractMockURLProtocol.handler = { request in
            (
                HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                Data(Self.realManifestJSON.utf8)
            )
        }

        let manifest = try await client().fetchManifest(baseURL: URL(string: "https://example.test")!, sheetCode: "ABCD-2345")

        XCTAssertEqual(manifest.sheetID, "ABCD-2345")
        XCTAssertEqual(manifest.sheetVersion, "lps-letter-grid-v1")
        XCTAssertEqual(manifest.page, Page(units: "mm", width: 215.9, height: 279.4))
        XCTAssertEqual(manifest.registrationMarkers.map(\.role), ["top_left", "top_right", "bottom_right", "bottom_left"])
        XCTAssertEqual(manifest.patches.count, 2)
        XCTAssertEqual(manifest.pairs.count, 1)
    }

    func testFetchRecentSheetsDecodesRealServerShape() async throws {
        RealContractMockURLProtocol.handler = { request in
            (
                HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                Data(#"""
                {"sheets": [{"sheet_id": "ABCD-2345", "manifest_url": "https://example.test/api/v1/test_sheets/ABCD-2345/manifest", "title": null}]}
                """#.utf8)
            )
        }

        let sheets = try await client().fetchRecentSheets(baseURL: URL(string: "https://example.test")!)

        XCTAssertEqual(sheets.count, 1)
        XCTAssertEqual(sheets[0].sheetID, "ABCD-2345")
        XCTAssertNil(sheets[0].title)
    }

    // MARK: - Failing placeholders for surfaces the generated client must add

    func testRankedResultsEndpointHasNoClientSupportYet() throws {
        // Real shape of GET /api/v1/test_sheets/:sheet_id/ranked_results,
        // grounded in viamin/color_matching's
        // test/color_matching_web/controllers/ranked_results_controller_test.exs
        // and lib/color_matching_web/controllers/test_sheet_json.ex.
        struct FixtureOnlyRankedResults: Decodable {
            struct Score: Decodable {
                var average: Double
                var latest: Double
                var minimum: Double
                var maximum: Double
                var captureCount: Int
                var sampleCount: Int
                var algorithmVersions: [String]

                enum CodingKeys: String, CodingKey {
                    case average, latest, minimum, maximum
                    case captureCount = "capture_count"
                    case sampleCount = "sample_count"
                    case algorithmVersions = "algorithm_versions"
                }
            }

            struct Result: Decodable {
                var rank: Int
                var pairID: String
                var scoringAlgorithmVersion: String
                var score: Score
                var currentJudgment: String?

                enum CodingKeys: String, CodingKey {
                    case rank
                    case pairID = "pair_id"
                    case scoringAlgorithmVersion = "scoring_algorithm_version"
                    case score
                    case currentJudgment = "current_judgment"
                }
            }

            var schemaVersion: String
            var sheetID: String
            var captureCount: Int
            var scoringAlgorithmVersions: [String]
            var results: [Result]

            enum CodingKeys: String, CodingKey {
                case schemaVersion = "schema_version"
                case sheetID = "sheet_id"
                case captureCount = "capture_count"
                case scoringAlgorithmVersions = "scoring_algorithm_versions"
                case results
            }
        }

        let decoded = try JSONDecoder().decode(FixtureOnlyRankedResults.self, from: Data(Self.realRankedResultsJSON.utf8))
        XCTAssertEqual(decoded.sheetID, "RNKD-2345")
        XCTAssertEqual(decoded.results.first?.pairID, "RNKD-2345-0-0")

        XCTFail(
            """
            GET /api/v1/test_sheets/:sheet_id/ranked_results is a real, server-tested \
            endpoint (ColorMatchingWeb.TestSheetController.ranked_results) with no \
            equivalent anywhere in ColorMatchingLPSAppCore or MeasurementCore: no \
            RankedResults model, no APIClient.fetchRankedResults method. The fixture \
            above decodes fine, proving the shape is understood; this fails to mark \
            that production code has no symbol to decode it into yet. See issue #5 \
            and docs/color-matching-api-contract-deltas.md.
            """
        )
    }

    func testMeasurementUploadResponseBodyIsDiscardedByClient() async throws {
        RealContractMockURLProtocol.handler = { request in
            (
                HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                Data(#"{"capture_id": "cap_1", "measurement_count": 1, "pair_score_count": 1}"#.utf8)
            )
        }

        let rgb = RGB(r: 0.2, g: 0.3, b: 0.4)
        let stats = ChannelStats(median: rgb, mean: rgb, standardDeviation: RGB(r: 0.01, g: 0.01, b: 0.01), min: rgb, max: rgb, sampleCount: 9, clippingFraction: 0)

        // APIClient.uploadMeasurements returns Void today, so there is no
        // measurementCount/pairScoreCount to assert on even though the real
        // server sends them back. Calling it still exercises the real
        // response body against the client's status-only validation.
        try await client().uploadMeasurements(
            captureID: "cap_1",
            baseURL: URL(string: "https://example.test")!,
            measurements: [PatchMeasurement(patchID: "patch_1", linearRGBMedian: rgb, normalizedLinearRGBMedian: rgb, stats: stats)],
            scores: [PairScore(pairID: "pair_1", distance: 0.1, similarity: 0.9, algorithmVersion: "lps-distance-v1")]
        )

        XCTFail(
            """
            POST /api/v1/captures/:capture_id/measurements returns \
            {capture_id, measurement_count, pair_score_count} (MeasurementUploadResponse), \
            but APIClient.uploadMeasurements returns Void and discards the body via the \
            private send(_:) helper. The generated client's typed Output should not be \
            thrown away. See issue #5 and docs/color-matching-api-contract-deltas.md.
            """
        )
    }

    func testJudgmentUploadResponseBodyIsDiscardedByClient() async throws {
        RealContractMockURLProtocol.handler = { request in
            (
                HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                Data(#"{"capture_id": "cap_1", "judgment_count": 1}"#.utf8)
            )
        }

        try await client().uploadJudgments(
            captureID: "cap_1",
            baseURL: URL(string: "https://example.test")!,
            judgments: [PairJudgment(pairID: "pair_1", judgment: "near_match")]
        )

        XCTFail(
            """
            POST /api/v1/captures/:capture_id/judgments returns \
            {capture_id, judgment_count} (JudgmentUploadResponse), but \
            APIClient.uploadJudgments returns Void and discards the body via the \
            private send(_:) helper. See issue #5 and \
            docs/color-matching-api-contract-deltas.md.
            """
        )
    }

    // MARK: - Fixtures

    private func client() -> APIClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [RealContractMockURLProtocol.self]
        return APIClient(token: "token", session: URLSession(configuration: configuration))
    }

    private static let realManifestJSON = """
    {
      "schema_version": "lps-sheet-manifest/v1",
      "sheet_version": "lps-letter-grid-v1",
      "sheet_id": "ABCD-2345",
      "manifest_url": "https://example.test/api/v1/test_sheets/ABCD-2345/manifest",
      "created_at": "2026-07-28T20:10:19Z",
      "page": {"units": "mm", "width": 215.9, "height": 279.4},
      "registration_markers": [
        {"role": "top_left", "shape": "solid_square", "rect": {"x": 12.7, "y": 12.7, "width": 10.0, "height": 10.0}},
        {"role": "top_right", "shape": "solid_square", "rect": {"x": 193.2, "y": 12.7, "width": 10.0, "height": 10.0}},
        {"role": "bottom_right", "shape": "solid_square", "rect": {"x": 193.2, "y": 256.7, "width": 10.0, "height": 10.0}},
        {"role": "bottom_left", "shape": "solid_square", "rect": {"x": 12.7, "y": 256.7, "width": 10.0, "height": 10.0}}
      ],
      "printer_profile": {
        "printer_make_model": "Epson SureColor P900",
        "paper_type": "Ultra Premium Luster",
        "ink_type": "OEM UltraChrome PRO10",
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
        {"id": "ABCD-2345-0-0#first", "role": "pair_color", "pair_id": "ABCD-2345-0-0", "pair_side": "first", "reference_role": null, "source_color": "#FF0000", "safe_inset_mm": 12.7, "rect": {"x": 20.0, "y": 40.0, "width": 10.0, "height": 10.0}},
        {"id": "ABCD-2345-0-0#second", "role": "pair_color", "pair_id": "ABCD-2345-0-0", "pair_side": "second", "reference_role": null, "source_color": "#00FFFF", "safe_inset_mm": 12.7, "rect": {"x": 35.0, "y": 40.0, "width": 10.0, "height": 10.0}}
      ],
      "pairs": [
        {"id": "ABCD-2345-0-0", "first_patch_id": "ABCD-2345-0-0#first", "second_patch_id": "ABCD-2345-0-0#second", "source_colors": ["#FF0000", "#00FFFF"], "grid_row": 0, "grid_col": 0}
      ]
    }
    """

    private static let realRankedResultsJSON = """
    {
      "schema_version": "lps-ranked-results/v1",
      "sheet_id": "RNKD-2345",
      "printer_profile": {
        "printer_make_model": "Epson SureColor P900",
        "paper_type": "Ultra Premium Luster",
        "ink_type": "OEM UltraChrome PRO10",
        "icc_profile": null,
        "print_settings": null,
        "driver_name": null,
        "driver_version": null,
        "calibration_date": null,
        "calibration_version": null,
        "notes": null
      },
      "capture_count": 1,
      "latest_capture_at": "2026-07-28T12:34:56.123456Z",
      "earliest_capture_at": "2026-07-28T12:34:56.123456Z",
      "scoring_algorithm_versions": ["ios-score/v1"],
      "results": [
        {
          "rank": 1,
          "pair_id": "RNKD-2345-0-0",
          "scoring_algorithm_version": "ios-score/v1",
          "row": 0,
          "col": 0,
          "source_colors": {"color_a_hex": "#FF0000", "color_b_hex": "#00FFFF"},
          "score": {
            "average": 0.91,
            "latest": 0.91,
            "minimum": 0.91,
            "maximum": 0.91,
            "capture_count": 1,
            "sample_count": 1,
            "algorithm_versions": ["ios-score/v1"]
          },
          "current_judgment": null,
          "current_judgment_observed_at": null,
          "observation_count": 0,
          "latest_observation": null,
          "capture_count": 1,
          "latest_capture_at": "2026-07-28T12:34:56.123456Z",
          "earliest_capture_at": "2026-07-28T12:34:56.123456Z"
        }
      ]
    }
    """
}

private final class RealContractMockURLProtocol: URLProtocol {
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
