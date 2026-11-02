import ColorMatchingAPI
import Foundation
import MeasurementCore
import XCTest
@testable import ColorMatchingLPSAppCore

/// App-level contract for `APIClient` once it routes through the generated
/// OpenAPI client (`ColorMatchingAPI`) instead of hand-written Codable
/// request/response models.
///
/// The wire behavior asserted here follows the published OpenAPI spec
/// (`docs/color-matching-openapi-delta.md`): measurement and judgment uploads
/// answer 200 with a JSON body, capture creation answers 201 with
/// `capture_id`, and requests carry only spec-typed fields.
final class APIClientTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.handler = nil
        super.tearDown()
    }

    func testFetchManifestDecodesFullClientSideManifestModel() async throws {
        MockURLProtocol.handler = { _ in
            Self.httpResponse(200, Data(Self.fullManifestJSON.utf8))
        }

        let manifest = try await client().fetchManifest(
            from: URL(string: "https://example.test/api/v1/test_sheets/sheet_1/manifest")!
        )

        XCTAssertEqual(manifest.schemaVersion, "lps-sheet-manifest/v1")
        XCTAssertEqual(manifest.sheetID, "sheet_1")
        XCTAssertEqual(manifest.sheetVersion, "lps-letter-grid-v1")
        XCTAssertEqual(manifest.page.width, 215.9, accuracy: 0.0001)
        XCTAssertEqual(manifest.registrationMarkers.count, 1)
        // The Phoenix renderer identifies patches as "<pair_id>#<side>", not
        // the "patch_1" style shown in the old prose contract.
        XCTAssertEqual(manifest.patches.map(\.id), ["pair_1#first", "pair_1#second"])
        XCTAssertEqual(manifest.pairs.first?.firstPatchID, "pair_1#first")
        XCTAssertEqual(manifest.pairs.first?.sourceColors, ["#FF0000", "#00FF00"])
    }

    func testFetchRecentSheetsReturnsGeneratedSheetPayloads() async throws {
        var capturedRequest: URLRequest?
        MockURLProtocol.handler = { request in
            capturedRequest = request
            return Self.httpResponse(
                200,
                Data(
                    #"{"sheets":[{"sheet_id":"sheet_1","manifest_url":"/api/v1/test_sheets/sheet_1/manifest","title":null}]}"#
                        .utf8
                )
            )
        }

        let sheets = try await client().fetchRecentSheets(baseURL: URL(string: "https://example.test")!)

        XCTAssertEqual(capturedRequest?.url?.path, "/api/v1/test_sheets/recent")
        XCTAssertEqual(capturedRequest?.value(forHTTPHeaderField: "Authorization"), "Bearer token")
        XCTAssertEqual(sheets.map(\.sheetId), ["sheet_1"])
        XCTAssertEqual(sheets.first?.manifestUrl, "/api/v1/test_sheets/sheet_1/manifest")
        XCTAssertNil(sheets.first?.title)
    }

    func testCreateCaptureSendsGeneratedMetadataAndQualityAndReturnsCaptureID() async throws {
        var capturedRequest: URLRequest?
        var capturedBody: Data?
        MockURLProtocol.handler = { request in
            capturedRequest = request
            capturedBody = request.httpBodyStream.flatMap(Self.readBody) ?? request.httpBody
            return Self.httpResponse(201, Data(#"{"capture_id":"cap_1"}"#.utf8))
        }

        let created = try await client().createCapture(
            sheetID: "sheet_1",
            baseURL: URL(string: "https://example.test")!,
            metadata: .init(
                deviceModel: "iPhone 15",
                lens: "built_in_wide_angle",
                imageWidth: 4032,
                imageHeight: 3024,
                appVersion: "0.1.0",
                timestamp: Date(timeIntervalSince1970: 0)
            ),
            quality: CaptureQuality(detectedMarkerCount: 4, blurScore: 0.75, rejections: [])
        )

        XCTAssertEqual(created.captureId, "cap_1")
        XCTAssertEqual(capturedRequest?.httpMethod, "POST")
        XCTAssertEqual(capturedRequest?.url?.path, "/api/v1/test_sheets/sheet_1/captures")
        XCTAssertEqual(capturedRequest?.value(forHTTPHeaderField: "Authorization"), "Bearer token")

        let json = try XCTUnwrap(Self.jsonObject(from: capturedBody) as? [String: Any])
        let metadata = try XCTUnwrap(json["metadata"] as? [String: Any])
        XCTAssertEqual(metadata["device_model"] as? String, "iPhone 15")
        XCTAssertEqual(metadata["lens"] as? String, "built_in_wide_angle")
        XCTAssertEqual(metadata["image_width"] as? Int, 4032)
        XCTAssertEqual(metadata["image_height"] as? Int, 3024)
        XCTAssertNotNil(metadata["timestamp"] as? String)
        let quality = try XCTUnwrap(json["quality"] as? [String: Any])
        XCTAssertEqual(quality["detected_marker_count"] as? Int, 4)
        XCTAssertEqual(quality["rejections"] as? [String], [])
    }

    func testUploadMeasurementsSendsSpecTypedPayloadAndReturnsCounts() async throws {
        var capturedRequest: URLRequest?
        var capturedBody: Data?
        MockURLProtocol.handler = { request in
            capturedRequest = request
            capturedBody = request.httpBodyStream.flatMap(Self.readBody) ?? request.httpBody
            return Self.httpResponse(
                200,
                Data(#"{"capture_id":"cap_1","measurement_count":2,"pair_score_count":1}"#.utf8)
            )
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
        let uploaded = try await client().uploadMeasurements(
            captureID: "cap_1",
            baseURL: URL(string: "https://example.test")!,
            measurements: [
                PatchMeasurement(patchID: "pair_1#first", linearRGBMedian: rgb, normalizedLinearRGBMedian: rgb, stats: stats),
                PatchMeasurement(patchID: "pair_1#second", linearRGBMedian: rgb, normalizedLinearRGBMedian: rgb, stats: stats)
            ],
            scores: [PairScore(pairID: "pair_1", distance: 0.035, similarity: 0.965, algorithmVersion: LPSScorer.algorithmVersion)]
        )

        XCTAssertEqual(uploaded.captureId, "cap_1")
        XCTAssertEqual(uploaded.measurementCount, 2)
        XCTAssertEqual(uploaded.pairScoreCount, 1)
        XCTAssertEqual(capturedRequest?.url?.path, "/api/v1/captures/cap_1/measurements")

        let json = try XCTUnwrap(Self.jsonObject(from: capturedBody) as? [String: Any])
        XCTAssertFalse(
            json.keys.contains("scoring_algorithm_version"),
            "The published spec does not type a top-level scoring_algorithm_version; the generated client must not invent one"
        )
        let measurements = try XCTUnwrap(json["measurements"] as? [[String: Any]])
        XCTAssertEqual(measurements.count, 2)
        let measurement = try XCTUnwrap(measurements.first)
        XCTAssertEqual(measurement["patch_id"] as? String, "pair_1#first")
        XCTAssertEqual(measurement["linear_rgb_median"] as? [String: Double], ["r": 0.2, "g": 0.3, "b": 0.4])
        XCTAssertEqual(
            measurement["normalized_linear_rgb_median"] as? [String: Double],
            ["r": 0.2, "g": 0.3, "b": 0.4]
        )
        XCTAssertEqual(
            Set(measurement.keys),
            ["patch_id", "linear_rgb_median", "normalized_linear_rgb_median"],
            "Robustness stats are not typed in the published spec; their absence on the wire is the visible drift (documented gap)"
        )
        let pairScores = try XCTUnwrap(json["pair_scores"] as? [[String: Any]])
        let score = try XCTUnwrap(pairScores.first)
        XCTAssertEqual(score["pair_id"] as? String, "pair_1")
        XCTAssertEqual(score["algorithm_version"] as? String, "lps-distance-v1")
        XCTAssertEqual(score["similarity"] as? Double ?? -1, 0.965, accuracy: 0.0001)
        XCTAssertNil(score["distance"], "Generated PairScoreRequest sends exactly one of score/similarity/distance")
    }

    func testUploadJudgmentsReturnsGeneratedCount() async throws {
        var capturedBody: Data?
        MockURLProtocol.handler = { request in
            capturedBody = request.httpBodyStream.flatMap(Self.readBody) ?? request.httpBody
            return Self.httpResponse(200, Data(#"{"capture_id":"cap_1","judgment_count":1}"#.utf8))
        }

        let uploaded = try await client().uploadJudgments(
            captureID: "cap_1",
            baseURL: URL(string: "https://example.test")!,
            judgments: [.init(pairId: "pair_1", judgment: "near_match")]
        )

        XCTAssertEqual(uploaded.captureId, "cap_1")
        XCTAssertEqual(uploaded.judgmentCount, 1)

        let json = try XCTUnwrap(Self.jsonObject(from: capturedBody) as? [String: Any])
        let judgments = try XCTUnwrap(json["judgments"] as? [[String: Any]])
        XCTAssertEqual(judgments.first?["pair_id"] as? String, "pair_1")
        XCTAssertEqual(judgments.first?["judgment"] as? String, "near_match")
    }

    func testUnauthorizedResponsesSurfaceAsAPIErrors() async throws {
        MockURLProtocol.handler = { _ in
            Self.httpResponse(401, Data(#"{"errors":{"detail":"Unauthorized"}}"#.utf8))
        }

        do {
            _ = try await client().fetchRecentSheets(baseURL: URL(string: "https://example.test")!)
            XCTFail("Expected an error for a 401 response")
        } catch {
            XCTAssertTrue(error is APIError, "Expected APIError, got: \(error)")
        }
    }

    // MARK: - Helpers

    private func client() -> APIClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        return APIClient(token: "token", session: URLSession(configuration: configuration))
    }

    private static func httpResponse(_ statusCode: Int, _ data: Data) -> (HTTPURLResponse, Data) {
        (
            HTTPURLResponse(
                url: URL(string: "https://example.test")!,
                statusCode: statusCode,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!,
            data
        )
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
                data.append(buffer, count)
            } else {
                break
            }
        }
        return data
    }

    /// Mirrors the manifest payload the Phoenix `TestSheetJSON` renderer
    /// actually emits (patch IDs are `"<pair_id>#<side>"`).
    private static let fullManifestJSON = """
        {
          "schema_version": "lps-sheet-manifest/v1",
          "sheet_id": "sheet_1",
          "sheet_version": "lps-letter-grid-v1",
          "manifest_url": "/api/v1/test_sheets/sheet_1/manifest",
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
            },
            {
              "id": "pair_1#second",
              "role": "pair_color",
              "pair_id": "pair_1",
              "pair_side": "second",
              "reference_role": null,
              "source_color": "#00FF00",
              "safe_inset_mm": 1.5,
              "rect": {"x": 32, "y": 38, "width": 16, "height": 10}
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
        """
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
