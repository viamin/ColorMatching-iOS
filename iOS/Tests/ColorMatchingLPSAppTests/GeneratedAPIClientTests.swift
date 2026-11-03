import Foundation
import MeasurementCore
import XCTest
@testable import ColorMatchingLPSAppCore

/// Exercises the OpenAPI-generated client that backs `APIClient` against
/// stubbed HTTP responses.
///
/// The stubs speak the wire format published by `viamin/color_matching`
/// (`GET /api/v1/openapi.json`), so a change in the generated request or
/// response shape fails here instead of at capture time on a device.
///
/// Nothing in this suite contacts a live server.
final class GeneratedAPIClientTests: XCTestCase {
    override func tearDown() {
        StubURLProtocol.handler = nil
        super.tearDown()
    }

    // MARK: - Manifest

    func testFetchManifestUsesSpecPathAndDecodesManifest() async throws {
        var capturedRequest: URLRequest?
        StubURLProtocol.handler = { request in
            capturedRequest = request
            return Self.stubResponse(for: request, statusCode: 200, json: Self.manifestJSON)
        }

        let manifest = try await client().fetchManifest(
            baseURL: URL(string: "https://example.test")!,
            sheetCode: "LPSM-DEV2"
        )

        XCTAssertEqual(capturedRequest?.httpMethod, "GET")
        XCTAssertEqual(capturedRequest?.url?.path, "/api/v1/test_sheets/LPSM-DEV2/manifest")
        XCTAssertEqual(capturedRequest?.value(forHTTPHeaderField: "Authorization"), "Bearer token")

        let json = try Self.jsonObject(from: try JSONEncoder().encode(manifest))
        XCTAssertEqual(json["schema_version"] as? String, "lps-sheet-manifest/v1")
        XCTAssertEqual(json["sheet_id"] as? String, "LPSM-DEV2")
        XCTAssertEqual(json["manifest_url"] as? String, "http://localhost:4000/api/v1/test_sheets/LPSM-DEV2/manifest")
        XCTAssertEqual((json["patches"] as? [Any])?.count, 2)
        XCTAssertEqual((json["pairs"] as? [Any])?.count, 1)

        let page = try XCTUnwrap(json["page"] as? [String: Any])
        XCTAssertEqual(page["units"] as? String, "mm")
        XCTAssertEqual(page["width"] as? Double ?? 0, 215.9, accuracy: 0.0001)
    }

    // MARK: - Recent sheets

    func testFetchRecentSheetsUsesSpecPathAndDecodesSheets() async throws {
        var capturedRequest: URLRequest?
        StubURLProtocol.handler = { request in
            capturedRequest = request
            return Self.stubResponse(for: request, statusCode: 200, json: Self.recentSheetsJSON)
        }

        let sheets = try await client().fetchRecentSheets(baseURL: URL(string: "https://example.test")!)

        XCTAssertEqual(capturedRequest?.httpMethod, "GET")
        XCTAssertEqual(capturedRequest?.url?.path, "/api/v1/test_sheets/recent")
        XCTAssertEqual(sheets.count, 2)
        XCTAssertNil(sheets[0].title)

        let json = try Self.jsonObject(from: try JSONEncoder().encode(sheets[1]))
        XCTAssertEqual(json["sheet_id"] as? String, "LPSM-DEV2")
        XCTAssertEqual(json["manifest_url"] as? String, "http://localhost:4000/api/v1/test_sheets/LPSM-DEV2/manifest")
        XCTAssertEqual(json["title"] as? String, "July LPS comparison sheet")
    }

    // MARK: - Capture session

    func testCreateCapturePostsSpecPayload() async throws {
        var capturedRequest: URLRequest?
        var capturedBody: Data?
        StubURLProtocol.handler = { request in
            capturedRequest = request
            capturedBody = request.httpBodyStream.flatMap(Self.readBody) ?? request.httpBody
            return Self.stubResponse(for: request, statusCode: 201, json: #"{"capture_id": "cap_1"}"#)
        }

        let capture = try await client().createCapture(
            sheetID: "LPSM-DEV2",
            baseURL: URL(string: "https://example.test")!,
            metadata: CaptureMetadata(
                deviceModel: "iPhone",
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

        XCTAssertEqual(capturedRequest?.httpMethod, "POST")
        XCTAssertEqual(capturedRequest?.url?.path, "/api/v1/test_sheets/LPSM-DEV2/captures")
        XCTAssertTrue(capturedRequest?.value(forHTTPHeaderField: "Content-Type")?.contains("application/json") == true)

        let json = try Self.jsonObject(from: capturedBody)
        let metadata = try XCTUnwrap(json["metadata"] as? [String: Any])
        XCTAssertEqual(metadata["device_model"] as? String, "iPhone")
        XCTAssertEqual(metadata["lens"] as? String, "built_in_wide_angle")
        XCTAssertEqual(metadata["image_width"] as? Int, 4032)
        XCTAssertEqual(metadata["image_height"] as? Int, 3024)
        XCTAssertEqual(metadata["app_version"] as? String, "0.1.0")
        XCTAssertNotNil(metadata["timestamp"])

        let quality = try XCTUnwrap(json["quality"] as? [String: Any])
        XCTAssertEqual(quality["detected_marker_count"] as? Int, 4)
        XCTAssertEqual(quality["blur_score"] as? Double ?? 0, 0.82, accuracy: 0.0001)
        XCTAssertEqual(quality["rejections"] as? [String], [])

        let captureJSON = try Self.jsonObject(from: try JSONEncoder().encode(capture))
        XCTAssertEqual(captureJSON["capture_id"] as? String, "cap_1")
    }

    // MARK: - Measurement upload

    func testUploadMeasurementsPostsSpecPayloadWithStats() async throws {
        var capturedRequest: URLRequest?
        var capturedBody: Data?
        StubURLProtocol.handler = { request in
            capturedRequest = request
            capturedBody = request.httpBodyStream.flatMap(Self.readBody) ?? request.httpBody
            return Self.stubResponse(
                for: request,
                statusCode: 200,
                json: #"{"capture_id": "cap_1", "measurement_count": 1, "pair_score_count": 1}"#
            )
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

        try await client().uploadMeasurements(
            captureID: "cap_1",
            baseURL: URL(string: "https://example.test")!,
            measurements: [
                PatchMeasurement(
                    patchID: "pair-abc#first",
                    linearRGBMedian: rgb,
                    normalizedLinearRGBMedian: rgb,
                    stats: stats
                )
            ],
            scores: [
                PairScore(
                    pairID: "pair-abc",
                    distance: 0.035,
                    similarity: 0.965,
                    algorithmVersion: LPSScorer.algorithmVersion
                )
            ]
        )

        XCTAssertEqual(capturedRequest?.httpMethod, "POST")
        XCTAssertEqual(capturedRequest?.url?.path, "/api/v1/captures/cap_1/measurements")
        XCTAssertTrue(capturedRequest?.value(forHTTPHeaderField: "Content-Type")?.contains("application/json") == true)

        let json = try Self.jsonObject(from: capturedBody)
        let measurement = try XCTUnwrap((json["measurements"] as? [[String: Any]])?.first)
        XCTAssertEqual(measurement["patch_id"] as? String, "pair-abc#first")

        let median = try Self.rgbComponents(from: measurement["linear_rgb_median"])
        XCTAssertEqual(median.r, 0.12, accuracy: 0.0001)
        XCTAssertEqual(median.g, 0.10, accuracy: 0.0001)
        XCTAssertEqual(median.b, 0.02, accuracy: 0.0001)

        // The server stores `sample_count`, `clipping_fraction`, `mean` and
        // `standard_deviation` as required columns, so the generated request has
        // to carry them or the upload is rejected.
        let uploadedStats = try XCTUnwrap(measurement["stats"] as? [String: Any])
        XCTAssertEqual(Set(uploadedStats.keys), ["sample_count", "clipping_fraction", "mean", "standard_deviation"])
        XCTAssertEqual(uploadedStats["sample_count"] as? Int, 900)

        let pairScore = try XCTUnwrap((json["pair_scores"] as? [[String: Any]])?.first)
        XCTAssertEqual(pairScore["pair_id"] as? String, "pair-abc")
        XCTAssertEqual(pairScore["algorithm_version"] as? String, "lps-distance-v1")
    }

    // MARK: - Judgment upload

    func testUploadJudgmentsPostsSpecPayload() async throws {
        var capturedRequest: URLRequest?
        var capturedBody: Data?
        StubURLProtocol.handler = { request in
            capturedRequest = request
            capturedBody = request.httpBodyStream.flatMap(Self.readBody) ?? request.httpBody
            return Self.stubResponse(
                for: request,
                statusCode: 200,
                json: #"{"capture_id": "cap_1", "judgment_count": 1}"#
            )
        }

        try await client().uploadJudgments(
            captureID: "cap_1",
            baseURL: URL(string: "https://example.test")!,
            judgments: [PairJudgment(pairID: "pair-abc", judgment: "near_match")]
        )

        XCTAssertEqual(capturedRequest?.httpMethod, "POST")
        XCTAssertEqual(capturedRequest?.url?.path, "/api/v1/captures/cap_1/judgments")
        XCTAssertTrue(capturedRequest?.value(forHTTPHeaderField: "Content-Type")?.contains("application/json") == true)

        let json = try Self.jsonObject(from: capturedBody)
        let judgment = try XCTUnwrap((json["judgments"] as? [[String: Any]])?.first)
        XCTAssertEqual(judgment["pair_id"] as? String, "pair-abc")
        XCTAssertEqual(judgment["judgment"] as? String, "near_match")
    }

    // MARK: - Ranked results

    func testFetchRankedResultsUsesSpecPathAndDecodesResults() async throws {
        var capturedRequest: URLRequest?
        StubURLProtocol.handler = { request in
            capturedRequest = request
            return Self.stubResponse(for: request, statusCode: 200, json: Self.rankedResultsJSON)
        }

        let ranked = try await client().fetchRankedResults(
            baseURL: URL(string: "https://example.test")!,
            sheetCode: "LPSM-DEV2"
        )

        XCTAssertEqual(capturedRequest?.httpMethod, "GET")
        XCTAssertEqual(capturedRequest?.url?.path, "/api/v1/test_sheets/LPSM-DEV2/ranked_results")

        let json = try Self.jsonObject(from: try JSONEncoder().encode(ranked))
        XCTAssertEqual(json["schema_version"] as? String, "lps-ranked-results/v1")
        XCTAssertEqual(json["sheet_id"] as? String, "LPSM-DEV2")

        let results = try XCTUnwrap(json["results"] as? [[String: Any]])
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?["rank"] as? Int, 1)
        XCTAssertEqual(results.first?["pair_id"] as? String, "pair-abc")
    }

    // MARK: - Failures

    func testServerErrorIsSurfacedToTheCaller() async throws {
        StubURLProtocol.handler = { request in
            Self.stubResponse(for: request, statusCode: 500, json: #"{"errors": {"detail": "boom"}}"#)
        }

        var caught: Error?
        do {
            _ = try await client().fetchManifest(
                baseURL: URL(string: "https://example.test")!,
                sheetCode: "LPSM-DEV2"
            )
        } catch {
            caught = error
        }

        XCTAssertNotNil(caught, "A 500 response must not be reported as a successful manifest fetch")
    }

    func testNotFoundIsSurfacedToTheCaller() async throws {
        StubURLProtocol.handler = { request in
            Self.stubResponse(for: request, statusCode: 404, json: #"{"errors": {"detail": "Sheet not found"}}"#)
        }

        var caught: Error?
        do {
            _ = try await client().fetchManifest(
                baseURL: URL(string: "https://example.test")!,
                sheetCode: "missing"
            )
        } catch {
            caught = error
        }

        XCTAssertNotNil(caught, "A 404 response must not be reported as a successful manifest fetch")
    }

    // MARK: - Helpers

    private func client() -> APIClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return APIClient(token: "token", session: URLSession(configuration: configuration))
    }

    private static func stubResponse(for request: URLRequest, statusCode: Int, json: String) -> (HTTPURLResponse, Data) {
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        return (response, Data(json.utf8))
    }

    private static func jsonObject(from data: Data?) throws -> [String: Any] {
        let object = try JSONSerialization.jsonObject(with: try XCTUnwrap(data))
        return try XCTUnwrap(object as? [String: Any])
    }

    /// The published document describes the RGB payload as an object with
    /// `r`/`g`/`b` channels; the server also accepts the array form.
    private static func rgbComponents(from value: Any?) throws -> (r: Double, g: Double, b: Double) {
        if let object = value as? [String: Any] {
            return (
                try XCTUnwrap(object["r"] as? Double),
                try XCTUnwrap(object["g"] as? Double),
                try XCTUnwrap(object["b"] as? Double)
            )
        }
        if let array = value as? [Any], array.count == 3 {
            return (
                try XCTUnwrap(array[0] as? Double),
                try XCTUnwrap(array[1] as? Double),
                try XCTUnwrap(array[2] as? Double)
            )
        }
        XCTFail("Unexpected RGB payload: \(String(describing: value))")
        return (0, 0, 0)
    }

    private static func readBody(_ stream: InputStream) -> Data {
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 1024)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            if count > 0 {
                data.append(buffer, count: count)
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

// MARK: - Fixtures

private extension GeneratedAPIClientTests {
    /// Mirrors `ColorMatchingWeb.TestSheetJSON.manifest/1`.
    static let manifestJSON = #"""
    {
      "schema_version": "lps-sheet-manifest/v1",
      "sheet_version": "lps-letter-grid-v1",
      "sheet_id": "LPSM-DEV2",
      "manifest_url": "http://localhost:4000/api/v1/test_sheets/LPSM-DEV2/manifest",
      "created_at": "2026-07-28T20:10:19Z",
      "page": {"units": "mm", "width": 215.9, "height": 279.4},
      "registration_markers": [
        {"role": "top_left", "shape": "solid_square", "rect": {"x": 12.7, "y": 12.7, "width": 10.0, "height": 10.0}},
        {"role": "top_right", "shape": "solid_square", "rect": {"x": 193.2, "y": 12.7, "width": 10.0, "height": 10.0}},
        {"role": "bottom_right", "shape": "solid_square", "rect": {"x": 193.2, "y": 256.7, "width": 10.0, "height": 10.0}},
        {"role": "bottom_left", "shape": "solid_square", "rect": {"x": 12.7, "y": 256.7, "width": 10.0, "height": 10.0}}
      ],
      "printer_profile": {
        "printer_make_model": "Generic Inkjet",
        "paper_type": "Plain",
        "ink_type": "Dye"
      },
      "capture_profile": {
        "expected_illuminant": "low_pressure_sodium",
        "preferred_camera": "built_in_wide_angle_rear",
        "scoring_algorithm_version": "lps-distance-v1"
      },
      "patches": [
        {"id": "pair-abc#first", "role": "pair_color", "pair_id": "pair-abc", "pair_side": "first", "reference_role": null, "source_color": "#FF4444", "safe_inset_mm": 1.5, "rect": {"x": 75.95, "y": 107.7, "width": 10.0, "height": 10.0}},
        {"id": "pair-abc#second", "role": "pair_color", "pair_id": "pair-abc", "pair_side": "second", "reference_role": null, "source_color": "#BB55BB", "safe_inset_mm": 1.5, "rect": {"x": 85.95, "y": 117.7, "width": 10.0, "height": 10.0}}
      ],
      "pairs": [
        {"id": "pair-abc", "first_patch_id": "pair-abc#first", "second_patch_id": "pair-abc#second", "source_colors": ["#FF4444", "#BB55BB"], "grid_row": 0, "grid_col": 1}
      ]
    }
    """#

    /// Mirrors `ColorMatchingWeb.TestSheetJSON.recent/1`. The upstream server
    /// currently always sends a `null` title; the contract allows a title, so
    /// both shapes are covered.
    static let recentSheetsJSON = #"""
    {
      "sheets": [
        {"sheet_id": "LPSM-DEV1", "manifest_url": "http://localhost:4000/api/v1/test_sheets/LPSM-DEV1/manifest", "title": null},
        {"sheet_id": "LPSM-DEV2", "manifest_url": "http://localhost:4000/api/v1/test_sheets/LPSM-DEV2/manifest", "title": "July LPS comparison sheet"}
      ]
    }
    """#

    /// Mirrors `ColorMatchingWeb.TestSheetJSON.ranked_results/1`.
    static let rankedResultsJSON = #"""
    {
      "schema_version": "lps-ranked-results/v1",
      "sheet_id": "LPSM-DEV2",
      "printer_profile": {
        "printer_make_model": "Generic Inkjet",
        "paper_type": "Plain",
        "ink_type": "Dye"
      },
      "capture_count": 2,
      "latest_capture_at": "2026-07-28T20:10:19Z",
      "earliest_capture_at": "2026-07-28T20:05:00Z",
      "scoring_algorithm_versions": ["lps-distance-v1"],
      "results": [
        {
          "rank": 1,
          "pair_id": "pair-abc",
          "scoring_algorithm_version": "lps-distance-v1",
          "row": 0,
          "col": 1,
          "source_colors": {"color_a_hex": "#FF4444", "color_b_hex": "#BB55BB"},
          "score": {
            "average": 0.965,
            "latest": 0.965,
            "minimum": 0.96,
            "maximum": 0.97,
            "capture_count": 2,
            "sample_count": 2,
            "algorithm_versions": ["lps-distance-v1"]
          },
          "current_judgment": "near_match",
          "current_judgment_observed_at": "2026-07-28T20:12:00Z",
          "observation_count": 1,
          "latest_observation": {"judgment": "near_match", "observed_at": "2026-07-28T20:12:00Z"},
          "capture_count": 2,
          "latest_capture_at": "2026-07-28T20:10:19Z",
          "earliest_capture_at": "2026-07-28T20:05:00Z"
        }
      ]
    }
    """#
}
