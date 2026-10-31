import ColorMatchingOpenAPI
import Foundation
import MeasurementCore
import XCTest
@testable import ColorMatchingLPSAppCore

final class APIClientTests: XCTestCase {
    private let baseURL = URL(string: "https://example.test")!

    override func tearDown() {
        StubURLProtocol.handler = nil
        super.tearDown()
    }

    private func client() -> APIClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return APIClient(token: "token", session: URLSession(configuration: configuration))
    }

    private func stub(status: Int, json: String) {
        StubURLProtocol.handler = { request in
            StubbedHTTP.response(url: request.url!, status: status, json: json)
        }
    }

    func testFetchManifestSendsAuthorizedRequestAndReturnsGeneratedManifest() async throws {
        var capturedRequest: URLRequest?
        StubURLProtocol.handler = { request in
            capturedRequest = request
            return StubbedHTTP.response(url: request.url!, status: 200, json: SpecFixtures.manifestJSON)
        }

        let manifest = try await client().fetchManifest(baseURL: baseURL, sheetCode: "sheet_123")

        XCTAssertEqual(capturedRequest?.httpMethod, "GET")
        XCTAssertEqual(capturedRequest?.url?.path, "/api/v1/test_sheets/sheet_123/manifest")
        XCTAssertEqual(capturedRequest?.value(forHTTPHeaderField: "Authorization"), "Bearer token")
        assertFullManifestDecoded(manifest)
    }

    func testFetchRecentSheetsReturnsGeneratedSheets() async throws {
        stub(status: 200, json: SpecFixtures.recentSheetsJSON)

        let sheets = try await client().fetchRecentSheets(baseURL: baseURL)

        XCTAssertEqual(sheets.count, 1)
        XCTAssertEqual(sheets.first?.sheetId, "sheet_123")
        XCTAssertEqual(sheets.first?.manifestUrl, "https://example.test/api/v1/test_sheets/sheet_123/manifest")
        XCTAssertNil(sheets.first?.title)
    }

    func testFetchRankedResultsReturnsGeneratedResults() async throws {
        var capturedRequest: URLRequest?
        StubURLProtocol.handler = { request in
            capturedRequest = request
            return StubbedHTTP.response(url: request.url!, status: 200, json: SpecFixtures.rankedResultsJSON)
        }

        let results = try await client().fetchRankedResults(baseURL: baseURL, sheetID: "sheet_123")

        XCTAssertEqual(capturedRequest?.url?.path, "/api/v1/test_sheets/sheet_123/ranked_results")
        XCTAssertEqual(results.schemaVersion.rawValue, "lps-ranked-results/v1")
        XCTAssertEqual(results.sheetId, "sheet_123")
        XCTAssertEqual(results.captureCount, 2)
        XCTAssertEqual(results.scoringAlgorithmVersions, ["lps-distance-v1"])
        XCTAssertEqual(results.results.first?.rank, 1)
        XCTAssertEqual(results.results.first?.pairId, "pair_1")
        XCTAssertEqual(results.results.first?.score.average, 0.965, accuracy: 0.0001)
        XCTAssertEqual(results.results.first?.currentJudgment, "near_match")
    }

    func testCreateCaptureSendsNestedMetadataAndQualityAndReturnsGeneratedCapture() async throws {
        var capturedRequest: URLRequest?
        StubURLProtocol.handler = { request in
            capturedRequest = request
            return StubbedHTTP.response(url: request.url!, status: 201, json: SpecFixtures.captureCreatedJSON)
        }

        let metadata = Components.Schemas.CaptureMetadata(
            appVersion: "0.1.0",
            deviceModel: "iPhone 15 Pro",
            exposureDurationSeconds: 0.016,
            focusLensPosition: 0.42,
            imageHeight: 3024,
            imageWidth: 4032,
            iso: 100,
            lens: "built_in_wide_angle",
            timestamp: Date(timeIntervalSince1970: 0),
            whiteBalanceGains: nil
        )
        let quality = Components.Schemas.CaptureRequest.qualityPayload(
            blurScore: 0.75,
            detectedMarkerCount: 4,
            rejections: []
        )
        let capture = try await client().createCapture(
            sheetID: "sheet_123",
            baseURL: baseURL,
            metadata: metadata,
            quality: quality
        )

        XCTAssertEqual(capture.captureId, "12")
        XCTAssertEqual(capturedRequest?.httpMethod, "POST")
        XCTAssertEqual(capturedRequest?.url?.path, "/api/v1/test_sheets/sheet_123/captures")
        XCTAssertEqual(capturedRequest?.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertEqual(capturedRequest?.value(forHTTPHeaderField: "Authorization"), "Bearer token")
        let body = StubbedHTTP.readBody(of: XCTUnwrap(capturedRequest))
        let json = try XCTUnwrap(StubbedHTTP.jsonObject(from: body) as? [String: Any])
        let metadataJSON = try XCTUnwrap(json["metadata"] as? [String: Any])
        XCTAssertEqual(metadataJSON["device_model"] as? String, "iPhone 15 Pro")
        XCTAssertEqual(metadataJSON["timestamp"] as? String, "1970-01-01T00:00:00Z")
        let qualityJSON = try XCTUnwrap(json["quality"] as? [String: Any])
        XCTAssertEqual(qualityJSON["detected_marker_count"] as? Int, 4)
        XCTAssertEqual(qualityJSON["rejections"] as? [String], [])
    }

    func testUploadMeasurementsOmitsUndocumentedFieldsAndReturnsGeneratedCounts() async throws {
        var capturedRequest: URLRequest?
        StubURLProtocol.handler = { request in
            capturedRequest = request
            return StubbedHTTP.response(url: request.url!, status: 200, json: SpecFixtures.measurementUploadJSON)
        }

        let rgb = RGB(r: 0.12, g: 0.10, b: 0.02)
        let stats = ChannelStats(
            median: rgb,
            mean: rgb,
            standardDeviation: RGB(r: 0.01, g: 0.01, b: 0.01),
            min: rgb,
            max: rgb,
            sampleCount: 900,
            clippingFraction: 0
        )
        let response = try await client().uploadMeasurements(
            captureID: "12",
            baseURL: baseURL,
            measurements: [
                PatchMeasurement(
                    patchID: "pair_1#first",
                    linearRGBMedian: rgb,
                    normalizedLinearRGBMedian: rgb,
                    stats: stats
                )
            ],
            scores: [
                PairScore(pairID: "pair_1", distance: 0.035, similarity: 0.965, algorithmVersion: "lps-distance-v1")
            ]
        )

        XCTAssertEqual(response.captureId, "12")
        XCTAssertEqual(response.measurementCount, 1)
        XCTAssertEqual(response.pairScoreCount, 1)
        XCTAssertEqual(capturedRequest?.url?.path, "/api/v1/captures/12/measurements")
        XCTAssertEqual(capturedRequest?.value(forHTTPHeaderField: "Authorization"), "Bearer token")
        let body = StubbedHTTP.readBody(of: XCTUnwrap(capturedRequest))
        let json = try XCTUnwrap(StubbedHTTP.jsonObject(from: body) as? [String: Any])
        XCTAssertEqual(Set(json.keys), ["measurements", "pair_scores"])
        let measurement = try XCTUnwrap((json["measurements"] as? [[String: Any]])?.first)
        XCTAssertEqual(
            Set(measurement.keys),
            ["patch_id", "linear_rgb_median", "normalized_linear_rgb_median"]
        )
        XCTAssertEqual(measurement["patch_id"] as? String, "pair_1#first")
        let median = try XCTUnwrap(measurement["linear_rgb_median"] as? [String: Any])
        XCTAssertEqual(median["r"] as? Double, 0.12)
        let score = try XCTUnwrap((json["pair_scores"] as? [[String: Any]])?.first)
        XCTAssertEqual(score["pair_id"] as? String, "pair_1")
        XCTAssertEqual(score["algorithm_version"] as? String, "lps-distance-v1")
        XCTAssertEqual(score["similarity"] as? Double, 0.965)
    }

    func testUploadJudgmentsReturnsGeneratedJudgmentCount() async throws {
        var capturedRequest: URLRequest?
        StubURLProtocol.handler = { request in
            capturedRequest = request
            return StubbedHTTP.response(url: request.url!, status: 200, json: SpecFixtures.judgmentUploadJSON)
        }

        let response = try await client().uploadJudgments(
            captureID: "12",
            baseURL: baseURL,
            judgments: [.init(judgment: "near_match", pairId: "pair_1")]
        )

        XCTAssertEqual(response.captureId, "12")
        XCTAssertEqual(response.judgmentCount, 1)
        XCTAssertEqual(capturedRequest?.httpMethod, "POST")
        XCTAssertEqual(capturedRequest?.url?.path, "/api/v1/captures/12/judgments")
        let body = StubbedHTTP.readBody(of: XCTUnwrap(capturedRequest))
        let json = try XCTUnwrap(StubbedHTTP.jsonObject(from: body) as? [String: Any])
        let judgments = try XCTUnwrap(json["judgments"] as? [[String: Any]])
        XCTAssertEqual(judgments.first?["pair_id"] as? String, "pair_1")
        XCTAssertEqual(judgments.first?["judgment"] as? String, "near_match")
    }

    func testUploadMeasurementsThrowsWhenStatusIsUndocumentedBySpec() async throws {
        StubURLProtocol.handler = { request in
            StubbedHTTP.emptyResponse(url: request.url!, status: 204)
        }

        await XCTAssertThrowsError(
            try await client().uploadMeasurements(captureID: "12", baseURL: baseURL, measurements: [], scores: [])
        )
    }
}
