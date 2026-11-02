import XCTest
import MeasurementCore
import OpenAPIRuntime
import ColorMatchingAPI
import ColorMatchingLPSAppCore

final class ColorMatchingAPIClientTests: XCTestCase {
    private let baseURL = URL(string: "https://example.test")!

    func testFetchManifestByCodeAppliesBearerTokenAndMapsDomainManifest() async throws {
        let transport = StubTransport()
        transport.enqueue(StubTransport.jsonResponse(statusCode: 200, payload: Fixtures.manifest))
        let client = ColorMatchingAPIClient(token: "token", transport: transport)

        let manifest = try await client.fetchManifest(baseURL: baseURL, sheetCode: "sheet_123")

        XCTAssertEqual(manifest.schemaVersion, "lps-sheet-manifest/v1")
        XCTAssertEqual(manifest.sheetID, "sheet_123")
        XCTAssertEqual(manifest.manifestURL, URL(string: "https://example.test/api/v1/test_sheets/sheet_123/manifest"))
        XCTAssertEqual(manifest.page.units, "mm")
        XCTAssertEqual(manifest.page.width, 215.9, accuracy: 0.0001)
        XCTAssertEqual(manifest.registrationMarkers.first?.role, "top_left")
        let marker = try XCTUnwrap(manifest.registrationMarkers.first)
        XCTAssertEqual(marker.rect.height, 8, accuracy: 0.0001)
        XCTAssertEqual(manifest.patches.count, 2)
        let patch = try XCTUnwrap(manifest.patches.first)
        XCTAssertEqual(patch.id, "pair_1#first")
        XCTAssertEqual(patch.pairID, "pair_1")
        XCTAssertEqual(patch.pairSide, "first")
        XCTAssertEqual(patch.sourceColor, "#FF0000")
        XCTAssertEqual(patch.safeInsetMM, 1.5, accuracy: 0.0001)
        XCTAssertEqual(patch.rect.width, 16, accuracy: 0.0001)
        let pair = try XCTUnwrap(manifest.pairs.first)
        XCTAssertEqual(pair.id, "pair_1")
        XCTAssertEqual(pair.firstPatchID, "pair_1#first")
        XCTAssertEqual(pair.secondPatchID, "pair_1#second")
        XCTAssertEqual(pair.sourceColors, ["#FF0000", "#00FF00"])
        XCTAssertEqual(pair.gridRow, 0)
        XCTAssertEqual(pair.gridCol, 1)

        let recorded = try XCTUnwrap(transport.recordedRequests.first)
        XCTAssertEqual(recorded.authorization, "Bearer token")
        XCTAssertEqual(recorded.method, "GET")
        XCTAssertEqual(recorded.path, "/api/v1/test_sheets/sheet_123/manifest")
    }

    func testFetchManifestFromURLExtractsSheetCodeAndOmitsAuthorizationWithoutToken() async throws {
        let transport = StubTransport()
        transport.enqueue(StubTransport.jsonResponse(statusCode: 200, payload: Fixtures.manifest))
        let client = ColorMatchingAPIClient(token: nil, transport: transport)

        let manifest = try await client.fetchManifest(
            from: URL(string: "https://example.test/api/v1/test_sheets/sheet_123/manifest")!
        )

        XCTAssertEqual(manifest.sheetID, "sheet_123")
        let recorded = try XCTUnwrap(transport.recordedRequests.first)
        XCTAssertNil(recorded.authorization)
        XCTAssertEqual(recorded.path, "/api/v1/test_sheets/sheet_123/manifest")
    }

    func testFetchRecentSheetsReturnsGeneratedSheets() async throws {
        let transport = StubTransport()
        transport.enqueue(StubTransport.jsonResponse(statusCode: 200, payload: Fixtures.recentSheets))
        let client = ColorMatchingAPIClient(token: "token", transport: transport)

        let sheets = try await client.fetchRecentSheets(baseURL: baseURL)

        XCTAssertEqual(sheets.count, 1)
        let sheet = try XCTUnwrap(sheets.first)
        XCTAssertEqual(sheet.sheetId, "sheet_123")
        XCTAssertEqual(sheet.manifestUrl, "https://example.test/api/v1/test_sheets/sheet_123/manifest")
        XCTAssertNil(sheet.title)
        let recorded = try XCTUnwrap(transport.recordedRequests.first)
        XCTAssertEqual(recorded.path, "/api/v1/test_sheets/recent")
        XCTAssertEqual(recorded.authorization, "Bearer token")
    }

    func testCreateCaptureSendsGeneratedMetadataAndReturnsCaptureID() async throws {
        let transport = StubTransport()
        transport.enqueue(StubTransport.jsonResponse(statusCode: 201, payload: Fixtures.captureCreated))
        let client = ColorMatchingAPIClient(token: "token", transport: transport)

        let captureID = try await client.createCapture(
            sheetID: "sheet_1",
            baseURL: baseURL,
            metadata: Components.Schemas.CaptureMetadata(
                deviceModel: "iPhone 15",
                lens: "built_in_wide_angle",
                exposureDurationSeconds: 0.016,
                iso: 100,
                focusLensPosition: 0.42,
                whiteBalanceGains: Components.Schemas.WhiteBalanceGains(red: 1.2, green: 1.0, blue: 1.4),
                imageWidth: 4032,
                imageHeight: 3024,
                appVersion: "0.1.0",
                timestamp: Date(timeIntervalSince1970: 0)
            ),
            quality: CaptureQuality(detectedMarkerCount: 4, blurScore: 0.75, rejections: [])
        )

        XCTAssertEqual(captureID, "cap_1")
        let recorded = try XCTUnwrap(transport.recordedRequests.first)
        XCTAssertEqual(recorded.method, "POST")
        XCTAssertEqual(recorded.path, "/api/v1/test_sheets/sheet_1/captures")
        XCTAssertEqual(recorded.authorization, "Bearer token")
        XCTAssertEqual(recorded.contentType?.hasPrefix("application/json"), true)
        let json = try decodeJSONObject(from: recorded.bodyData)
        let metadataJSON = try XCTUnwrap(json["metadata"] as? [String: Any])
        XCTAssertEqual(metadataJSON["device_model"] as? String, "iPhone 15")
        XCTAssertEqual(metadataJSON["timestamp"] as? String, "1970-01-01T00:00:00Z")
        let qualityJSON = try XCTUnwrap(json["quality"] as? [String: Any])
        XCTAssertEqual(qualityJSON["detected_marker_count"] as? Int, 4)
        XCTAssertEqual(try doubleValue(qualityJSON, "blur_score"), 0.75, accuracy: 0.000001)
    }

    func testUploadMeasurementsSendsPerPairAlgorithmVersionWithoutTopLevelVersion() async throws {
        let transport = StubTransport()
        transport.enqueue(StubTransport.jsonResponse(statusCode: 200, payload: Fixtures.measurementAccepted))
        let client = ColorMatchingAPIClient(token: "token", transport: transport)

        let rgb = RGB(r: 0.12, g: 0.1, b: 0.02)
        let stats = ChannelStats(
            median: rgb,
            mean: rgb,
            standardDeviation: RGB(r: 0.01, g: 0.01, b: 0.004),
            min: rgb,
            max: rgb,
            sampleCount: 900,
            clippingFraction: 0
        )
        let measurement = PatchMeasurement(
            patchID: "pair_1#first",
            linearRGBMedian: rgb,
            normalizedLinearRGBMedian: RGB(r: 0.15, g: 0.12, b: 0.02),
            stats: stats
        )
        let score = PairScore(
            pairID: "pair_1",
            distance: 0.035,
            similarity: 0.965,
            algorithmVersion: "lps-distance-v1"
        )

        let accepted = try await client.uploadMeasurements(
            captureID: "cap_1",
            baseURL: baseURL,
            measurements: [measurement],
            scores: [score]
        )

        XCTAssertEqual(accepted.captureId, "cap_1")
        XCTAssertEqual(accepted.measurementCount, 1)
        XCTAssertEqual(accepted.pairScoreCount, 1)

        let recorded = try XCTUnwrap(transport.recordedRequests.first)
        XCTAssertEqual(recorded.method, "POST")
        XCTAssertEqual(recorded.path, "/api/v1/captures/cap_1/measurements")
        XCTAssertEqual(recorded.authorization, "Bearer token")
        let json = try decodeJSONObject(from: recorded.bodyData)
        XCTAssertNil(json["scoring_algorithm_version"])
        let measurementJSON = try XCTUnwrap((json["measurements"] as? [[String: Any]])?.first)
        XCTAssertEqual(measurementJSON["patch_id"] as? String, "pair_1#first")
        let linearJSON = try XCTUnwrap(measurementJSON["linear_rgb_median"] as? [String: Any])
        XCTAssertEqual(try doubleValue(linearJSON, "r"), 0.12, accuracy: 0.000001)
        let normalizedJSON = try XCTUnwrap(measurementJSON["normalized_linear_rgb_median"] as? [String: Any])
        XCTAssertEqual(try doubleValue(normalizedJSON, "r"), 0.15, accuracy: 0.000001)
        let statsJSON = try XCTUnwrap(measurementJSON["stats"] as? [String: Any])
        XCTAssertEqual(statsJSON["sample_count"] as? Int, 900)
        XCTAssertEqual(try doubleValue(statsJSON, "clipping_fraction"), 0, accuracy: 0.000001)
        let standardDeviationJSON = try XCTUnwrap(statsJSON["standard_deviation"] as? [String: Any])
        XCTAssertEqual(try doubleValue(standardDeviationJSON, "b"), 0.004, accuracy: 0.000001)
        let scoreJSON = try XCTUnwrap((json["pair_scores"] as? [[String: Any]])?.first)
        XCTAssertEqual(scoreJSON["pair_id"] as? String, "pair_1")
        XCTAssertEqual(scoreJSON["algorithm_version"] as? String, "lps-distance-v1")
        XCTAssertEqual(try doubleValue(scoreJSON, "similarity"), 0.965, accuracy: 0.000001)
        XCTAssertEqual(try doubleValue(scoreJSON, "distance"), 0.035, accuracy: 0.000001)
    }

    func testUploadJudgmentsSendsGeneratedEntriesAndDecodesCount() async throws {
        let transport = StubTransport()
        transport.enqueue(StubTransport.jsonResponse(statusCode: 200, payload: Fixtures.judgmentsAccepted))
        let client = ColorMatchingAPIClient(token: "token", transport: transport)

        let accepted = try await client.uploadJudgments(
            captureID: "cap_1",
            baseURL: baseURL,
            judgments: [
                Components.Schemas.PairJudgmentEntry(pairId: "pair_1", judgment: "near_match")
            ]
        )

        XCTAssertEqual(accepted.captureId, "cap_1")
        XCTAssertEqual(accepted.judgmentCount, 1)
        let recorded = try XCTUnwrap(transport.recordedRequests.first)
        XCTAssertEqual(recorded.method, "POST")
        XCTAssertEqual(recorded.path, "/api/v1/captures/cap_1/judgments")
        let json = try decodeJSONObject(from: recorded.bodyData)
        let judgmentJSON = try XCTUnwrap((json["judgments"] as? [[String: Any]])?.first)
        XCTAssertEqual(judgmentJSON["pair_id"] as? String, "pair_1")
        XCTAssertEqual(judgmentJSON["judgment"] as? String, "near_match")
    }

    func testFetchRankedResultsDecodesAggregatePayload() async throws {
        let transport = StubTransport()
        transport.enqueue(StubTransport.jsonResponse(statusCode: 200, payload: Fixtures.rankedResults))
        let client = ColorMatchingAPIClient(token: "token", transport: transport)

        let results = try await client.fetchRankedResults(sheetID: "sheet_123", baseURL: baseURL)

        XCTAssertEqual(results.schemaVersion, "lps-ranked-results/v1")
        XCTAssertEqual(results.sheetId, "sheet_123")
        let entry = try XCTUnwrap(results.results.first)
        XCTAssertEqual(entry.rank, 1)
        XCTAssertEqual(entry.currentJudgment, "near_match")
        XCTAssertEqual(entry.score.captureCount, 2)
        let recorded = try XCTUnwrap(transport.recordedRequests.first)
        XCTAssertEqual(recorded.path, "/api/v1/test_sheets/sheet_123/ranked_results")
        XCTAssertEqual(recorded.authorization, "Bearer token")
    }

    func testFetchManifestThrowsUnexpectedStatusCodeOnNotFound() async throws {
        let transport = StubTransport()
        transport.enqueue(StubTransport.jsonResponse(statusCode: 404, payload: Fixtures.sheetNotFound))
        let client = ColorMatchingAPIClient(token: "token", transport: transport)

        do {
            _ = try await client.fetchManifest(baseURL: baseURL, sheetCode: "missing")
            XCTFail("Expected fetchManifest to throw")
        } catch let error as ColorMatchingAPIError {
            XCTAssertEqual(error, .unexpectedStatusCode(404))
        }
    }
}
