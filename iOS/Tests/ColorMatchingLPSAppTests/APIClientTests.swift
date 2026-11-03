import Foundation
import XCTest
@testable import ColorMatchingLPSAppCore

#if canImport(ColorMatchingOpenAPI)
import ColorMatchingOpenAPI

/// The generated component schemas of the vendored OpenAPI document.
typealias GeneratedSchemas = ColorMatchingOpenAPI.Components.Schemas
#endif

/// Exercises the app's API layer against stubbed HTTP responses.
///
/// The API layer is expected to be built on the generated OpenAPI client, so
/// every request and response shape asserted here is the shape produced by
/// `swift-openapi-generator` from the vendored OpenAPI document. No live
/// `color_matching` server is involved.
final class APIClientTests: XCTestCase {
    override func tearDown() {
        StubURLProtocol.reset()
        super.tearDown()
    }

    // MARK: - Sheet manifest

    #if canImport(ColorMatchingOpenAPI)

    func testFetchManifestRequestsTheManifestPathAndDecodesTheGeneratedSchema() async throws {
        StubURLProtocol.setHandler { request in
            (
                HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                Data(Self.manifestJSON.utf8)
            )
        }

        let manifest = try await APIClient(token: "token", session: Self.session()).fetchManifest(
            baseURL: URL(string: "https://example.test")!,
            sheetCode: "sheet_123"
        )

        let recorded = try XCTUnwrap(StubURLProtocol.recordedRequests.first)
        XCTAssertEqual(recorded.request.httpMethod, "GET")
        let path = try XCTUnwrap(recorded.request.url?.path)
        XCTAssertEqual(path, "/api/v1/test_sheets/sheet_123/manifest")
        let authorization = try XCTUnwrap(recorded.request.value(forHTTPHeaderField: "Authorization"))
        XCTAssertEqual(authorization, "Bearer token")

        let json = try StubJSON.reencoded(from: manifest)
        let schemaVersion = try XCTUnwrap(json["schema_version"] as? String)
        XCTAssertEqual(schemaVersion, "lps-sheet-manifest/v1")
        let sheetID = try XCTUnwrap(json["sheet_id"] as? String)
        XCTAssertEqual(sheetID, "sheet_123")

        // The published manifest schema only declares three fields, but the app
        // cannot measure a sheet without the patch and pair geometry.
        let patches = try XCTUnwrap(json["patches"] as? [[String: Any]])
        XCTAssertEqual(patches.count, 2)
        let pairs = try XCTUnwrap(json["pairs"] as? [[String: Any]])
        XCTAssertEqual(pairs.count, 1)

        XCTAssertTrue(Self.isGeneratedType(manifest))
    }

    func testFetchManifestFromAnAbsoluteURLUsesTheManifestPath() async throws {
        StubURLProtocol.setHandler { request in
            (
                HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                Data(Self.manifestJSON.utf8)
            )
        }

        let manifestURL = URL(string: "https://example.test/api/v1/test_sheets/sheet_123/manifest")!
        let manifest = try await APIClient(token: "token", session: Self.session()).fetchManifest(from: manifestURL)

        let recorded = try XCTUnwrap(StubURLProtocol.recordedRequests.first)
        XCTAssertEqual(recorded.request.httpMethod, "GET")
        let path = try XCTUnwrap(recorded.request.url?.path)
        XCTAssertEqual(path, "/api/v1/test_sheets/sheet_123/manifest")
        let host = try XCTUnwrap(recorded.request.url?.host)
        XCTAssertEqual(host, "example.test")

        let json = try StubJSON.reencoded(from: manifest)
        let sheetID = try XCTUnwrap(json["sheet_id"] as? String)
        XCTAssertEqual(sheetID, "sheet_123")
    }

    // MARK: - Recent sheets

    func testFetchRecentSheetsDecodesTheGeneratedResponse() async throws {
        StubURLProtocol.setHandler { request in
            (
                HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                Data(Self.recentSheetsJSON.utf8)
            )
        }

        let recent = try await APIClient(token: "token", session: Self.session()).fetchRecentSheets(
            baseURL: URL(string: "https://example.test")!
        )

        let recorded = try XCTUnwrap(StubURLProtocol.recordedRequests.first)
        XCTAssertEqual(recorded.request.httpMethod, "GET")
        let path = try XCTUnwrap(recorded.request.url?.path)
        XCTAssertEqual(path, "/api/v1/test_sheets/recent")
        let authorization = try XCTUnwrap(recorded.request.value(forHTTPHeaderField: "Authorization"))
        XCTAssertEqual(authorization, "Bearer token")

        let json = try StubJSON.reencoded(from: recent)
        let sheets = try XCTUnwrap(json["sheets"] as? [[String: Any]])
        XCTAssertEqual(sheets.count, 1)
        let sheetID = try XCTUnwrap(sheets.first?["sheet_id"] as? String)
        XCTAssertEqual(sheetID, "sheet_123")
        let manifestURL = try XCTUnwrap(sheets.first?["manifest_url"] as? String)
        XCTAssertEqual(manifestURL, "https://example.test/api/v1/test_sheets/sheet_123/manifest")

        XCTAssertTrue(Self.isGeneratedType(recent))
    }

    // MARK: - Capture session

    func testCreateCaptureSendsMetadataAndQualityAndDecodesTheGeneratedResponse() async throws {
        StubURLProtocol.setHandler { request in
            (
                HTTPURLResponse(url: request.url!, statusCode: 201, httpVersion: nil, headerFields: nil)!,
                Data(#"{"capture_id":"capture_123"}"#.utf8)
            )
        }

        let request = try StubJSON.decoded(GeneratedSchemas.CaptureRequest.self, fromJSON: Self.captureRequestJSON)
        let response = try await APIClient(token: "token", session: Self.session()).createCapture(
            sheetID: "sheet_123",
            baseURL: URL(string: "https://example.test")!,
            request: request
        )

        let recorded = try XCTUnwrap(StubURLProtocol.recordedRequests.first)
        XCTAssertEqual(recorded.request.httpMethod, "POST")
        let path = try XCTUnwrap(recorded.request.url?.path)
        XCTAssertEqual(path, "/api/v1/test_sheets/sheet_123/captures")
        let contentType = try XCTUnwrap(recorded.request.value(forHTTPHeaderField: "Content-Type"))
        XCTAssertEqual(contentType, "application/json")
        let authorization = try XCTUnwrap(recorded.request.value(forHTTPHeaderField: "Authorization"))
        XCTAssertEqual(authorization, "Bearer token")

        let body = try StubJSON.parsed(from: recorded.body)
        let metadata = try XCTUnwrap(body["metadata"] as? [String: Any])
        let deviceModel = try XCTUnwrap(metadata["device_model"] as? String)
        XCTAssertEqual(deviceModel, "iPhone")
        let lens = try XCTUnwrap(metadata["lens"] as? String)
        XCTAssertEqual(lens, "built_in_wide_angle")
        let imageWidth = try XCTUnwrap(metadata["image_width"] as? Int)
        XCTAssertEqual(imageWidth, 4032)
        let imageHeight = try XCTUnwrap(metadata["image_height"] as? Int)
        XCTAssertEqual(imageHeight, 3024)
        let appVersion = try XCTUnwrap(metadata["app_version"] as? String)
        XCTAssertEqual(appVersion, "0.1.0")
        let timestamp = try XCTUnwrap(metadata["timestamp"] as? String)
        XCTAssertEqual(timestamp, "2026-07-25T12:00:00Z")

        let quality = try XCTUnwrap(body["quality"] as? [String: Any])
        let markerCount = try XCTUnwrap(quality["detected_marker_count"] as? Int)
        XCTAssertEqual(markerCount, 4)
        let blurScore = try XCTUnwrap(quality["blur_score"] as? Double)
        XCTAssertEqual(blurScore, 0.82)
        let rejections = try XCTUnwrap(quality["rejections"] as? [String])
        XCTAssertEqual(rejections.count, 0)

        let json = try StubJSON.reencoded(from: response)
        let captureID = try XCTUnwrap(json["capture_id"] as? String)
        XCTAssertEqual(captureID, "capture_123")

        XCTAssertTrue(Self.isGeneratedType(response))
    }

    func testCreateCaptureKeepsTheWhiteBalanceGainsOfTheCapture() async throws {
        StubURLProtocol.setHandler { request in
            (
                HTTPURLResponse(url: request.url!, statusCode: 201, httpVersion: nil, headerFields: nil)!,
                Data(#"{"capture_id":"capture_123"}"#.utf8)
            )
        }

        let request = try StubJSON.decoded(
            GeneratedSchemas.CaptureRequest.self,
            fromJSON: Self.captureRequestWithGainsJSON
        )
        _ = try await APIClient(token: "token", session: Self.session()).createCapture(
            sheetID: "sheet_123",
            baseURL: URL(string: "https://example.test")!,
            request: request
        )

        let recorded = try XCTUnwrap(StubURLProtocol.recordedRequests.first)
        let body = try StubJSON.parsed(from: recorded.body)
        let metadata = try XCTUnwrap(body["metadata"] as? [String: Any])
        let gains = try XCTUnwrap(metadata["white_balance_gains"] as? [String: Any])
        let red = try XCTUnwrap(gains["red"] as? Double)
        XCTAssertEqual(red, 1.2)
        let green = try XCTUnwrap(gains["green"] as? Double)
        XCTAssertEqual(green, 1.0)
        let blue = try XCTUnwrap(gains["blue"] as? Double)
        XCTAssertEqual(blue, 1.4)
    }

    // MARK: - Measurements

    func testUploadMeasurementsSendsMeasurementsWithStatsAndPairScores() async throws {
        StubURLProtocol.setHandler { request in
            (
                HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                Data(#"{"capture_id":"capture_123","measurement_count":1,"pair_score_count":1}"#.utf8)
            )
        }

        let request = try StubJSON.decoded(
            GeneratedSchemas.MeasurementUploadRequest.self,
            fromJSON: Self.measurementRequestJSON
        )
        let response = try await APIClient(token: "token", session: Self.session()).uploadMeasurements(
            captureID: "capture_123",
            baseURL: URL(string: "https://example.test")!,
            request: request
        )

        let recorded = try XCTUnwrap(StubURLProtocol.recordedRequests.first)
        XCTAssertEqual(recorded.request.httpMethod, "POST")
        let path = try XCTUnwrap(recorded.request.url?.path)
        XCTAssertEqual(path, "/api/v1/captures/capture_123/measurements")
        let contentType = try XCTUnwrap(recorded.request.value(forHTTPHeaderField: "Content-Type"))
        XCTAssertEqual(contentType, "application/json")

        let body = try StubJSON.parsed(from: recorded.body)
        let measurements = try XCTUnwrap(body["measurements"] as? [[String: Any]])
        XCTAssertEqual(measurements.count, 1)
        let measurement = try XCTUnwrap(measurements.first)
        let patchID = try XCTUnwrap(measurement["patch_id"] as? String)
        XCTAssertEqual(patchID, "patch_1")

        let median = try XCTUnwrap(measurement["linear_rgb_median"] as? [String: Any])
        let red = try XCTUnwrap(median["r"] as? Double)
        XCTAssertEqual(red, 0.12)
        let green = try XCTUnwrap(median["g"] as? Double)
        XCTAssertEqual(green, 0.10)
        let blue = try XCTUnwrap(median["b"] as? Double)
        XCTAssertEqual(blue, 0.02)

        let normalized = try XCTUnwrap(measurement["normalized_linear_rgb_median"] as? [String: Any])
        let normalizedRed = try XCTUnwrap(normalized["r"] as? Double)
        XCTAssertEqual(normalizedRed, 0.15)

        // The upstream server rejects a measurement without robustness stats.
        let stats = try XCTUnwrap(measurement["stats"] as? [String: Any])
        let sampleCount = try XCTUnwrap(stats["sample_count"] as? Int)
        XCTAssertEqual(sampleCount, 900)
        let clippingFraction = try XCTUnwrap(stats["clipping_fraction"] as? Double)
        XCTAssertEqual(clippingFraction, 0.0)
        XCTAssertNotNil(stats["mean"])
        XCTAssertNotNil(stats["standard_deviation"])

        let pairScores = try XCTUnwrap(body["pair_scores"] as? [[String: Any]])
        XCTAssertEqual(pairScores.count, 1)
        let pairID = try XCTUnwrap(pairScores.first?["pair_id"] as? String)
        XCTAssertEqual(pairID, "pair_1")
        let algorithmVersion = try XCTUnwrap(pairScores.first?["algorithm_version"] as? String)
        XCTAssertEqual(algorithmVersion, "lps-distance-v1")

        let json = try StubJSON.reencoded(from: response)
        let captureID = try XCTUnwrap(json["capture_id"] as? String)
        XCTAssertEqual(captureID, "capture_123")
        let measurementCount = try XCTUnwrap(json["measurement_count"] as? Int)
        XCTAssertEqual(measurementCount, 1)
        let pairScoreCount = try XCTUnwrap(json["pair_score_count"] as? Int)
        XCTAssertEqual(pairScoreCount, 1)

        XCTAssertTrue(Self.isGeneratedType(response))
    }

    // MARK: - Judgments

    func testUploadJudgmentsSendsJudgmentsAndDecodesTheGeneratedResponse() async throws {
        StubURLProtocol.setHandler { request in
            (
                HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                Data(#"{"capture_id":"capture_123","judgment_count":1}"#.utf8)
            )
        }

        let request = try StubJSON.decoded(
            GeneratedSchemas.JudgmentUploadRequest.self,
            fromJSON: Self.judgmentRequestJSON
        )
        let response = try await APIClient(token: "token", session: Self.session()).uploadJudgments(
            captureID: "capture_123",
            baseURL: URL(string: "https://example.test")!,
            request: request
        )

        let recorded = try XCTUnwrap(StubURLProtocol.recordedRequests.first)
        XCTAssertEqual(recorded.request.httpMethod, "POST")
        let path = try XCTUnwrap(recorded.request.url?.path)
        XCTAssertEqual(path, "/api/v1/captures/capture_123/judgments")
        let contentType = try XCTUnwrap(recorded.request.value(forHTTPHeaderField: "Content-Type"))
        XCTAssertEqual(contentType, "application/json")

        let body = try StubJSON.parsed(from: recorded.body)
        let judgments = try XCTUnwrap(body["judgments"] as? [[String: Any]])
        XCTAssertEqual(judgments.count, 1)
        let pairID = try XCTUnwrap(judgments.first?["pair_id"] as? String)
        XCTAssertEqual(pairID, "pair_1")
        let judgment = try XCTUnwrap(judgments.first?["judgment"] as? String)
        XCTAssertEqual(judgment, "near_match")

        let json = try StubJSON.reencoded(from: response)
        let captureID = try XCTUnwrap(json["capture_id"] as? String)
        XCTAssertEqual(captureID, "capture_123")
        let judgmentCount = try XCTUnwrap(json["judgment_count"] as? Int)
        XCTAssertEqual(judgmentCount, 1)

        XCTAssertTrue(Self.isGeneratedType(response))
    }

    // MARK: - Ranked results

    func testFetchRankedResultsDecodesTheGeneratedResponse() async throws {
        StubURLProtocol.setHandler { request in
            (
                HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                Data(Self.rankedResultsJSON.utf8)
            )
        }

        let ranked = try await APIClient(token: "token", session: Self.session()).fetchRankedResults(
            sheetID: "sheet_123",
            baseURL: URL(string: "https://example.test")!
        )

        let recorded = try XCTUnwrap(StubURLProtocol.recordedRequests.first)
        XCTAssertEqual(recorded.request.httpMethod, "GET")
        let path = try XCTUnwrap(recorded.request.url?.path)
        XCTAssertEqual(path, "/api/v1/test_sheets/sheet_123/ranked_results")
        let authorization = try XCTUnwrap(recorded.request.value(forHTTPHeaderField: "Authorization"))
        XCTAssertEqual(authorization, "Bearer token")

        let json = try StubJSON.reencoded(from: ranked)
        let schemaVersion = try XCTUnwrap(json["schema_version"] as? String)
        XCTAssertEqual(schemaVersion, "lps-ranked-results/v1")
        let sheetID = try XCTUnwrap(json["sheet_id"] as? String)
        XCTAssertEqual(sheetID, "sheet_123")

        XCTAssertTrue(Self.isGeneratedType(ranked))
    }

    // MARK: - Failures

    func testAnUnknownSheetIsReportedAsAnError() async throws {
        StubURLProtocol.setHandler { request in
            (
                HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!,
                Data(#"{"errors":{"detail":"Sheet not found"}}"#.utf8)
            )
        }

        do {
            _ = try await APIClient(token: "token", session: Self.session()).fetchManifest(
                baseURL: URL(string: "https://example.test")!,
                sheetCode: "missing"
            )
            XCTFail("expected the failed manifest request to throw")
        } catch {
            XCTAssertEqual(StubURLProtocol.recordedRequests.count, 1)
        }
    }

    func testAnUnauthorizedRequestIsReportedAsAnError() async throws {
        StubURLProtocol.setHandler { request in
            (
                HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!,
                Data(#"{"errors":{"detail":"Unauthorized"}}"#.utf8)
            )
        }

        do {
            _ = try await APIClient(token: "token", session: Self.session()).fetchRecentSheets(
                baseURL: URL(string: "https://example.test")!
            )
            XCTFail("expected the unauthorized request to throw")
        } catch {
            XCTAssertEqual(StubURLProtocol.recordedRequests.count, 1)
        }
    }

    #else

    func testTheGeneratedOpenAPIClientIsAvailable() {
        XCTFail("""
        The generated OpenAPI client is missing. Add a `ColorMatchingOpenAPI` target that \
        runs the `OpenAPIGenerator` plugin over a vendored `openapi.json`, and make \
        `ColorMatchingLPSAppCore` and `ColorMatchingLPSAppTests` depend on it.
        """)
    }

    #endif

    // MARK: - Helpers

    private static func session() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    /// True when `value` is one of the generated OpenAPI types.
    ///
    /// The check is on the module rather than on a concrete type name: the
    /// Swift type names of the generated code depend on the generator's naming
    /// strategy, the module does not.
    private static func isGeneratedType(_ value: Any) -> Bool {
        String(describing: type(of: value)).hasPrefix("ColorMatchingOpenAPI.")
    }

    // MARK: - Fixtures

    private static let manifestJSON = ##"""
    {
      "schema_version": "lps-sheet-manifest/v1",
      "sheet_id": "sheet_123",
      "sheet_version": "lps-letter-grid-v1",
      "manifest_url": "https://example.test/api/v1/test_sheets/sheet_123/manifest",
      "created_at": "2026-07-25T12:00:00Z",
      "page": {"units": "mm", "width": 215.9, "height": 279.4},
      "registration_markers": [
        {"role": "top_left", "shape": "solid_square", "rect": {"x": 12, "y": 12, "width": 8, "height": 8}},
        {"role": "top_right", "shape": "solid_square", "rect": {"x": 195.9, "y": 12, "width": 8, "height": 8}}
      ],
      "printer_profile": {
        "printer_make_model": "Research printer",
        "paper_type": "paper name",
        "ink_type": "ink set",
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
          "rect": {"x": 34, "y": 38, "width": 16, "height": 10}
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
    """##

    private static let recentSheetsJSON = ##"""
    {
      "sheets": [
        {
          "sheet_id": "sheet_123",
          "manifest_url": "https://example.test/api/v1/test_sheets/sheet_123/manifest",
          "title": null
        }
      ]
    }
    """##

    private static let captureRequestJSON = ##"""
    {
      "metadata": {
        "device_model": "iPhone",
        "lens": "built_in_wide_angle",
        "exposure_duration_seconds": 0.016,
        "iso": 100,
        "focus_lens_position": 0.42,
        "image_width": 4032,
        "image_height": 3024,
        "app_version": "0.1.0",
        "timestamp": "2026-07-25T12:00:00Z"
      },
      "quality": {
        "detected_marker_count": 4,
        "blur_score": 0.82,
        "rejections": []
      }
    }
    """##

    private static let captureRequestWithGainsJSON = ##"""
    {
      "metadata": {
        "device_model": "iPhone",
        "lens": "built_in_wide_angle",
        "exposure_duration_seconds": 0.016,
        "iso": 100,
        "focus_lens_position": 0.42,
        "white_balance_gains": {"red": 1.2, "green": 1.0, "blue": 1.4},
        "image_width": 4032,
        "image_height": 3024,
        "app_version": "0.1.0",
        "timestamp": "2026-07-25T12:00:00Z"
      },
      "quality": {
        "detected_marker_count": 4,
        "blur_score": 0.82,
        "rejections": []
      }
    }
    """##

    private static let measurementRequestJSON = ##"""
    {
      "measurements": [
        {
          "patch_id": "patch_1",
          "linear_rgb_median": {"r": 0.12, "g": 0.10, "b": 0.02},
          "normalized_linear_rgb_median": {"r": 0.15, "g": 0.12, "b": 0.02},
          "stats": {
            "sample_count": 900,
            "clipping_fraction": 0.0,
            "mean": {"r": 0.12, "g": 0.10, "b": 0.02},
            "standard_deviation": {"r": 0.01, "g": 0.01, "b": 0.004}
          }
        }
      ],
      "pair_scores": [
        {
          "pair_id": "pair_1",
          "distance": 0.035,
          "similarity": 0.965,
          "algorithm_version": "lps-distance-v1"
        }
      ]
    }
    """##

    private static let judgmentRequestJSON = ##"""
    {
      "judgments": [
        {"pair_id": "pair_1", "judgment": "near_match"}
      ]
    }
    """##

    private static let rankedResultsJSON = ##"""
    {
      "schema_version": "lps-ranked-results/v1",
      "sheet_id": "sheet_123",
      "printer_profile": {
        "printer_make_model": "Research printer",
        "paper_type": "paper name",
        "ink_type": "ink set"
      },
      "capture_count": 2,
      "latest_capture_at": "2026-07-25T12:00:00Z",
      "earliest_capture_at": "2026-07-25T11:00:00Z",
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
            "average": 0.965,
            "latest": 0.965,
            "minimum": 0.964,
            "maximum": 0.966,
            "capture_count": 2,
            "sample_count": 2,
            "algorithm_versions": ["lps-distance-v1"]
          },
          "current_judgment": null,
          "current_judgment_observed_at": null,
          "observation_count": 0,
          "latest_observation": null,
          "capture_count": 2,
          "latest_capture_at": "2026-07-25T12:00:00Z",
          "earliest_capture_at": "2026-07-25T11:00:00Z"
        }
      ]
    }
    """##
}

/// A `URLProtocol` that answers every request with a canned response and
/// records what the app's API layer actually put on the wire.
///
/// The generated OpenAPI client talks to the network through `URLSession`, so
/// stubbing at this level keeps the tests hermetic: no live `color_matching`
/// server is needed in CI.
private final class StubURLProtocol: URLProtocol {
    typealias Handler = (URLRequest) throws -> (HTTPURLResponse, Data)

    /// A request as the stub saw it, with the body already drained.
    struct RecordedRequest {
        let request: URLRequest
        let body: Data?
    }

    private static let lock = NSLock()
    private static var handler: Handler?
    private static var recorded: [RecordedRequest] = []

    /// Installs `responseHandler` as the reply to every subsequent request and
    /// discards anything recorded so far.
    static func setHandler(_ responseHandler: @escaping Handler) {
        lock.lock()
        defer { lock.unlock() }
        handler = responseHandler
        recorded = []
    }

    /// Removes the installed handler and the recorded requests.
    static func reset() {
        lock.lock()
        defer { lock.unlock() }
        handler = nil
        recorded = []
    }

    /// The requests the stub has answered so far, oldest first.
    static var recordedRequests: [RecordedRequest] {
        lock.lock()
        defer { lock.unlock() }
        return recorded
    }

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        let body = Self.drainBody(of: request)
        do {
            let handler = try XCTUnwrap(Self.currentHandler)
            let (response, data) = try handler(request)
            Self.record(request, body: body)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}

    private static var currentHandler: Handler? {
        lock.lock()
        defer { lock.unlock() }
        return handler
    }

    private static func record(_ request: URLRequest, body: Data?) {
        lock.lock()
        defer { lock.unlock() }
        recorded.append(RecordedRequest(request: request, body: body))
    }

    private static func drainBody(of request: URLRequest) -> Data? {
        if let body = request.httpBody {
            return body
        }
        guard let stream = request.httpBodyStream else {
            return nil
        }
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let read = stream.read(&buffer, maxLength: buffer.count)
            guard read > 0 else { break }
            data.append(buffer, count: read)
        }
        return data
    }
}

/// JSON helpers shared by the API tests.
private enum StubJSON {
    /// Re-encodes `value` and parses the result back into a JSON object.
    ///
    /// Assertions go through JSON on purpose: the Swift property names of the
    /// generated types depend on the generator's naming strategy, while the
    /// JSON keys are fixed by the OpenAPI document. Re-encoding also proves
    /// that no field was dropped while decoding.
    static func reencoded<T: Encodable>(from value: T) throws -> [String: Any] {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try parsed(from: encoder.encode(value))
    }

    /// Parses `data` into a JSON object.
    static func parsed(from data: Data?) throws -> [String: Any] {
        let data = try XCTUnwrap(data)
        let parsed = try JSONSerialization.jsonObject(with: data)
        return try XCTUnwrap(parsed as? [String: Any])
    }

    /// Decodes `json` into `type`.
    static func decoded<T: Decodable>(_ type: T.Type, fromJSON json: String) throws -> T {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(type, from: Data(json.utf8))
    }
}
