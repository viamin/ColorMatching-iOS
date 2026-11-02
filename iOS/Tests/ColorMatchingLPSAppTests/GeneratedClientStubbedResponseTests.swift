import Foundation
import XCTest

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

#if canImport(ColorMatchingOpenAPI)
import ColorMatchingOpenAPI
import OpenAPIRuntime
import OpenAPIURLSession

/// Exercises the generated OpenAPI client against locally stubbed HTTP
/// responses (no live server in CI), covering every surface the app uses
/// today plus the drift-visibility behavior (undocumented status codes).
///
/// Compiled only once the `ColorMatchingOpenAPI` target exists; until then the
/// fallback suite below records the missing module as a skip (#5 red phase).
final class GeneratedClientStubbedResponseTests: XCTestCase {
    override func tearDown() {
        StubURLProtocol.handler = nil
        super.tearDown()
    }

    // MARK: - Test-sheet manifest

    func testFetchManifestDecodesProseContractManifest() async throws {
        var capturedRequest: URLRequest?
        StubURLProtocol.handler = { request in
            capturedRequest = request
            return (Self.httpResponse(for: request, status: 200), Data(Self.manifestJSON.utf8))
        }

        let output = try await makeClient().fetchManifest(.init(path: .init(sheet_id: "sheet_1")))

        guard case .ok(let ok) = output else { return XCTFail("Expected .ok, got \(output).") }
        let manifest = try ok.body.json
        XCTAssertEqual(manifest.schema_version, "lps-sheet-manifest/v1")
        XCTAssertEqual(manifest.sheet_id, "sheet_1")
        XCTAssertEqual(manifest.patches.first?.id, "patch_1")
        XCTAssertEqual(manifest.patches.first?.rect.width, 16)
        XCTAssertEqual(manifest.pairs.first?.first_patch_id, "patch_1")
        XCTAssertEqual(manifest.capture_profile.scoring_algorithm_version, "lps-distance-v1")

        XCTAssertEqual(capturedRequest?.url?.path, "/api/v1/test_sheets/sheet_1/manifest")
        XCTAssertEqual(capturedRequest?.httpMethod, "GET")
    }

    func testFetchManifestSurfacesUndocumentedStatusAsUndocumented() async throws {
        StubURLProtocol.handler = { request in
            (Self.httpResponse(for: request, status: 500), Data(#"{"errors":{"detail":"boom"}}"#.utf8))
        }

        let output = try await makeClient().fetchManifest(.init(path: .init(sheet_id: "sheet_1")))

        guard case .undocumented(let statusCode, _) = output else { return XCTFail("Expected .undocumented, got \(output).") }
        XCTAssertEqual(statusCode, 500)
    }

    // MARK: - Recent sheets

    func testFetchRecentSheetsDecodesNullableTitles() async throws {
        var capturedRequest: URLRequest?
        StubURLProtocol.handler = { request in
            capturedRequest = request
            return (
                Self.httpResponse(for: request, status: 200),
                Data(#"""
                {"sheets":[
                  {"sheet_id":"sheet_1","manifest_url":"https://example.test/api/v1/test_sheets/sheet_1/manifest","title":null},
                  {"sheet_id":"sheet_2","manifest_url":"https://example.test/api/v1/test_sheets/sheet_2/manifest","title":"July sheet"}
                ]}
                """#.utf8)
            )
        }

        let output = try await makeClient().fetchRecentSheets(.init())

        guard case .ok(let ok) = output else { return XCTFail("Expected .ok, got \(output).") }
        let sheets = try ok.body.json.sheets
        XCTAssertEqual(sheets.count, 2)
        XCTAssertEqual(sheets.first?.sheet_id, "sheet_1")
        XCTAssertNil(sheets.first?.title, "title must decode as nil when the server omits a display name.")
        XCTAssertEqual(sheets.last?.title, "July sheet")

        XCTAssertEqual(capturedRequest?.url?.path, "/api/v1/test_sheets/recent")
    }

    // MARK: - Capture session creation

    func testCreateCaptureSendsNestedMetadataShapeAndDecodesCaptureID() async throws {
        var capturedRequest: URLRequest?
        var capturedBody: Data?
        StubURLProtocol.handler = { request in
            capturedRequest = request
            capturedBody = request.httpBodyStream.flatMap(Self.readBody) ?? request.httpBody
            return (Self.httpResponse(for: request, status: 201), Data(#"{"capture_id":"cap_1"}"#.utf8))
        }

        let body = try Self.decode(
            Components.Schemas.CaptureRequest.self,
            from: #"""
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
            """#
        )
        let output = try await makeClient().createCapture(.init(path: .init(sheet_id: "sheet_1"), body: .json(body)))

        guard case .created(let created) = output else { return XCTFail("Expected .created, got \(output).") }
        XCTAssertEqual(try created.body.json.capture_id, "cap_1")

        XCTAssertEqual(capturedRequest?.url?.path, "/api/v1/test_sheets/sheet_1/captures")
        XCTAssertEqual(capturedRequest?.httpMethod, "POST")
        XCTAssertTrue(
            capturedRequest?.value(forHTTPHeaderField: "Content-Type")?.hasPrefix("application/json") == true
        )

        let json = try Self.jsonObject(from: capturedBody)
        let metadata = try XCTUnwrap(json["metadata"] as? [String: Any])
        XCTAssertEqual(metadata["device_model"] as? String, "iPhone")
        let gains = try XCTUnwrap(metadata["white_balance_gains"] as? [String: Double])
        XCTAssertEqual(try XCTUnwrap(gains["red"]), 1.2, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(gains["green"]), 1.0, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(gains["blue"]), 1.4, accuracy: 0.0001)
        let quality = try XCTUnwrap(json["quality"] as? [String: Any])
        XCTAssertEqual(quality["detected_marker_count"] as? Int, 4)
        XCTAssertEqual(quality["rejections"] as? [String], [])
    }

    // MARK: - Measurement upload

    func testUploadMeasurementsRoundTripsMeasurementsAndScores() async throws {
        var capturedRequest: URLRequest?
        var capturedBody: Data?
        StubURLProtocol.handler = { request in
            capturedRequest = request
            capturedBody = request.httpBodyStream.flatMap(Self.readBody) ?? request.httpBody
            return (
                Self.httpResponse(for: request, status: 200),
                Data(#"{"capture_id":"cap_1","measurement_count":1,"pair_score_count":1}"#.utf8)
            )
        }

        let body = try Self.decode(
            Components.Schemas.MeasurementUploadRequest.self,
            from: #"""
            {
              "scoring_algorithm_version": "lps-distance-v1",
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
            """#
        )
        let output = try await makeClient().uploadMeasurements(.init(path: .init(capture_id: "cap_1"), body: .json(body)))

        guard case .ok(let ok) = output else { return XCTFail("Expected .ok, got \(output).") }
        XCTAssertEqual(try ok.body.json.measurement_count, 1)
        XCTAssertEqual(try ok.body.json.pair_score_count, 1)

        XCTAssertEqual(capturedRequest?.url?.path, "/api/v1/captures/cap_1/measurements")
        XCTAssertEqual(capturedRequest?.httpMethod, "POST")

        let json = try Self.jsonObject(from: capturedBody)
        XCTAssertEqual(json["scoring_algorithm_version"] as? String, "lps-distance-v1")
        let measurement = try XCTUnwrap((json["measurements"] as? [[String: Any]])?.first)
        XCTAssertEqual(measurement["patch_id"] as? String, "patch_1")
        let median = try XCTUnwrap(measurement["linear_rgb_median"] as? [String: Double])
        XCTAssertEqual(try XCTUnwrap(median["r"]), 0.12, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(median["g"]), 0.10, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(median["b"]), 0.02, accuracy: 0.0001)
        let stats = try XCTUnwrap(measurement["stats"] as? [String: Any])
        XCTAssertEqual(stats["sample_count"] as? Int, 900)
        let score = try XCTUnwrap((json["pair_scores"] as? [[String: Any]])?.first)
        XCTAssertEqual(score["pair_id"] as? String, "pair_1")
        XCTAssertEqual(score["distance"] as? Double, 0.035)
        XCTAssertEqual(score["similarity"] as? Double, 0.965)
        XCTAssertEqual(score["algorithm_version"] as? String, "lps-distance-v1")
    }

    // MARK: - Judgment upload

    func testUploadJudgmentsRoundTripsJudgments() async throws {
        var capturedRequest: URLRequest?
        var capturedBody: Data?
        StubURLProtocol.handler = { request in
            capturedRequest = request
            capturedBody = request.httpBodyStream.flatMap(Self.readBody) ?? request.httpBody
            return (
                Self.httpResponse(for: request, status: 200),
                Data(#"{"capture_id":"cap_1","judgment_count":1}"#.utf8)
            )
        }

        let body = try Self.decode(
            Components.Schemas.JudgmentUploadRequest.self,
            from: #"""
            {"judgments":[{"pair_id":"pair_1","judgment":"near_match"}]}
            """#
        )
        let output = try await makeClient().uploadJudgments(.init(path: .init(capture_id: "cap_1"), body: .json(body)))

        guard case .ok(let ok) = output else { return XCTFail("Expected .ok, got \(output).") }
        XCTAssertEqual(try ok.body.json.judgment_count, 1)

        XCTAssertEqual(capturedRequest?.url?.path, "/api/v1/captures/cap_1/judgments")
        XCTAssertEqual(capturedRequest?.httpMethod, "POST")

        let json = try Self.jsonObject(from: capturedBody)
        let judgment = try XCTUnwrap((json["judgments"] as? [[String: Any]])?.first)
        XCTAssertEqual(judgment["pair_id"] as? String, "pair_1")
        XCTAssertEqual(judgment["judgment"] as? String, "near_match")
    }

    // MARK: - Ranked results

    func testFetchRankedResultsDecodesVersionedEnvelope() async throws {
        var capturedRequest: URLRequest?
        StubURLProtocol.handler = { request in
            capturedRequest = request
            return (
                Self.httpResponse(for: request, status: 200),
                Data(#"{"schema_version":"lps-ranked-results/v1","sheet_id":"sheet_1"}"#.utf8)
            )
        }

        let output = try await makeClient().fetchRankedResults(.init(path: .init(sheet_id: "sheet_1")))

        guard case .ok(let ok) = output else { return XCTFail("Expected .ok, got \(output).") }
        let results = try ok.body.json
        XCTAssertEqual(results.schema_version, "lps-ranked-results/v1")
        XCTAssertEqual(results.sheet_id, "sheet_1")

        XCTAssertEqual(capturedRequest?.url?.path, "/api/v1/test_sheets/sheet_1/ranked_results")
    }

    // MARK: - Fixtures and helpers

    private static let manifestJSON = #"""
    {
      "schema_version": "lps-sheet-manifest/v1",
      "sheet_version": "lps-letter-grid-v1",
      "sheet_id": "sheet_1",
      "manifest_url": "https://example.test/api/v1/test_sheets/sheet_1/manifest",
      "created_at": "2026-07-25T12:00:00Z",
      "page": {"units": "mm", "width": 215.9, "height": 279.4},
      "registration_markers": [
        {"role": "top_left", "shape": "solid_square", "rect": {"x": 12, "y": 12, "width": 8, "height": 8}}
      ],
      "printer_profile": {
        "id": "printer_profile_1",
        "name": "Research printer",
        "paper": "paper name",
        "ink": "ink set",
        "settings": {}
      },
      "capture_profile": {
        "expected_illuminant": "low_pressure_sodium",
        "preferred_camera": "built_in_wide_angle_rear",
        "scoring_algorithm_version": "lps-distance-v1"
      },
      "patches": [
        {
          "id": "patch_1",
          "role": "pair_color",
          "pair_id": "pair_1",
          "pair_side": "first",
          "reference_role": null,
          "source_color": "#FF0000",
          "safe_inset_mm": 1.5,
          "rect": {"x": 16, "y": 38, "width": 16, "height": 10}
        }
      ],
      "pairs": [
        {
          "id": "pair_1",
          "first_patch_id": "patch_1",
          "second_patch_id": "patch_2",
          "source_colors": ["#FF0000", "#00FF00"],
          "grid_row": 0,
          "grid_col": 1
        }
      ]
    }
    """#

    private func makeClient() -> ColorMatchingOpenAPI.Client {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return Client(
            serverURL: URL(string: "https://example.test")!,
            transport: URLSessionTransport(
                configuration: .init(session: URLSession(configuration: configuration))
            )
        )
    }

    private static func httpResponse(for request: URLRequest, status: Int) -> HTTPURLResponse {
        HTTPURLResponse(
            url: request.url!,
            statusCode: status,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
    }

    private static func decode<T: Decodable>(_ type: T.Type, from json: String) throws -> T {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(type, from: Data(json.utf8))
    }

    private static func jsonObject(from data: Data?, file: StaticString = #filePath, line: UInt = #line) throws -> [String: Any] {
        try XCTUnwrap(try JSONSerialization.jsonObject(with: XCTUnwrap(data, file: file, line: line)) as? [String: Any], file: file, line: line)
    }

    private static func readBody(_ stream: InputStream) -> Data {
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
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
    nonisolated(unsafe) static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

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

#else

/// Red-phase placeholder (#5): skips until the `ColorMatchingOpenAPI` generated
/// client target is wired into the package, then the stubbed-response suite
/// above takes over automatically.
final class GeneratedClientStubbedResponseTests: XCTestCase {
    func testGeneratedClientStubbedResponseSuiteIsActive() throws {
        throw XCTSkip(
            "ColorMatchingOpenAPI generated client target not present yet; "
                + "run the OpenAPIGenerator plugin over Sources/ColorMatchingOpenAPI/openapi.json (see docs/openapi-generated-client-test-plan.md)."
        )
    }
}

#endif
