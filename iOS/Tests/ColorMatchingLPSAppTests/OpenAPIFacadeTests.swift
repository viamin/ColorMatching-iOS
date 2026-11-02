import ColorMatchingOpenAPI
import Foundation
import MeasurementCore
import XCTest
@testable import ColorMatchingLPSAppCore

/// Drives the app-facing `APIClient` facade — reimplemented on top of the
/// generated `ColorMatchingOpenAPI` client — end-to-end through URLSession
/// with a stubbed URLProtocol. No live server is required.
///
/// These tests pin the wire-behavior deltas found between the prose
/// contract and the published OpenAPI spec (docs/color-matching-openapi-deltas.md):
/// uploads return `200` JSON bodies with counts (D1/D2), measurement
/// uploads carry no stats block and no top-level scoring_algorithm_version
/// (D3/D4), capture creation returns `201` with a string capture id (D6),
/// and ranked results surface the aggregate payload (G2).
final class OpenAPIFacadeTests: XCTestCase {
    override func tearDown() {
        StubURLProtocol.handler = nil
        super.tearDown()
    }

    private func client(token: String = "token") -> APIClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return APIClient(token: token, session: URLSession(configuration: configuration))
    }

    private static func response(_ request: URLRequest, status: Int, json: String) -> (HTTPURLResponse, Data) {
        (
            HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!,
            Data(json.utf8)
        )
    }

    func testFetchManifestSendsBearerTokenAndDecodesGeneratedManifest() async throws {
        var capturedRequest: URLRequest?
        StubURLProtocol.handler = { request in
            capturedRequest = request
            return Self.response(request, status: 200, json: OpenAPIFixtures.manifestJSON)
        }

        let manifest = try await client().fetchManifest(
            baseURL: URL(string: "https://example.test")!,
            sheetCode: "sheet_1"
        )

        XCTAssertEqual(capturedRequest?.url?.path, "/api/v1/test_sheets/sheet_1/manifest")
        XCTAssertEqual(capturedRequest?.value(forHTTPHeaderField: "Authorization"), "Bearer token")
        XCTAssertEqual(manifest.schemaVersion, "lps-sheet-manifest/v1")
        XCTAssertEqual(manifest.sheetId, "sheet_1")
        XCTAssertEqual(manifest.captureProfile?.scoringAlgorithmVersion, "lps-distance-v1")
        XCTAssertEqual(manifest.patches?.first?.id, "pair_1#first")
        XCTAssertEqual(manifest.patches?.first?.safeInsetMm, 1.5)
        XCTAssertEqual(manifest.pairs?.first?.sourceColors, ["#FF0000", "#00FF00"])
    }

    func testFetchRecentSheetsDecodesGeneratedSummaries() async throws {
        StubURLProtocol.handler = { request in
            Self.response(
                request,
                status: 200,
                json: #"""
                {"sheets": [
                  {"sheet_id": "sheet_1", "manifest_url": "https://example.test/api/v1/test_sheets/sheet_1/manifest", "title": null},
                  {"sheet_id": "sheet_2", "manifest_url": "https://example.test/api/v1/test_sheets/sheet_2/manifest", "title": "July LPS comparison sheet"}
                ]}
                """#
            )
        }

        let sheets = try await client().fetchRecentSheets(baseURL: URL(string: "https://example.test")!)

        XCTAssertEqual(sheets.count, 2)
        XCTAssertEqual(sheets.first?.sheetId, "sheet_1")
        XCTAssertEqual(sheets.first?.title, nil)
        XCTAssertEqual(sheets.last?.title, "July LPS comparison sheet")
        XCTAssertEqual(sheets.last?.manifestUrl, "https://example.test/api/v1/test_sheets/sheet_2/manifest")
    }

    func testCreateCaptureReturnsGeneratedCaptureId() async throws {
        var capturedRequest: URLRequest?
        var capturedBody: Data?
        StubURLProtocol.handler = { request in
            capturedRequest = request
            capturedBody = request.httpBodyStream.flatMap(Self.readBody) ?? request.httpBody
            return Self.response(request, status: 201, json: #"{"capture_id": "9"}"#)
        }

        let capture = try await client().createCapture(
            sheetID: "sheet_1",
            baseURL: URL(string: "https://example.test")!,
            metadata: .init(
                deviceModel: "iPhone 16",
                lens: "built_in_wide_angle",
                exposureDurationSeconds: 0.016,
                iso: 100,
                focusLensPosition: 0.42,
                whiteBalanceGains: .init(red: 1.1, green: 1.0, blue: 1.2),
                imageWidth: 4032,
                imageHeight: 3024,
                appVersion: "0.1.0",
                timestamp: "2026-07-25T12:00:00Z"
            ),
            quality: CaptureQuality(detectedMarkerCount: 4, blurScore: 0.75, rejections: [])
        )

        XCTAssertEqual(capturedRequest?.url?.path, "/api/v1/test_sheets/sheet_1/captures")
        XCTAssertEqual(capturedRequest?.value(forHTTPHeaderField: "Authorization"), "Bearer token")
        XCTAssertEqual(capture.captureId, "9")
        let json = try XCTUnwrap(Self.jsonObject(from: capturedBody) as? [String: Any])
        let metadata = try XCTUnwrap(json["metadata"] as? [String: Any])
        XCTAssertEqual(metadata["device_model"] as? String, "iPhone 16")
        XCTAssertEqual(metadata["iso"] as? Int, 100)
        let quality = try XCTUnwrap(json["quality"] as? [String: Any])
        XCTAssertEqual(quality["detected_marker_count"] as? Int, 4)
        XCTAssertEqual(quality["rejections"] as? [String], [])
    }

    func testUploadMeasurementsMatchesPublishedSpecAndReturnsCounts() async throws {
        var capturedRequest: URLRequest?
        var capturedBody: Data?
        StubURLProtocol.handler = { request in
            capturedRequest = request
            capturedBody = request.httpBodyStream.flatMap(Self.readBody) ?? request.httpBody
            return Self.response(request, status: 200, json: #"{"capture_id": "9", "measurement_count": 2, "pair_score_count": 1}"#)
        }

        let rgb = RGB(r: 0.2, g: 0.3, b: 0.4)
        let stats = ChannelStats(
            median: rgb,
            mean: rgb,
            standardDeviation: RGB(r: 0.01, g: 0.01, b: 0.01),
            min: rgb,
            max: rgb,
            sampleCount: 9,
            clippingFraction: 0
        )
        let accepted = try await client().uploadMeasurements(
            captureID: "9",
            baseURL: URL(string: "https://example.test")!,
            measurements: [
                PatchMeasurement(patchID: "pair_1#first", linearRGBMedian: rgb, normalizedLinearRGBMedian: rgb, stats: stats),
                PatchMeasurement(patchID: "pair_1#second", linearRGBMedian: rgb, normalizedLinearRGBMedian: rgb, stats: stats)
            ],
            scores: [
                PairScore(pairID: "pair_1", distance: 0.035, similarity: 0.965, algorithmVersion: "lps-distance-v1")
            ]
        )

        XCTAssertEqual(capturedRequest?.url?.path, "/api/v1/captures/9/measurements")
        // Delta D1/D3: the published API answers 200 with counts and its
        // upload schema has no stats block or top-level algorithm version.
        XCTAssertEqual(accepted.captureId, "9")
        XCTAssertEqual(accepted.measurementCount, 2)
        XCTAssertEqual(accepted.pairScoreCount, 1)
        let json = try XCTUnwrap(Self.jsonObject(from: capturedBody) as? [String: Any])
        XCTAssertEqual(Set(json.keys), ["measurements", "pair_scores"])
        let measurement = try XCTUnwrap((json["measurements"] as? [[String: Any]])?.first)
        XCTAssertEqual(
            Set(measurement.keys),
            ["patch_id", "linear_rgb_median", "normalized_linear_rgb_median"]
        )
        let score = try XCTUnwrap((json["pair_scores"] as? [[String: Any]])?.first)
        XCTAssertEqual(score["algorithm_version"] as? String, "lps-distance-v1")
        XCTAssertEqual(score["similarity"] as? Double, 0.965)
        XCTAssertEqual(score["distance"] as? Double, 0.035)
    }

    func testUploadJudgmentsReturnsGeneratedJudgmentCount() async throws {
        var capturedBody: Data?
        StubURLProtocol.handler = { request in
            capturedBody = request.httpBodyStream.flatMap(Self.readBody) ?? request.httpBody
            return Self.response(request, status: 200, json: #"{"capture_id": "9", "judgment_count": 2}"#)
        }

        let response = try await client().uploadJudgments(
            captureID: "9",
            baseURL: URL(string: "https://example.test")!,
            judgments: [
                .init(pairId: "pair_1", judgment: "near_match"),
                .init(pairId: "pair_2", judgment: "no_match")
            ]
        )

        // Delta D2: judgments answer 200 with a count, not an empty 204.
        XCTAssertEqual(response.captureId, "9")
        XCTAssertEqual(response.judgmentCount, 2)
        let json = try XCTUnwrap(Self.jsonObject(from: capturedBody) as? [String: Any])
        let judgments = try XCTUnwrap(json["judgments"] as? [[String: Any]])
        XCTAssertEqual(judgments.first?["judgment"] as? String, "near_match")
        XCTAssertEqual(judgments.last?["judgment"] as? String, "no_match")
    }

    func testFetchRankedResultsDecodesGeneratedAggregates() async throws {
        var capturedRequest: URLRequest?
        StubURLProtocol.handler = { request in
            capturedRequest = request
            return Self.response(request, status: 200, json: OpenAPIFixtures.rankedResultsJSON)
        }

        let results = try await client().fetchRankedResults(
            sheetID: "sheet_1",
            baseURL: URL(string: "https://example.test")!
        )

        XCTAssertEqual(capturedRequest?.url?.path, "/api/v1/test_sheets/sheet_1/ranked_results")
        XCTAssertEqual(results.schemaVersion, "lps-ranked-results/v1")
        XCTAssertEqual(results.sheetId, "sheet_1")
        XCTAssertEqual(results.printerProfile?.inkType, "ink set")
        let pair = try XCTUnwrap(results.results.first)
        XCTAssertEqual(pair.rank, 1)
        XCTAssertEqual(pair.pairId, "pair_1")
        XCTAssertEqual(pair.sourceColors.colorAHex, "#FF0000")
        XCTAssertEqual(pair.score.average, 0.04)
        XCTAssertEqual(pair.currentJudgment, "near_match")
    }
}

private enum OpenAPIFixtures {
    static let manifestJSON = #"""
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
      "printer_profile": {"printer_make_model": "Research printer", "paper_type": "paper name", "ink_type": "ink set"},
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
    """#

    static let rankedResultsJSON = #"""
    {
      "schema_version": "lps-ranked-results/v1",
      "sheet_id": "sheet_1",
      "printer_profile": {"printer_make_model": "Research printer", "paper_type": "paper name", "ink_type": "ink set"},
      "capture_count": 2,
      "latest_capture_at": "2026-07-26T09:00:00Z",
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
            "average": 0.04,
            "latest": 0.035,
            "minimum": 0.03,
            "maximum": 0.05,
            "capture_count": 2,
            "sample_count": 2,
            "algorithm_versions": ["lps-distance-v1"]
          },
          "current_judgment": "near_match",
          "current_judgment_observed_at": "2026-07-26T10:00:00Z",
          "observation_count": 1,
          "latest_observation": {"judgment": "near_match", "observed_at": "2026-07-26T10:00:00Z"},
          "capture_count": 2,
          "latest_capture_at": "2026-07-26T09:00:00Z",
          "earliest_capture_at": "2026-07-25T12:00:00Z"
        }
      ]
    }
    """#
}

private extension OpenAPIFacadeTests {
    static func jsonObject(from data: Data?) throws -> Any {
        try JSONSerialization.jsonObject(with: XCTUnwrap(data))
    }

    static func readBody(_ stream: InputStream) -> Data {
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 1024)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            if count > 0 {
                data.append(buffer, count)
            } else {
                break
            }
        }
        return data
    }
}

private final class StubURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        do {
            guard let handler = Self.handler else {
                throw URLError(.unsupportedURL)
            }
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
