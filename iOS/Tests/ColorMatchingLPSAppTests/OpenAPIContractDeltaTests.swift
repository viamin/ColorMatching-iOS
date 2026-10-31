import Foundation
import MeasurementCore
import XCTest
@testable import ColorMatchingLPSAppCore

/// Red-phase coverage for viamin/ColorMatching-iOS#5 ("Replace hand-written API
/// layer with a generated OpenAPI Swift client").
///
/// These tests compare the hand-written `APIClient`/`MeasurementCore` models
/// against the *real* `color_matching` API, as implemented in the merged spec
/// PR (viamin/color_matching#113, commit
/// `094bd6d3443ddacbda7e63354299867eb5bdfa9f`: `lib/color_matching_web/api_schemas.ex`,
/// `lib/color_matching_web/controllers/capture_controller.ex`, and
/// `lib/color_matching_web/controllers/test_sheet_json.ex`), not just against
/// `docs/color-matching-api-contract.md`. See `docs/openapi-contract-deltas.md`
/// for the full writeup.
///
/// Some of these fail today on purpose: they demonstrate drift that the
/// generated-client replacement (tracked by #5) is meant to fix, and should be
/// revisited once that work lands.
final class OpenAPIContractDeltaTests: XCTestCase {
    override func tearDown() {
        DeltaMockURLProtocol.handler = nil
        super.tearDown()
    }

    // MARK: - Manifest

    /// The real manifest response (`TestSheetJSON.manifest/1`) always includes
    /// `printer_profile` and `capture_profile`, but `SheetManifest` has no
    /// properties for either, so decoding then re-encoding silently drops them.
    /// `capture_profile.scoring_algorithm_version` in particular is exactly what
    /// this app would need to detect server-side scoring drift against
    /// `LPSScorer.algorithmVersion` — the motivating problem for #5.
    func testManifestDecodeDropsPrinterProfileAndCaptureProfileFromRealAPIResponse() throws {
        let manifest = try JSONDecoder().decode(SheetManifest.self, from: Self.realManifestJSON)
        let reencoded = try JSONEncoder().encode(manifest)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: reencoded) as? [String: Any])

        XCTAssertNotNil(json["printer_profile"], "SheetManifest should retain printer_profile from the real API response")
        XCTAssertNotNil(json["capture_profile"], "SheetManifest should retain capture_profile (incl. scoring_algorithm_version) from the real API response")
    }

    // MARK: - Measurement upload

    /// The published `MeasurementUploadRequest` schema only declares
    /// `measurements` and `pair_scores` at the top level, and each measurement
    /// item only declares `patch_id`, `linear_rgb_median`, and
    /// `normalized_linear_rgb_median`. The hand-written client sends an extra
    /// top-level `scoring_algorithm_version` and an extra per-measurement
    /// `stats` object that have no counterpart in the published contract.
    func testUploadMeasurementsRequestBodyMatchesPublishedMeasurementUploadSchema() async throws {
        var capturedBody: Data?
        DeltaMockURLProtocol.handler = { request in
            capturedBody = request.httpBodyStream.flatMap(Self.readBody) ?? request.httpBody
            return (
                HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                Data(#"{"capture_id":"cap_1","measurement_count":1,"pair_score_count":1}"#.utf8)
            )
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
        XCTAssertEqual(
            Set(json.keys),
            ["measurements", "pair_scores"],
            "request body should only send fields the published MeasurementUploadRequest schema declares"
        )

        let measurement = try XCTUnwrap((json["measurements"] as? [[String: Any]])?.first)
        XCTAssertEqual(
            Set(measurement.keys),
            ["patch_id", "linear_rgb_median", "normalized_linear_rgb_median"],
            "measurement payload should only send fields the published schema declares (no client-only stats object)"
        )
    }

    // MARK: - Judgment upload

    /// Unlike measurement upload, the judgment upload request body already
    /// matches the published `JudgmentUploadRequest` schema exactly. This is
    /// a deliberately passing counter-example: not every endpoint has drifted.
    func testUploadJudgmentsRequestBodyMatchesPublishedJudgmentUploadSchema() async throws {
        var capturedBody: Data?
        DeltaMockURLProtocol.handler = { request in
            capturedBody = request.httpBodyStream.flatMap(Self.readBody) ?? request.httpBody
            return (
                HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                Data(#"{"capture_id":"cap_1","judgment_count":1}"#.utf8)
            )
        }

        try await client().uploadJudgments(
            captureID: "cap_1",
            baseURL: URL(string: "https://example.test")!,
            judgments: [PairJudgment(pairID: "pair_1", judgment: "near_match")]
        )

        let json = try XCTUnwrap(Self.jsonObject(from: capturedBody) as? [String: Any])
        XCTAssertEqual(Set(json.keys), ["judgments"], "request body should only send fields the published JudgmentUploadRequest schema declares")

        let judgment = try XCTUnwrap((json["judgments"] as? [[String: Any]])?.first)
        XCTAssertEqual(Set(judgment.keys), ["pair_id", "judgment"])
    }

    // MARK: - Ranked results (no client code exists for this endpoint today)

    /// `APIClient` has no method and `MeasurementCore` has no model for
    /// `GET /api/v1/test_sheets/:sheet_id/ranked_results` at all. This fixture
    /// pins down the real response shape (from `TestSheetJSON.ranked_results/1`,
    /// which is considerably richer than the published `RankedResults` OpenAPI
    /// schema) using a test-local type, so the implementation run has a
    /// verified target instead of re-deriving it from `color_matching` source.
    func testRankedResultsRealResponseShapeDecodesForFutureGeneratedClient() throws {
        let decoded = try JSONDecoder().decode(DeltaRankedResultsFixture.self, from: Self.realRankedResultsJSON)

        XCTAssertEqual(decoded.schemaVersion, "lps-ranked-results/v1")
        XCTAssertEqual(decoded.sheetID, "sheet_123")
        XCTAssertEqual(decoded.scoringAlgorithmVersions, ["lps-distance-v1"])
        XCTAssertEqual(decoded.results.count, 1)

        let result = try XCTUnwrap(decoded.results.first)
        XCTAssertEqual(result.rank, 1)
        XCTAssertEqual(result.pairID, "pair_1")
        XCTAssertEqual(result.sourceColors.colorAHex, "#FF0000")
        XCTAssertEqual(result.currentJudgment, "near_match")
        XCTAssertEqual(result.score.average, 0.035, accuracy: 0.0001)
    }

    // MARK: - Fixtures (real response shapes, see docs/openapi-contract-deltas.md)

    private static let realManifestJSON = Data(
        #"""
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
            "printer_make_model": "Canon PIXMA",
            "paper_type": "Matte",
            "ink_type": "Dye",
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
              "rect": {"x": 36, "y": 38, "width": 16, "height": 10}
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
        """#.utf8
    )

    private static let realRankedResultsJSON = Data(
        #"""
        {
          "schema_version": "lps-ranked-results/v1",
          "sheet_id": "sheet_123",
          "printer_profile": {
            "printer_make_model": "Canon PIXMA",
            "paper_type": "Matte",
            "ink_type": "Dye",
            "icc_profile": null,
            "print_settings": null,
            "driver_name": null,
            "driver_version": null,
            "calibration_date": null,
            "calibration_version": null,
            "notes": null
          },
          "capture_count": 1,
          "latest_capture_at": "2026-07-25T12:00:00Z",
          "earliest_capture_at": "2026-07-25T12:00:00Z",
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
                "average": 0.035,
                "latest": 0.035,
                "minimum": 0.035,
                "maximum": 0.035,
                "capture_count": 1,
                "sample_count": 1,
                "algorithm_versions": ["lps-distance-v1"]
              },
              "current_judgment": "near_match",
              "current_judgment_observed_at": "2026-07-25T12:00:00Z",
              "observation_count": 1,
              "latest_observation": {"judgment": "near_match", "observed_at": "2026-07-25T12:00:00Z"},
              "capture_count": 1,
              "latest_capture_at": "2026-07-25T12:00:00Z",
              "earliest_capture_at": "2026-07-25T12:00:00Z"
            }
          ]
        }
        """#.utf8
    )

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

/// Test-local decodable mirroring the real `TestSheetJSON.ranked_results/1`
/// shape. Deliberately not added to `MeasurementCore`/`ColorMatchingLPSAppCore`
/// in this run — it exists only to pin the target shape down for the
/// generated-client implementation work.
private struct DeltaRankedResultsFixture: Decodable {
    struct SourceColors: Decodable {
        var colorAHex: String
        var colorBHex: String

        enum CodingKeys: String, CodingKey {
            case colorAHex = "color_a_hex"
            case colorBHex = "color_b_hex"
        }
    }

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
        var row: Int
        var col: Int
        var sourceColors: SourceColors
        var score: Score
        var currentJudgment: String?
        var observationCount: Int

        enum CodingKeys: String, CodingKey {
            case rank, row, col, score
            case pairID = "pair_id"
            case scoringAlgorithmVersion = "scoring_algorithm_version"
            case sourceColors = "source_colors"
            case currentJudgment = "current_judgment"
            case observationCount = "observation_count"
        }
    }

    var schemaVersion: String
    var sheetID: String
    var scoringAlgorithmVersions: [String]
    var results: [Result]

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case sheetID = "sheet_id"
        case scoringAlgorithmVersions = "scoring_algorithm_versions"
        case results
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
