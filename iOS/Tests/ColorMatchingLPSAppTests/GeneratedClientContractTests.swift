import Foundation
import MeasurementCore
import XCTest
@testable import ColorMatchingLPSAppCore

/// Pins real response shapes discovered in `viamin/color_matching` (PR #113,
/// merge commit 094bd6d) that the current hand-written `APIClient` either
/// has no method for, or silently discards. See
/// docs/color-matching-api-contract-deltas.md for sourcing. These
/// intentionally reference client methods/types that don't exist yet; this
/// file is expected to fail to build until the generated-client
/// implementation lands.
final class GeneratedClientContractTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.handler = nil
        super.tearDown()
    }

    func testFetchRankedResultsDecodesRealResponseShape() async throws {
        let json = """
        {
          "schema_version": "lps-ranked-results/v1",
          "sheet_id": "sheet_123",
          "printer_profile": {
            "printer_make_model": "Research printer",
            "paper_type": "matte",
            "ink_type": "pigment",
            "icc_profile": null,
            "print_settings": null,
            "driver_name": null,
            "driver_version": null,
            "calibration_date": null,
            "calibration_version": null,
            "notes": null
          },
          "capture_count": 2,
          "latest_capture_at": "2026-07-25T12:00:00Z",
          "earliest_capture_at": "2026-07-20T09:00:00Z",
          "scoring_algorithm_versions": ["lps-distance-v1"],
          "results": [
            {
              "rank": 1,
              "pair_id": "pair_1",
              "scoring_algorithm_version": "lps-distance-v1",
              "row": 0,
              "col": 1,
              "source_colors": {"color_a_hex": "#FF0000", "color_b_hex": "#00FF00"},
              "score": {
                "average": 0.965,
                "latest": 0.97,
                "minimum": 0.95,
                "maximum": 0.97,
                "capture_count": 2,
                "sample_count": 2,
                "algorithm_versions": ["lps-distance-v1"]
              },
              "current_judgment": "near_match",
              "current_judgment_observed_at": "2026-07-25T12:05:00Z",
              "observation_count": 1,
              "latest_observation": {"judgment": "near_match", "observed_at": "2026-07-25T12:05:00Z"},
              "capture_count": 2,
              "latest_capture_at": "2026-07-25T12:00:00Z",
              "earliest_capture_at": "2026-07-20T09:00:00Z"
            }
          ]
        }
        """
        MockURLProtocol.handler = { request in
            (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data(json.utf8))
        }

        let results: RankedResults = try await client().fetchRankedResults(
            sheetID: "sheet_123",
            baseURL: URL(string: "https://example.test")!
        )

        XCTAssertEqual(results.schemaVersion, "lps-ranked-results/v1")
        XCTAssertEqual(results.sheetID, "sheet_123")
        XCTAssertEqual(results.captureCount, 2)
        XCTAssertEqual(results.scoringAlgorithmVersions, ["lps-distance-v1"])
        let pair = try XCTUnwrap(results.results.first)
        XCTAssertEqual(pair.pairID, "pair_1")
        XCTAssertEqual(pair.rank, 1)
        XCTAssertEqual(pair.sourceColors.colorAHex, "#FF0000")
        XCTAssertEqual(pair.score.average, 0.965)
        XCTAssertEqual(pair.currentJudgment, "near_match")
    }

    func testUploadMeasurementsDecodesCaptureIdAndCounts() async throws {
        MockURLProtocol.handler = { request in
            (
                HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                Data(#"{"capture_id":"cap_1","measurement_count":1,"pair_score_count":1}"#.utf8)
            )
        }

        let rgb = RGB(r: 0.2, g: 0.3, b: 0.4)
        let stats = ChannelStats(median: rgb, mean: rgb, standardDeviation: RGB(r: 0.01, g: 0.01, b: 0.01), min: rgb, max: rgb, sampleCount: 9, clippingFraction: 0)
        let response: MeasurementUploadResponse = try await client().uploadMeasurements(
            captureID: "cap_1",
            baseURL: URL(string: "https://example.test")!,
            measurements: [PatchMeasurement(patchID: "patch_1", linearRGBMedian: rgb, normalizedLinearRGBMedian: rgb, stats: stats)],
            scores: [PairScore(pairID: "pair_1", distance: 0.1, similarity: 0.9, algorithmVersion: LPSScorer.algorithmVersion)]
        )

        XCTAssertEqual(response.captureID, "cap_1")
        XCTAssertEqual(response.measurementCount, 1)
        XCTAssertEqual(response.pairScoreCount, 1)
    }

    func testUploadJudgmentsDecodesCaptureIdAndCount() async throws {
        MockURLProtocol.handler = { request in
            (
                HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                Data(#"{"capture_id":"cap_1","judgment_count":1}"#.utf8)
            )
        }

        let response: JudgmentUploadResponse = try await client().uploadJudgments(
            captureID: "cap_1",
            baseURL: URL(string: "https://example.test")!,
            judgments: [PairJudgment(pairID: "pair_1", judgment: "near_match")]
        )

        XCTAssertEqual(response.captureID, "cap_1")
        XCTAssertEqual(response.judgmentCount, 1)
    }

    func testFetchManifestDecodesPrinterProfileAndCaptureProfileFromRealServerShape() async throws {
        let json = """
        {
          "schema_version": "lps-sheet-manifest/v1",
          "sheet_version": "lps-letter-grid-v1",
          "sheet_id": "sheet_123",
          "manifest_url": "https://example.test/api/v1/test_sheets/sheet_123/manifest",
          "created_at": "2026-07-25T12:00:00Z",
          "page": {"units": "mm", "width": 215.9, "height": 279.4},
          "registration_markers": [],
          "printer_profile": {
            "printer_make_model": "Research printer",
            "paper_type": "matte",
            "ink_type": "pigment",
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
          "patches": [],
          "pairs": []
        }
        """
        MockURLProtocol.handler = { request in
            (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data(json.utf8))
        }

        let manifest = try await client().fetchManifest(from: URL(string: "https://example.test/api/v1/test_sheets/sheet_123/manifest")!)

        XCTAssertEqual(manifest.printerProfile.printerMakeModel, "Research printer")
        XCTAssertEqual(manifest.captureProfile.scoringAlgorithmVersion, "lps-distance-v1")
    }

    private func client() -> APIClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        return APIClient(token: "token", session: URLSession(configuration: configuration))
    }
}

private final class MockURLProtocol: URLProtocol {
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
