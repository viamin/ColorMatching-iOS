import Foundation
import MeasurementCore
import XCTest
@testable import ColorMatchingLPSAppCore

// Pins the app-facing APIClient facade after the hand-written API layer is
// replaced by the generated OpenAPI client (see docs/openapi-client-test-plan.md).
//
// The facade keeps the call sites from ContentView working while its wire
// responses and results are the generated types, server error bodies become
// typed APIError cases, and the responses the prose contract didn't document
// (upload counts, ranked results) become first-class results.
final class APIClientFacadeTests: XCTestCase {
    override func tearDown() {
        StubbedURLProtocol.handler = nil
        super.tearDown()
    }

    private let baseURL = URL(string: "https://example.test")!

    // MARK: - Manifest

    func testFetchManifestBySheetCodeReturnsFullClientSideManifest() async throws {
        StubbedURLProtocol.handler = { request in
            Stubbing.jsonResponse(for: request, status: 200, json: Fixtures.manifestJSON)
        }

        let manifest = try await client().fetchManifest(baseURL: baseURL, sheetCode: "sheet_123")

        XCTAssertEqual(manifest.schemaVersion, "lps-sheet-manifest/v1")
        XCTAssertEqual(manifest.sheetVersion, "lps-letter-grid-v1")
        XCTAssertEqual(manifest.sheetID, "sheet_123")
        XCTAssertEqual(manifest.manifestURL.absoluteString, "https://example.test/api/v1/test_sheets/sheet_123/manifest")
        XCTAssertEqual(manifest.page.units, "mm")
        XCTAssertEqual(manifest.page.width, 215.9, accuracy: 0.001)
        XCTAssertEqual(manifest.registrationMarkers.first?.role, "top_left")
        XCTAssertEqual(manifest.patches.map(\.id), ["pair_1#first", "pair_1#second"])
        XCTAssertEqual(manifest.patches.first?.safeInsetMM, 1.5, accuracy: 0.001)
        XCTAssertEqual(manifest.pairs.first?.firstPatchID, "pair_1#first")
        XCTAssertEqual(manifest.pairs.first?.sourceColors, ["#FF0000", "#00FF00"])
    }

    func testFetchManifestFromFullURLDerivesServerAndSheetCode() async throws {
        var capturedRequest: URLRequest?
        StubbedURLProtocol.handler = { request in
            capturedRequest = request
            return Stubbing.jsonResponse(for: request, status: 200, json: Fixtures.manifestJSON)
        }

        let manifestURL = URL(string: "https://example.test/api/v1/test_sheets/sheet_123/manifest")!
        let manifest = try await client().fetchManifest(from: manifestURL)

        XCTAssertEqual(capturedRequest?.url?.path, "/api/v1/test_sheets/sheet_123/manifest")
        XCTAssertEqual(manifest.sheetID, "sheet_123")
    }

    // MARK: - Recent sheets

    func testFetchRecentSheetsReturnsGeneratedItems() async throws {
        StubbedURLProtocol.handler = { request in
            Stubbing.jsonResponse(for: request, status: 200, json: Fixtures.recentSheetsJSON)
        }

        let sheets = try await client().fetchRecentSheets(baseURL: baseURL)

        XCTAssertEqual(sheets.count, 1)
        XCTAssertEqual(sheets.first?.sheetId, "sheet_123")
        XCTAssertEqual(
            sheets.first?.manifestUrl,
            "https://example.test/api/v1/test_sheets/sheet_123/manifest"
        )
        XCTAssertNil(sheets.first?.title)
    }

    // MARK: - Ranked results

    func testFetchRankedResultsReturnsGeneratedSchema() async throws {
        StubbedURLProtocol.handler = { request in
            Stubbing.jsonResponse(for: request, status: 200, json: Fixtures.rankedResultsJSON)
        }

        let results = try await client().fetchRankedResults(sheetID: "sheet_123", baseURL: baseURL)

        XCTAssertEqual(results.schemaVersion.rawValue, "lps-ranked-results/v1")
        XCTAssertEqual(results.sheetId, "sheet_123")
    }

    // MARK: - Capture creation

    func testCreateCaptureReturnsGeneratedCaptureIDAndSendsBearerToken() async throws {
        var capturedRequest: URLRequest?
        StubbedURLProtocol.handler = { request in
            capturedRequest = request
            return Stubbing.jsonResponse(for: request, status: 201, json: Fixtures.captureCreatedJSON)
        }

        let created = try await client().createCapture(
            sheetID: "sheet_123",
            baseURL: baseURL,
            metadata: captureMetadata(),
            quality: CaptureQuality(detectedMarkerCount: 4, blurScore: 0.82, rejections: [])
        )

        XCTAssertEqual(capturedRequest?.url?.path, "/api/v1/test_sheets/sheet_123/captures")
        XCTAssertEqual(capturedRequest?.value(forHTTPHeaderField: "Authorization"), "Bearer token")

        // Generated result type: capture ids are stringified integer ids.
        XCTAssertEqual(created.captureId, "421")
    }

    // MARK: - Measurement upload

    func testUploadMeasurementsPreservesWireShapeAndReturnsServerCounts() async throws {
        var capturedRequest: URLRequest?
        StubbedURLProtocol.handler = { request in
            capturedRequest = request
            return Stubbing.jsonResponse(for: request, status: 200, json: Fixtures.measurementUploadResponseJSON)
        }

        let result = try await client().uploadMeasurements(
            captureID: "421",
            baseURL: baseURL,
            measurements: [
                measurement(patchID: "pair_1#first"),
                measurement(patchID: "pair_1#second")
            ],
            scores: [
                PairScore(pairID: "pair_1", distance: 0.035, similarity: 0.965, algorithmVersion: LPSScorer.algorithmVersion)
            ]
        )

        XCTAssertEqual(capturedRequest?.url?.path, "/api/v1/captures/421/measurements")
        let json = try XCTUnwrap(RequestBody.jsonObject(of: capturedRequest!) as? [String: Any])
        XCTAssertEqual(json["scoring_algorithm_version"] as? String, "lps-distance-v1")
        let first = try XCTUnwrap((json["measurements"] as? [[String: Any]])?.first)
        XCTAssertEqual(first["patch_id"] as? String, "pair_1#first")
        XCTAssertEqual(first["linear_rgb_median"] as? [String: Double], ["r": 0.12, "g": 0.1, "b": 0.02])
        let stats = try XCTUnwrap(first["stats"] as? [String: Any])
        XCTAssertEqual(stats["sample_count"] as? Int, 900)
        let score = try XCTUnwrap((json["pair_scores"] as? [[String: Any]])?.first)
        XCTAssertEqual(score["algorithm_version"] as? String, "lps-distance-v1")

        XCTAssertEqual(result.captureId, "421")
        XCTAssertEqual(result.measurementCount, 2)
        XCTAssertEqual(result.pairScoreCount, 1)
    }

    // MARK: - Judgment upload

    func testUploadJudgmentsPreservesWireShapeAndReturnsServerCount() async throws {
        var capturedRequest: URLRequest?
        StubbedURLProtocol.handler = { request in
            capturedRequest = request
            return Stubbing.jsonResponse(for: request, status: 200, json: Fixtures.judgmentUploadResponseJSON)
        }

        let result = try await client().uploadJudgments(
            captureID: "421",
            baseURL: baseURL,
            judgments: [PairJudgment(pairID: "pair_1", judgment: "near_match")]
        )

        XCTAssertEqual(capturedRequest?.url?.path, "/api/v1/captures/421/judgments")
        let json = try XCTUnwrap(RequestBody.jsonObject(of: capturedRequest!) as? [String: Any])
        XCTAssertEqual(
            (json["judgments"] as? [[String: Any]])?.first?["judgment"] as? String,
            "near_match"
        )

        XCTAssertEqual(result.judgmentCount, 1)
    }

    // MARK: - Typed errors

    func testNotFoundSurfacesServerErrorDetail() async throws {
        StubbedURLProtocol.handler = { request in
            Stubbing.jsonResponse(for: request, status: 404, json: Fixtures.notFoundErrorJSON)
        }

        do {
            _ = try await client().fetchManifest(baseURL: baseURL, sheetCode: "missing")
            XCTFail("Expected APIError.notFound")
        } catch let error as APIError {
            XCTAssertEqual(error, .notFound(detail: "Sheet not found"))
        }
    }

    func testUnprocessableEntitySurfacesWithoutDetailWhenBodyHasNoDetailKey() async throws {
        StubbedURLProtocol.handler = { request in
            Stubbing.jsonResponse(
                for: request,
                status: 422,
                json: Data(#"{"errors": {"judgments": ["invalid"]}}"#.utf8)
            )
        }

        do {
            _ = try await client().uploadJudgments(
                captureID: "421",
                baseURL: baseURL,
                judgments: [PairJudgment(pairID: "pair_1", judgment: "bogus")]
            )
            XCTFail("Expected APIError.unprocessableEntity")
        } catch let error as APIError {
            XCTAssertEqual(error, .unprocessableEntity(detail: nil))
        }
    }

    func testUndocumentedStatusSurfacesAsUnexpectedStatus() async throws {
        StubbedURLProtocol.handler = { request in
            Stubbing.emptyResponse(for: request, status: 500)
        }

        do {
            _ = try await client().fetchRecentSheets(baseURL: baseURL)
            XCTFail("Expected APIError.unexpectedStatus")
        } catch let error as APIError {
            XCTAssertEqual(error, .unexpectedStatus(500))
        }
    }

    // MARK: - Helpers

    private func client() -> APIClient {
        APIClient(token: "token", session: Stubbing.session())
    }

    private func captureMetadata() -> CaptureMetadata {
        CaptureMetadata(
            deviceModel: "iPhone",
            lens: "built_in_wide_angle",
            exposureDurationSeconds: 0.01,
            iso: 100,
            focusLensPosition: 0.4,
            whiteBalanceGains: WhiteBalanceGains(red: 1.1, green: 1.0, blue: 1.2),
            imageWidth: 4032,
            imageHeight: 3024,
            appVersion: "0.1.0",
            timestamp: Date(timeIntervalSince1970: 1_784_980_800)
        )
    }

    private func measurement(patchID: String) -> PatchMeasurement {
        let median = RGB(r: 0.12, g: 0.1, b: 0.02)
        let normalized = RGB(r: 0.15, g: 0.12, b: 0.02)
        let stats = ChannelStats(
            median: median,
            mean: median,
            standardDeviation: RGB(r: 0.01, g: 0.01, b: 0.004),
            min: median,
            max: median,
            sampleCount: 900,
            clippingFraction: 0
        )
        return PatchMeasurement(
            patchID: patchID,
            linearRGBMedian: median,
            normalizedLinearRGBMedian: normalized,
            stats: stats
        )
    }
}
