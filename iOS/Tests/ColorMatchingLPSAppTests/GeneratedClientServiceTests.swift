import Foundation
import MeasurementCore
import XCTest
import ColorMatchingOpenAPIClient
@testable import ColorMatchingLPSAppCore

final class GeneratedClientServiceTests: XCTestCase {
    override func tearDown() {
        StubURLProtocol.handler = nil
        super.tearDown()
    }

    func testFetchManifestDecodesServerManifestAndSendsBearerToken() async throws {
        let service = makeService()
        stub(status: 200, body: Self.serverManifestJSON)

        let manifest = try await service.fetchManifest(sheetID: "sheet_123")

        XCTAssertEqual(manifest.sheet_id, "sheet_123")
        XCTAssertEqual(manifest.schema_version, "lps-sheet-manifest/v1")
        XCTAssertEqual(manifest.patches.count, 2)
        XCTAssertEqual(manifest.pairs.count, 1)
        XCTAssertEqual(manifest.patches.first?.id, "pair_1#first")
        XCTAssertEqual(StubURLProtocol.lastRequest?.url?.path, "/api/v1/test_sheets/sheet_123/manifest")
        XCTAssertEqual(StubURLProtocol.lastRequest?.value(forHTTPHeaderField: "Authorization"), "Bearer token")
    }

    func testFetchRecentSheetsDecodesNullableTitle() async throws {
        let service = makeService()
        stub(status: 200, body: #"{"sheets": [{"sheet_id": "sheet_123", "manifest_url": "https://example.test/api/v1/test_sheets/sheet_123/manifest", "title": null}]}"#)

        let recent = try await service.fetchRecentSheets()

        XCTAssertEqual(recent.sheets.count, 1)
        XCTAssertEqual(recent.sheets.first?.sheet_id, "sheet_123")
        XCTAssertNil(recent.sheets.first?.title)
        XCTAssertEqual(StubURLProtocol.lastRequest?.url?.path, "/api/v1/test_sheets/recent")
    }

    func testCreateCapturePostsNestedMetadataAndQuality() async throws {
        let service = makeService()
        stub(status: 201, body: #"{"capture_id": "42"}"#)

        let response = try await service.createCapture(
            sheetID: "sheet_123",
            metadata: CaptureMetadata(
                deviceModel: "iPhone 16 Pro",
                lens: "built_in_wide_angle",
                exposureDurationSeconds: 0.016,
                iso: 100,
                focusLensPosition: 0.42,
                whiteBalanceGains: WhiteBalanceGains(red: 1.2, green: 1.0, blue: 1.4),
                imageWidth: 4032,
                imageHeight: 3024,
                appVersion: "0.1.0",
                timestamp: Date(timeIntervalSince1970: 0)
            ),
            quality: CaptureQuality(detectedMarkerCount: 4, blurScore: 0.82, rejections: [])
        )

        XCTAssertEqual(response.capture_id, "42")
        let request = try XCTUnwrap(StubURLProtocol.lastRequest)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.path, "/api/v1/test_sheets/sheet_123/captures")
        let body = try Self.jsonBody()
        let metadata = try XCTUnwrap(body["metadata"] as? [String: Any])
        XCTAssertEqual(metadata["device_model"] as? String, "iPhone 16 Pro")
        XCTAssertEqual(metadata["exposure_duration_seconds"] as? Double, 0.016)
        XCTAssertEqual(metadata["image_width"] as? Int, 4032)
        let quality = try XCTUnwrap(body["quality"] as? [String: Any])
        XCTAssertEqual(quality["detected_marker_count"] as? Int, 4)
        XCTAssertEqual(quality["rejections"] as? [String], [])
    }

    func testUploadMeasurementsEncodesSpecShapedPayloadAndDecodesCounts() async throws {
        let service = makeService()
        stub(status: 200, body: #"{"capture_id": "42", "measurement_count": 2, "pair_score_count": 1}"#)

        let response = try await service.uploadMeasurements(
            captureID: "42",
            measurements: [
                Self.measurement(patchID: "pair_1#first", normalized: RGB(r: 0.15, g: 0.12, b: 0.02)),
                Self.measurement(patchID: "pair_1#second", normalized: nil)
            ],
            scores: [PairScore(pairID: "pair_1", distance: 0.035, similarity: 0.965, algorithmVersion: LPSScorer.algorithmVersion)]
        )

        XCTAssertEqual(response.measurement_count, 2)
        XCTAssertEqual(response.pair_score_count, 1)
        XCTAssertEqual(StubURLProtocol.lastRequest?.url?.path, "/api/v1/captures/42/measurements")

        let body = try Self.jsonBody()
        XCTAssertNil(body["scoring_algorithm_version"], "the published spec carries algorithm_version per pair score, not top level")

        let measurements = try XCTUnwrap(body["measurements"] as? [[String: Any]])
        XCTAssertEqual(measurements.count, 2)
        let first = try XCTUnwrap(measurements.first)
        XCTAssertEqual(first["patch_id"] as? String, "pair_1#first")
        let medianPayload = try XCTUnwrap(first["linear_rgb_median"] as? [String: Any])
        XCTAssertEqual(Set(medianPayload.keys), ["r", "g", "b"])
        XCTAssertEqual((first["normalized_linear_rgb_median"] as? [String: Any])?["r"] as? Double, 0.15)
        let stats = try XCTUnwrap(first["stats"] as? [String: Any])
        XCTAssertEqual(Set(stats.keys), ["sample_count", "clipping_fraction", "mean", "standard_deviation"])
        XCTAssertEqual(stats["sample_count"] as? Int, 900)

        let second = try XCTUnwrap(measurements.last)
        XCTAssertNil(second["normalized_linear_rgb_median"], "normalized medians are optional per actual server behavior")

        let score = try XCTUnwrap((body["pair_scores"] as? [[String: Any]])?.first)
        XCTAssertEqual(score["pair_id"] as? String, "pair_1")
        XCTAssertEqual(score["algorithm_version"] as? String, "lps-distance-v1")
        XCTAssertEqual(score["similarity"] as? Double, 0.965)
    }

    func testUploadJudgmentsEncodesPairsAndDecodesCount() async throws {
        let service = makeService()
        stub(status: 200, body: #"{"capture_id": "42", "judgment_count": 1}"#)

        let response = try await service.uploadJudgments(
            captureID: "42",
            judgments: [PairJudgment(pairID: "pair_1", judgment: "near_match")]
        )

        XCTAssertEqual(response.judgment_count, 1)
        XCTAssertEqual(StubURLProtocol.lastRequest?.url?.path, "/api/v1/captures/42/judgments")
        let body = try Self.jsonBody()
        let judgment = try XCTUnwrap((body["judgments"] as? [[String: Any]])?.first)
        XCTAssertEqual(judgment["pair_id"] as? String, "pair_1")
        XCTAssertEqual(judgment["judgment"] as? String, "near_match")
    }

    func testFetchRankedResultsDecodesResultsEnvelope() async throws {
        let service = makeService()
        stub(status: 200, body: Self.rankedResultsJSON)

        let results = try await service.fetchRankedResults(sheetID: "sheet_123")

        XCTAssertEqual(results.schema_version, "lps-ranked-results/v1")
        XCTAssertEqual(results.sheet_id, "sheet_123")
        XCTAssertEqual(results.results.count, 1)
        XCTAssertEqual(results.results.first?.pair_id, "pair_1")
        XCTAssertEqual(results.results.first?.rank, 1)
    }

    func testFetchManifestMapsDocumentedNotFoundToSheetNotFound() async throws {
        let service = makeService()
        stub(status: 404, body: #"{"errors": {"detail": "Sheet not found"}}"#)

        do {
            _ = try await service.fetchManifest(sheetID: "missing")
            XCTFail("expected sheetNotFound")
        } catch {
            XCTAssertEqual(error as? ColorMatchingServiceError, .sheetNotFound)
        }
    }

    private func makeService() -> ColorMatchingService {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return ColorMatchingService(
            serverURL: URL(string: "https://example.test")!,
            token: "token",
            session: URLSession(configuration: configuration)
        )
    }

    private func stub(status: Int, body: String) {
        StubURLProtocol.handler = StubURLProtocol.respond(status: status, body: body)
    }

    private static func jsonBody() throws -> [String: Any] {
        let data = try XCTUnwrap(StubURLProtocol.lastBody)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private static func measurement(patchID: String, normalized: RGB?) -> PatchMeasurement {
        let median = RGB(r: 0.12, g: 0.10, b: 0.02)
        return PatchMeasurement(
            patchID: patchID,
            linearRGBMedian: median,
            normalizedLinearRGBMedian: normalized,
            stats: ChannelStats(
                median: median,
                mean: median,
                standardDeviation: RGB(r: 0.01, g: 0.01, b: 0.01),
                min: median,
                max: median,
                sampleCount: 900,
                clippingFraction: 0
            )
        )
    }

    private static let serverManifestJSON = """
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
        "printer_make_model": "Research printer",
        "paper_type": "Paper name",
        "ink_type": "Ink set",
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
        {"id": "pair_1#first", "role": "pair_color", "pair_id": "pair_1", "pair_side": "first", "reference_role": null, "source_color": "#FF0000", "safe_inset_mm": 1.5, "rect": {"x": 16, "y": 38, "width": 16, "height": 10}},
        {"id": "pair_1#second", "role": "pair_color", "pair_id": "pair_1", "pair_side": "second", "reference_role": null, "source_color": "#00FF00", "safe_inset_mm": 1.5, "rect": {"x": 36, "y": 38, "width": 16, "height": 10}}
      ],
      "pairs": [
        {"id": "pair_1", "first_patch_id": "pair_1#first", "second_patch_id": "pair_1#second", "source_colors": ["#FF0000", "#00FF00"], "grid_row": 0, "grid_col": 1}
      ]
    }
    """

    private static let rankedResultsJSON = """
    {
      "schema_version": "lps-ranked-results/v1",
      "sheet_id": "sheet_123",
      "printer_profile": {
        "printer_make_model": "Research printer",
        "paper_type": "Paper name",
        "ink_type": "Ink set",
        "icc_profile": null,
        "print_settings": null,
        "driver_name": null,
        "driver_version": null,
        "calibration_date": null,
        "calibration_version": null,
        "notes": null
      },
      "capture_count": 2,
      "latest_capture_at": "2026-07-25T12:30:00Z",
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
            "latest": 0.04,
            "minimum": 0.03,
            "maximum": 0.04,
            "capture_count": 2,
            "sample_count": 2,
            "algorithm_versions": ["lps-distance-v1"]
          },
          "current_judgment": "near_match",
          "current_judgment_observed_at": "2026-07-25T12:31:00Z",
          "observation_count": 1,
          "latest_observation": {"judgment": "near_match", "observed_at": "2026-07-25T12:31:00Z"},
          "capture_count": 2,
          "latest_capture_at": "2026-07-25T12:30:00Z",
          "earliest_capture_at": "2026-07-25T12:00:00Z"
        }
      ]
    }
    """
}

private final class StubURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?
    private(set) static var lastRequest: URLRequest?
    private(set) static var lastBody: Data?

    static func respond(status: Int, body: String) -> (URLRequest) throws -> (HTTPURLResponse, Data) {
        let data = Data(body.utf8)
        return { request in
            self.lastRequest = request
            self.lastBody = request.httpBodyStream.flatMap(Self.read) ?? request.httpBody
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: status,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, data)
        }
    }

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

    private static func read(_ stream: InputStream) -> Data {
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
