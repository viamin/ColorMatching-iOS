import Foundation
import MeasurementCore
import XCTest
@testable import ColorMatchingLPSAppCore

final class APIClientTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.handler = nil
        super.tearDown()
    }

    func testFetchManifestByCodeDecodesPublishedManifest() async throws {
        var capturedRequest: URLRequest?
        MockURLProtocol.handler = { request in
            capturedRequest = request
            return try StubResponse.ok(APIFixtures.manifestJSON, for: request)
        }

        let manifest = try await stubbedClient().fetchManifest(
            baseURL: URL(string: "https://example.test")!,
            sheetCode: "sheet_1"
        )

        XCTAssertEqual(capturedRequest?.url?.path, "/api/v1/test_sheets/sheet_1/manifest")
        XCTAssertEqual(capturedRequest?.value(forHTTPHeaderField: "Authorization"), "Bearer token")
        XCTAssertEqual(manifest.schemaVersion, "lps-sheet-manifest/v1")
        XCTAssertEqual(manifest.sheetID, "sheet_1")
        XCTAssertEqual(manifest.sheetVersion, "lps-letter-grid-v1")
        XCTAssertEqual(manifest.page.units, "mm")
        XCTAssertEqual(manifest.registrationMarkers.first?.shape, "solid_square")
        XCTAssertEqual(manifest.patches.map(\.id), ["pair_1#first", "pair_1#second"])
        XCTAssertEqual(manifest.pairs.first?.sourceColors, ["#FF0000", "#00FF00"])
    }

    func testFetchRecentSheetsDecodesPublishedResponse() async throws {
        var capturedRequest: URLRequest?
        MockURLProtocol.handler = { request in
            capturedRequest = request
            return try StubResponse.ok(APIFixtures.recentSheetsJSON, for: request)
        }

        let sheets = try await stubbedClient().fetchRecentSheets(baseURL: URL(string: "https://example.test")!)

        XCTAssertEqual(capturedRequest?.url?.path, "/api/v1/test_sheets/recent")
        XCTAssertEqual(capturedRequest?.value(forHTTPHeaderField: "Authorization"), "Bearer token")
        XCTAssertEqual(sheets.map(\.sheetID), ["sheet_1", "sheet_2"])
        XCTAssertNil(sheets.first?.title)
        XCTAssertEqual(sheets.last?.title, "July LPS comparison sheet")
    }

    func testCreateCaptureEncodesMetadataAndQuality() async throws {
        var capturedRequest: URLRequest?
        MockURLProtocol.handler = { request in
            capturedRequest = request
            return try StubResponse.ok(APIFixtures.captureCreatedJSON, status: 201, for: request)
        }

        let response = try await stubbedClient().createCapture(
            sheetID: "sheet_1",
            baseURL: URL(string: "https://example.test")!,
            metadata: CaptureMetadata(
                deviceModel: "iPhone 15 Pro",
                lens: "built_in_wide_angle",
                exposureDurationSeconds: 0.016,
                iso: 100,
                focusLensPosition: 0.42,
                whiteBalanceGains: WhiteBalanceGains(red: 1.2, green: 1.0, blue: 1.4),
                imageWidth: 4032,
                imageHeight: 3024,
                appVersion: "0.1.0",
                timestamp: Date(timeIntervalSince1970: 1_784_987_200)
            ),
            quality: CaptureQuality(detectedMarkerCount: 4, blurScore: 0.82, rejections: [])
        )

        XCTAssertEqual(response.captureID, "42")
        XCTAssertEqual(capturedRequest?.url?.path, "/api/v1/test_sheets/sheet_1/captures")
        XCTAssertEqual(capturedRequest?.httpMethod, "POST")
        XCTAssertEqual(capturedRequest?.value(forHTTPHeaderField: "Authorization"), "Bearer token")
        XCTAssertEqual(capturedRequest?.value(forHTTPHeaderField: "Content-Type"), "application/json")
        let body = try jsonBody(of: capturedRequest)
        XCTAssertEqual(Set(body.keys), ["metadata", "quality"])
        let metadata = try XCTUnwrap(body["metadata"] as? [String: Any])
        XCTAssertEqual(
            Set(metadata.keys),
            [
                "device_model", "lens", "exposure_duration_seconds", "iso", "focus_lens_position",
                "white_balance_gains", "image_width", "image_height", "app_version", "timestamp"
            ]
        )
        XCTAssertEqual(metadata["device_model"] as? String, "iPhone 15 Pro")
        XCTAssertEqual(metadata["iso"] as? Int, 100)
        XCTAssertEqual(metadata["image_width"] as? Int, 4032)
        XCTAssertNotNil(metadata["timestamp"] as? String)
        let gains = try XCTUnwrap(metadata["white_balance_gains"] as? [String: Double])
        XCTAssertEqual(gains["red"] ?? 0, 1.2, accuracy: 0.0001)
        XCTAssertEqual(gains["green"] ?? 0, 1.0, accuracy: 0.0001)
        XCTAssertEqual(gains["blue"] ?? 0, 1.4, accuracy: 0.0001)
        let quality = try XCTUnwrap(body["quality"] as? [String: Any])
        XCTAssertEqual(quality["detected_marker_count"] as? Int, 4)
        XCTAssertEqual(try XCTUnwrap(quality["blur_score"] as? Double), 0.82, accuracy: 0.0001)
        XCTAssertEqual(quality["rejections"] as? [String], [])
    }

    func testUploadMeasurementsMatchesPublishedSpec() async throws {
        var capturedRequest: URLRequest?
        MockURLProtocol.handler = { request in
            capturedRequest = request
            return try StubResponse.ok(APIFixtures.measurementUploadResponseJSON, for: request)
        }

        let rgb = RGB(r: 0.12, g: 0.10, b: 0.02)
        let stats = ChannelStats(
            median: rgb,
            mean: rgb,
            standardDeviation: RGB(r: 0.01, g: 0.01, b: 0.004),
            min: rgb,
            max: rgb,
            sampleCount: 900,
            clippingFraction: 0
        )
        let receipt = try await stubbedClient().uploadMeasurements(
            captureID: "42",
            baseURL: URL(string: "https://example.test")!,
            measurements: [
                PatchMeasurement(patchID: "pair_1#first", linearRGBMedian: rgb, normalizedLinearRGBMedian: rgb, stats: stats)
            ],
            scores: [
                PairScore(pairID: "pair_1", distance: 0.035, similarity: 0.965, algorithmVersion: LPSScorer.algorithmVersion)
            ]
        )

        XCTAssertEqual(receipt.captureID, "42")
        XCTAssertEqual(receipt.measurementCount, 1)
        XCTAssertEqual(receipt.pairScoreCount, 1)
        XCTAssertEqual(capturedRequest?.url?.path, "/api/v1/captures/42/measurements")
        XCTAssertEqual(capturedRequest?.httpMethod, "POST")
        XCTAssertEqual(capturedRequest?.value(forHTTPHeaderField: "Authorization"), "Bearer token")
        let body = try jsonBody(of: capturedRequest)
        XCTAssertEqual(Set(body.keys), ["measurements", "pair_scores"])
        let measurement = try XCTUnwrap((body["measurements"] as? [[String: Any]])?.first)
        XCTAssertEqual(Set(measurement.keys), ["patch_id", "linear_rgb_median", "normalized_linear_rgb_median"])
        XCTAssertEqual(measurement["patch_id"] as? String, "pair_1#first")
        let linearMedian = try XCTUnwrap(measurement["linear_rgb_median"] as? [String: Double])
        XCTAssertEqual(linearMedian["r"] ?? 0, 0.12, accuracy: 0.0001)
        XCTAssertEqual(linearMedian["g"] ?? 0, 0.10, accuracy: 0.0001)
        XCTAssertEqual(linearMedian["b"] ?? 0, 0.02, accuracy: 0.0001)
        let normalizedMedian = try XCTUnwrap(measurement["normalized_linear_rgb_median"] as? [String: Double])
        XCTAssertEqual(normalizedMedian["r"] ?? 0, 0.12, accuracy: 0.0001)
        let score = try XCTUnwrap((body["pair_scores"] as? [[String: Any]])?.first)
        XCTAssertEqual(Set(score.keys), ["pair_id", "algorithm_version", "distance", "similarity"])
        XCTAssertEqual(score["pair_id"] as? String, "pair_1")
        XCTAssertEqual(score["algorithm_version"] as? String, "lps-distance-v1")
        XCTAssertEqual(try XCTUnwrap(score["distance"] as? Double), 0.035, accuracy: 0.0001)
    }

    func testUploadJudgmentsMatchesPublishedSpec() async throws {
        var capturedRequest: URLRequest?
        MockURLProtocol.handler = { request in
            capturedRequest = request
            return try StubResponse.ok(APIFixtures.judgmentUploadResponseJSON, for: request)
        }

        let receipt = try await stubbedClient().uploadJudgments(
            captureID: "42",
            baseURL: URL(string: "https://example.test")!,
            judgments: [PairJudgment(pairID: "pair_1", judgment: "near_match")]
        )

        XCTAssertEqual(receipt.captureID, "42")
        XCTAssertEqual(receipt.judgmentCount, 1)
        XCTAssertEqual(capturedRequest?.url?.path, "/api/v1/captures/42/judgments")
        XCTAssertEqual(capturedRequest?.httpMethod, "POST")
        XCTAssertEqual(capturedRequest?.value(forHTTPHeaderField: "Authorization"), "Bearer token")
        let body = try jsonBody(of: capturedRequest)
        XCTAssertEqual(Set(body.keys), ["judgments"])
        let judgment = try XCTUnwrap((body["judgments"] as? [[String: Any]])?.first)
        XCTAssertEqual(Set(judgment.keys), ["pair_id", "judgment"])
        XCTAssertEqual(judgment["pair_id"] as? String, "pair_1")
        XCTAssertEqual(judgment["judgment"] as? String, "near_match")
    }

    func testFetchManifestThrowsOnUnauthorized() async throws {
        MockURLProtocol.handler = { request in
            try StubResponse.make(status: 401, body: APIFixtures.errorJSON, for: request)
        }

        do {
            _ = try await stubbedClient().fetchManifest(
                baseURL: URL(string: "https://example.test")!,
                sheetCode: "sheet_1"
            )
            XCTFail("Expected an error for an unauthorized request")
        } catch {}
    }
}
