import Foundation
import MeasurementCore
import XCTest
@testable import ColorMatchingLPSAppCore

/// Exercises the API layer against stubbed server responses.
///
/// The assertions are written against the JSON that travels over the wire, so
/// they hold whether a payload is produced by the generated OpenAPI types or by
/// a hand-written model, and they fail loudly when a payload loses data.
final class APIClientTests: XCTestCase {
    override func tearDown() {
        StubURLProtocol.handler = nil
        super.tearDown()
    }

    func testManifestFetchUsesDocumentedEndpointAndKeepsSheetPayload() async throws {
        var capturedRequest: URLRequest?
        StubURLProtocol.handler = { request in
            capturedRequest = request
            return StubURLProtocol.Stub(statusCode: 200, json: APIFixtures.manifest)
        }

        let manifest = try await client().fetchManifest(from: URL(string: "https://example.test/api/v1/test_sheets/sheet_123/manifest")!)
        let json = try JSONProbe.object(manifest)

        XCTAssertEqual(capturedRequest?.httpMethod, "GET")
        XCTAssertEqual(capturedRequest?.url?.path.hasSuffix("/manifest"), true)
        XCTAssertEqual(capturedRequest?.value(forHTTPHeaderField: "Authorization"), "Bearer token")
        XCTAssertEqual(JSONProbe.string(json, ["sheet_id", "sheetID"]), "sheet_123")
        XCTAssertEqual(JSONProbe.string(json, ["schema_version", "schemaVersion"]), "lps-sheet-manifest/v1")

        let patches = json["patches"] as? [[String: Any]]
        XCTAssertEqual(patches?.count, 2, "The manifest must keep the patch list the analyzer samples")
        XCTAssertEqual(JSONProbe.string(patches?[0] ?? [:], ["id"]), "pair_1#first")

        let pairs = json["pairs"] as? [[String: Any]]
        XCTAssertEqual(pairs?.count, 1, "The manifest must keep the pair list the scorer ranks")
        XCTAssertEqual(JSONProbe.string(pairs?[0] ?? [:], ["id"]), "pair_1")
    }

    func testRecentSheetsUseDocumentedEndpointAndKeepServerPayload() async throws {
        var capturedRequest: URLRequest?
        StubURLProtocol.handler = { request in
            capturedRequest = request
            return StubURLProtocol.Stub(statusCode: 200, json: APIFixtures.recentSheets)
        }

        let sheets = try await client().fetchRecentSheets(baseURL: URL(string: "https://example.test")!)
        let json = try JSONProbe.array(sheets)

        XCTAssertEqual(capturedRequest?.httpMethod, "GET")
        XCTAssertEqual(capturedRequest?.url?.path, "/api/v1/test_sheets/recent")
        XCTAssertEqual(capturedRequest?.value(forHTTPHeaderField: "Authorization"), "Bearer token")
        XCTAssertEqual(json.count, 1)
        let sheet = json.first ?? [:]
        XCTAssertEqual(JSONProbe.string(sheet, ["sheet_id", "sheetID"]), "sheet_123")
        XCTAssertEqual(
            JSONProbe.string(sheet, ["manifest_url", "manifestURL"]),
            "https://example.test/api/v1/test_sheets/sheet_123/manifest"
        )
        XCTAssertTrue(
            sheet["title"] == nil || sheet["title"] is NSNull,
            "A sheet without a display name must decode as a missing title"
        )
    }

    func testCaptureCreationPostsDocumentedMetadataAndQuality() async throws {
        var capturedRequest: URLRequest?
        var capturedBody: Data?
        StubURLProtocol.handler = { request in
            capturedRequest = request
            capturedBody = StubURLProtocol.body(of: request)
            return StubURLProtocol.Stub(statusCode: 201, json: #"{"capture_id":"cap_1"}"#)
        }

        let response = try await client().createCapture(
            sheetID: "sheet_123",
            baseURL: URL(string: "https://example.test")!,
            metadata: try decodeValue(from: APIFixtures.captureMetadata),
            quality: CaptureQuality(detectedMarkerCount: 4, blurScore: 0.75, rejections: [])
        )

        XCTAssertEqual(capturedRequest?.httpMethod, "POST")
        XCTAssertEqual(capturedRequest?.url?.path, "/api/v1/test_sheets/sheet_123/captures")
        XCTAssertEqual(capturedRequest?.value(forHTTPHeaderField: "Authorization"), "Bearer token")

        let body = try JSONProbe.object(data: try XCTUnwrap(capturedBody))
        let metadata = JSONProbe.object(body, ["metadata"])
        XCTAssertEqual(JSONProbe.string(metadata ?? [:], ["device_model", "deviceModel"]), "iPhone")
        XCTAssertEqual(JSONProbe.number(metadata ?? [:], ["image_width", "imageWidth"]), 4032)

        let quality = JSONProbe.object(body, ["quality"])
        XCTAssertEqual(
            JSONProbe.number(quality ?? [:], ["detected_marker_count", "detectedMarkerCount"]),
            4,
            "Capture quality must reach the server; the published spec does not describe it"
        )

        let responseJSON = try JSONProbe.object(response)
        XCTAssertEqual(JSONProbe.string(responseJSON, ["capture_id", "captureID"]), "cap_1")
    }

    func testMeasurementUploadSendsMeasurementsStatsAndPairScores() async throws {
        var capturedRequest: URLRequest?
        var capturedBody: Data?
        StubURLProtocol.handler = { request in
            capturedRequest = request
            capturedBody = StubURLProtocol.body(of: request)
            return StubURLProtocol.Stub(statusCode: 200, json: #"{"capture_id":"cap_1","measurement_count":1,"pair_score_count":1}"#)
        }

        let rgb = RGB(r: 0.2, g: 0.3, b: 0.4)
        let stats = ChannelStats(
            median: rgb,
            mean: rgb,
            standardDeviation: RGB(r: 0.01, g: 0.01, b: 0.01),
            min: rgb,
            max: rgb,
            sampleCount: 900,
            clippingFraction: 0
        )

        try await client().uploadMeasurements(
            captureID: "cap_1",
            baseURL: URL(string: "https://example.test")!,
            measurements: [
                PatchMeasurement(
                    patchID: "patch_1",
                    linearRGBMedian: rgb,
                    normalizedLinearRGBMedian: rgb,
                    stats: stats
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

        XCTAssertEqual(capturedRequest?.httpMethod, "POST")
        XCTAssertEqual(capturedRequest?.url?.path, "/api/v1/captures/cap_1/measurements")

        let body = try JSONProbe.object(data: try XCTUnwrap(capturedBody))
        let measurements = body["measurements"] as? [[String: Any]]
        XCTAssertEqual(measurements?.count, 1)
        XCTAssertEqual(JSONProbe.string(measurements?[0] ?? [:], ["patch_id", "patchID"]), "patch_1")

        let measurementStats = JSONProbe.object(measurements?[0] ?? [:], ["stats"])
        XCTAssertEqual(
            JSONProbe.number(measurementStats ?? [:], ["sample_count", "sampleCount"]),
            900,
            "Robustness statistics must be uploaded; the server stores them"
        )

        let pairScores = body["pair_scores"] as? [[String: Any]]
        XCTAssertEqual(pairScores?.count, 1)
        XCTAssertEqual(JSONProbe.string(pairScores?[0] ?? [:], ["pair_id", "pairID"]), "pair_1")
        XCTAssertEqual(
            JSONProbe.string(pairScores?[0] ?? [:], ["algorithm_version", "algorithmVersion"]),
            LPSScorer.algorithmVersion,
            "The upload must name the scoring algorithm version the server persists"
        )
    }

    func testJudgmentUploadPostsDocumentedPayload() async throws {
        var capturedRequest: URLRequest?
        var capturedBody: Data?
        StubURLProtocol.handler = { request in
            capturedRequest = request
            capturedBody = StubURLProtocol.body(of: request)
            return StubURLProtocol.Stub(statusCode: 200, json: #"{"capture_id":"cap_1","judgment_count":1}"#)
        }

        try await client().uploadJudgments(
            captureID: "cap_1",
            baseURL: URL(string: "https://example.test")!,
            judgments: try decodeAll(from: APIFixtures.judgments)
        )

        XCTAssertEqual(capturedRequest?.httpMethod, "POST")
        XCTAssertEqual(capturedRequest?.url?.path, "/api/v1/captures/cap_1/judgments")

        let body = try JSONProbe.object(data: try XCTUnwrap(capturedBody))
        let judgments = body["judgments"] as? [[String: Any]]
        XCTAssertEqual(judgments?.count, 1)
        XCTAssertEqual(JSONProbe.string(judgments?[0] ?? [:], ["pair_id", "pairID"]), "pair_1")
        XCTAssertEqual(JSONProbe.string(judgments?[0] ?? [:], ["judgment"]), "near_match")
    }

    func testServerErrorsFailTheCallInsteadOfReturningEmptyData() async throws {
        StubURLProtocol.handler = { request in
            StubURLProtocol.Stub(statusCode: 404, json: #"{"errors":{"detail":"Sheet not found"}}"#)
        }

        do {
            _ = try await client().fetchManifest(from: URL(string: "https://example.test/api/v1/test_sheets/missing/manifest")!)
            XCTFail("A 404 response must not decode into a manifest")
        } catch {
            // The client is expected to surface the server failure.
        }
    }

    private func client() -> APIClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return APIClient(token: "token", session: URLSession(configuration: configuration))
    }
}
