import Foundation
import MeasurementCore
import OpenAPIURLSession
import XCTest
@testable import ColorMatchingLPSAppCore

// Contract suite for the OpenAPI-generated client migration (issue #5).
//
// These tests pin the façade contract documented in
// docs/openapi-client-migration.md: APIClient delegates to the generated
// ColorMatchingAPI client (swift-openapi-generator), and every request/
// response below follows the published OpenAPI spec from
// viamin/color_matching#110 — including the deltas D1–D12 the prose contract
// missed (uploads return 200 + JSON bodies, `stats` is not part of the
// published measurement schema, ranked results carry `lps-ranked-results/v1`).
//
// All HTTP is stubbed via MockURLProtocol beneath URLSessionTransport; no
// test performs network I/O.

final class APIClientTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.handler = nil
        super.tearDown()
    }

    // MARK: - Manifest (GET /api/v1/test_sheets/{sheet_id}/manifest)

    func testFetchManifestDecodesPublishedManifestGeometry() async throws {
        let box = RequestBox()
        MockURLProtocol.handler = Stubber.route(
            ["/manifest": (200, Fixtures.manifest)],
            into: box
        )

        let manifest = try await makeClient().fetchManifest(sheetID: "sheet_123")

        XCTAssertEqual(manifest.schemaVersion, "lps-sheet-manifest/v1")
        XCTAssertEqual(manifest.sheetID, "sheet_123")
        XCTAssertEqual(manifest.patches.map(\.id), ["pair_1#first", "pair_1#second"])
        XCTAssertEqual(manifest.patches.first?.sourceColor, "#FF0000")
        XCTAssertEqual(manifest.pairs.first?.firstPatchID, "pair_1#first")
        XCTAssertEqual(manifest.pairs.first?.gridRow, 0)
        XCTAssertEqual(manifest.registrationMarkers.first?.rect.width, 8)
        XCTAssertEqual(box.request?.httpMethod, "GET")
        XCTAssertEqual(box.request?.url?.path, "/api/v1/test_sheets/sheet_123/manifest")
        XCTAssertEqual(box.request?.value(forHTTPHeaderField: "Authorization"), "Bearer token")
    }

    func testFetchManifestWithoutTokenOmitsAuthorizationHeader() async throws {
        let box = RequestBox()
        MockURLProtocol.handler = Stubber.route(
            ["/manifest": (200, Fixtures.manifest)],
            into: box
        )

        let manifest = try await makeClient(token: nil).fetchManifest(sheetID: "sheet_123")

        XCTAssertEqual(manifest.sheetID, "sheet_123")
        XCTAssertNil(box.request?.value(forHTTPHeaderField: "Authorization"))
    }

    // MARK: - Recent sheets (GET /api/v1/test_sheets/recent)

    func testFetchRecentSheetsDecodesNullableTitles() async throws {
        let box = RequestBox()
        MockURLProtocol.handler = Stubber.route(
            ["/recent": (200, Fixtures.recentSheets)],
            into: box
        )

        let sheets = try await makeClient().fetchRecentSheets()

        XCTAssertEqual(sheets.count, 2)
        XCTAssertEqual(sheets[0].sheetID, "sheet_123")
        XCTAssertNil(sheets[0].title)
        XCTAssertEqual(sheets[1].sheetID, "sheet_456")
        XCTAssertEqual(sheets[1].title, "July LPS comparison sheet")
        XCTAssertEqual(
            sheets[0].manifestURL.absoluteString,
            "https://example.test/api/v1/test_sheets/sheet_123/manifest"
        )
        XCTAssertEqual(box.request?.url?.path, "/api/v1/test_sheets/recent")
    }

    // MARK: - Ranked results (GET /api/v1/test_sheets/{sheet_id}/ranked_results)

    func testFetchRankedResultsDecodesPublishedEnvelope() async throws {
        let box = RequestBox()
        MockURLProtocol.handler = Stubber.route(
            ["/ranked_results": (200, Fixtures.rankedResults)],
            into: box
        )

        let summary = try await makeClient().fetchRankedResults(sheetID: "sheet_123")

        XCTAssertEqual(
            summary,
            RankedResultsSummary(schemaVersion: "lps-ranked-results/v1", sheetID: "sheet_123")
        )
        XCTAssertEqual(box.request?.httpMethod, "GET")
        XCTAssertEqual(box.request?.url?.path, "/api/v1/test_sheets/sheet_123/ranked_results")
    }

    // MARK: - Capture creation (POST /api/v1/test_sheets/{sheet_id}/captures)

    func testCreateCapturePostsNestedMetadataAndQualityAndDecodesCaptureID() async throws {
        let box = RequestBox()
        MockURLProtocol.handler = Stubber.route(
            ["/captures": (201, Fixtures.captureCreated)],
            into: box
        )

        let captureID = try await makeClient().createCapture(
            sheetID: "sheet_123",
            metadata: captureMetadata(),
            quality: CaptureQuality(detectedMarkerCount: 4, blurScore: 0.75, rejections: [.glare])
        )

        XCTAssertEqual(captureID, "42")
        XCTAssertEqual(box.request?.httpMethod, "POST")
        XCTAssertEqual(box.request?.url?.path, "/api/v1/test_sheets/sheet_123/captures")
        XCTAssertEqual(box.request?.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertEqual(box.request?.value(forHTTPHeaderField: "Authorization"), "Bearer token")

        let json = try XCTUnwrap(Self.jsonObject(from: box.body) as? [String: Any])
        // The published spec accepts flat or nested; the client uses the nested
        // branch (metadata + quality) that matches the prose contract (D5).
        let metadata = try XCTUnwrap(json["metadata"] as? [String: Any])
        XCTAssertEqual(metadata["device_model"] as? String, "iPhone 15 Pro")
        XCTAssertEqual(metadata["lens"] as? String, "built_in_wide_angle")
        XCTAssertEqual(try metadata.number("exposure_duration_seconds"), 0.01, accuracy: 0.0001)
        XCTAssertEqual(try metadata.int("iso"), 100)
        XCTAssertEqual(try metadata.int("image_width"), 4032)
        XCTAssertEqual(try metadata.int("image_height"), 3024)
        XCTAssertEqual(metadata["app_version"] as? String, "0.1.0")
        let timestamp = try XCTUnwrap(metadata["timestamp"] as? String)
        XCTAssertTrue(timestamp.hasPrefix("1970-01-01T00:00:00"), "unexpected timestamp \(timestamp)")
        let quality = try XCTUnwrap(json["quality"] as? [String: Any])
        XCTAssertEqual(try quality.int("detected_marker_count"), 4)
        XCTAssertEqual(try quality.number("blur_score"), 0.75, accuracy: 0.0001)
        XCTAssertEqual(quality["rejections"] as? [String], ["glare"])
    }

    // MARK: - Measurement upload (POST /api/v1/captures/{capture_id}/measurements)

    func testUploadMeasurementsEncodesPublishedRequestShapeAndDecodesCounts() async throws {
        let box = RequestBox()
        MockURLProtocol.handler = Stubber.route(
            // D7: the published spec returns 200 with a JSON body, not 204.
            ["/measurements": (200, Fixtures.measurementUploadResponse)],
            into: box
        )

        let summary = try await makeClient().uploadMeasurements(
            captureID: "42",
            measurements: [
                PatchMeasurement(
                    patchID: "pair_1#first",
                    linearRGBMedian: RGB(r: 0.2, g: 0.3, b: 0.4),
                    normalizedLinearRGBMedian: RGB(r: 0.15, g: 0.25, b: 0.35),
                    stats: measurementStats()
                )
            ],
            scores: [
                PairScore(
                    pairID: "pair_1",
                    distance: 0.1,
                    similarity: 0.9,
                    algorithmVersion: LPSScorer.algorithmVersion
                )
            ]
        )

        XCTAssertEqual(summary, UploadSummary(captureID: "42", measurementCount: 1, pairScoreCount: 1))
        XCTAssertEqual(box.request?.httpMethod, "POST")
        XCTAssertEqual(box.request?.url?.path, "/api/v1/captures/42/measurements")

        let json = try XCTUnwrap(Self.jsonObject(from: box.body) as? [String: Any])
        // D6/G2: no top-level scoring_algorithm_version in the published
        // request schema — the version travels on each pair score.
        XCTAssertNil(json["scoring_algorithm_version"])

        let measurement = try XCTUnwrap((json["measurements"] as? [[String: Any]])?.first)
        XCTAssertEqual(measurement["patch_id"] as? String, "pair_1#first")
        XCTAssertEqual(
            measurement["linear_rgb_median"] as? [String: Double],
            ["r": 0.2, "g": 0.3, "b": 0.4]
        )
        // D6: normalized_linear_rgb_median is required by the published schema.
        XCTAssertNotNil(measurement["normalized_linear_rgb_median"])
        // G2: per-patch stats are not part of the published schema.
        XCTAssertNil(measurement["stats"])

        let pairScore = try XCTUnwrap((json["pair_scores"] as? [[String: Any]])?.first)
        XCTAssertEqual(pairScore["pair_id"] as? String, "pair_1")
        XCTAssertEqual(pairScore["algorithm_version"] as? String, "lps-distance-v1")
        XCTAssertEqual(try pairScore.number("distance"), 0.1, accuracy: 0.0001)
    }

    // MARK: - Judgment upload (POST /api/v1/captures/{capture_id}/judgments)

    func testUploadJudgmentsEncodesPayloadAndDecodesCount() async throws {
        let box = RequestBox()
        MockURLProtocol.handler = Stubber.route(
            // D8: 200 with a JSON body, not 204.
            ["/judgments": (200, Fixtures.judgmentUploadResponse)],
            into: box
        )

        let summary = try await makeClient().uploadJudgments(
            captureID: "42",
            judgments: [
                PairJudgment(pairID: "pair_1", judgment: "near_match"),
                PairJudgment(pairID: "pair_2", judgment: "match")
            ]
        )

        XCTAssertEqual(summary, JudgmentSummary(captureID: "42", judgmentCount: 2))
        XCTAssertEqual(box.request?.httpMethod, "POST")
        XCTAssertEqual(box.request?.url?.path, "/api/v1/captures/42/judgments")

        let json = try XCTUnwrap(Self.jsonObject(from: box.body) as? [String: Any])
        let judgments = try XCTUnwrap(json["judgments"] as? [[String: Any]])
        XCTAssertEqual(judgments.count, 2)
        XCTAssertEqual(judgments[0]["pair_id"] as? String, "pair_1")
        XCTAssertEqual(judgments[0]["judgment"] as? String, "near_match")
        XCTAssertEqual(judgments[1]["judgment"] as? String, "match")
    }

    // MARK: - Error mapping (documented 401/404/422 and undocumented non-2xx)

    func testNonSuccessStatusesSurfaceAsBadStatus() async throws {
        let box = RequestBox()
        MockURLProtocol.handler = Stubber.route(
            [
                "/manifest": (404, Fixtures.notFoundError),
                "/measurements": (401, Fixtures.unauthorizedError),
                "/judgments": (422, Fixtures.judgmentValidationError),
                "/recent": (500, #"{"errors": {"detail": "boom"}}"#)
            ],
            into: box
        )
        let client = makeClient()

        do {
            _ = try await client.fetchManifest(sheetID: "sheet_123")
            XCTFail("Expected .badStatus(404)")
        } catch {
            XCTAssertEqual(error as? APIError, .badStatus(statusCode: 404))
        }

        do {
            _ = try await client.uploadMeasurements(
                captureID: "42",
                measurements: [],
                scores: []
            )
            XCTFail("Expected .badStatus(401)")
        } catch {
            XCTAssertEqual(error as? APIError, .badStatus(statusCode: 401))
        }

        do {
            _ = try await client.uploadJudgments(captureID: "42", judgments: [])
            XCTFail("Expected .badStatus(422)")
        } catch {
            XCTAssertEqual(error as? APIError, .badStatus(statusCode: 422))
        }

        do {
            _ = try await client.fetchRecentSheets()
            XCTFail("Expected .badStatus(500)")
        } catch {
            XCTAssertEqual(error as? APIError, .badStatus(statusCode: 500))
        }
    }

    // MARK: - Helpers

    private func makeClient(token: String? = "token") -> APIClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: configuration)
        return APIClient(
            baseURL: URL(string: "https://example.test")!,
            token: token,
            transport: URLSessionTransport(configuration: .init(session: session))
        )
    }

    private func captureMetadata() -> CaptureMetadata {
        CaptureMetadata(
            deviceModel: "iPhone 15 Pro",
            lens: "built_in_wide_angle",
            exposureDurationSeconds: 0.01,
            iso: 100,
            focusLensPosition: 0.42,
            whiteBalanceGains: WhiteBalanceGains(red: 1.2, green: 1.0, blue: 1.4),
            imageWidth: 4032,
            imageHeight: 3024,
            appVersion: "0.1.0",
            timestamp: Date(timeIntervalSince1970: 0)
        )
    }

    private func measurementStats() -> ChannelStats {
        let rgb = RGB(r: 0.2, g: 0.3, b: 0.4)
        return ChannelStats(
            median: rgb,
            mean: rgb,
            standardDeviation: RGB(r: 0.01, g: 0.01, b: 0.01),
            min: rgb,
            max: rgb,
            sampleCount: 9,
            clippingFraction: 0
        )
    }

    private static func jsonObject(from data: Data?) throws -> Any {
        try JSONSerialization.jsonObject(with: XCTUnwrap(data))
    }
}

private extension Dictionary where Key == String, Value == Any {
    func int(_ key: String) throws -> Int {
        let number = try XCTUnwrap(self[key] as? NSNumber)
        return number.intValue
    }

    func number(_ key: String) throws -> Double {
        let number = try XCTUnwrap(self[key] as? NSNumber)
        return number.doubleValue
    }
}
