//
//  GeneratedClientStubbedServerTests.swift
//
//  Red-phase tests for "Replace hand-written API layer with a generated OpenAPI
//  Swift client" (#5).
//
//  While the `ColorMatchingOpenAPI` module does not exist, this file compiles to a
//  single failing availability test. Once the generated client is wired into the
//  package (see docs/openapi-client-generation.md), these tests exercise every
//  app-facing operation of the generated client against stubbed server responses —
//  no live server is contacted.
//
//  Notes on generated names (see docs/openapi-client-generation.md):
//  - Operation IDs are pinned; generated methods are `getTestSheetManifest`,
//    `listRecentTestSheets`, `getRankedResults`, `createCapture`,
//    `uploadMeasurements`, `uploadJudgments`.
//  - Swift property names are lower camel case (`sheet_id` -> `sheetId`); the JSON
//    wire keys stay snake_case via CodingKeys.
//  - Stub payloads mirror what viamin/color_matching renders today
//    (ColorMatchingWeb.TestSheetJSON upstream), including patch IDs of the form
//    "{pair_id}#first"/"{pair_id}#second" and 200 + JSON-body upload responses.
//

#if canImport(ColorMatchingOpenAPI)
import ColorMatchingOpenAPI
import Foundation
import HTTPTypes
import OpenAPIRuntime
import OpenAPIURLSession
import XCTest

final class GeneratedClientStubbedServerTests: XCTestCase {
    override func tearDown() {
        OpenAPIStubURLProtocol.handler = nil
        super.tearDown()
    }

    // MARK: Manifest

    func testGetTestSheetManifestDecodesServedManifestPayload() async throws {
        Self.stubManifestResponse()
        let manifest = try await fetchManifest()

        XCTAssertEqual(manifest.schemaVersion.rawValue, "lps-sheet-manifest/v1")
        XCTAssertEqual(manifest.sheetId, "lps-7f3k")
        XCTAssertEqual(manifest.sheetVersion, "lps-letter-grid-v1")
        XCTAssertEqual(
            manifest.manifestUrl,
            "https://example.test/api/v1/test_sheets/lps-7f3k/manifest"
        )
        XCTAssertEqual(
            manifest.createdAt,
            ISO8601DateFormatter().date(from: "2026-07-25T12:00:00Z")
        )
        XCTAssertEqual(manifest.page.units, "mm")
        XCTAssertEqual(manifest.page.width, 215.9, accuracy: 0.001)
        XCTAssertEqual(manifest.page.height, 279.4, accuracy: 0.001)
        XCTAssertEqual(manifest.registrationMarkers.count, 4)
        XCTAssertEqual(manifest.registrationMarkers.first?.role, "top_left")
        XCTAssertEqual(manifest.registrationMarkers.first?.shape, "solid_square")
        XCTAssertEqual(manifest.registrationMarkers.first?.rect.x ?? 0, 12, accuracy: 0.001)
        XCTAssertEqual(manifest.printerProfile?.printerMakeModel, "Research printer")
        XCTAssertEqual(manifest.printerProfile?.paperType, "paper name")
        XCTAssertEqual(manifest.printerProfile?.inkType, "ink set")
        XCTAssertEqual(
            manifest.captureProfile.scoringAlgorithmVersion.rawValue,
            "lps-distance-v1"
        )
    }

    func testGetTestSheetManifestDecodesPatchesAndPairs() async throws {
        Self.stubManifestResponse()
        let manifest = try await fetchManifest()

        XCTAssertEqual(manifest.patches.count, 2)
        let first = try XCTUnwrap(manifest.patches.first)
        XCTAssertEqual(first.id, "pair_1#first")
        XCTAssertEqual(first.role, "pair_color")
        XCTAssertEqual(first.pairId, "pair_1")
        XCTAssertEqual(first.pairSide, "first")
        XCTAssertNil(first.referenceRole)
        XCTAssertEqual(first.sourceColor, "#FF0000")
        XCTAssertEqual(first.safeInsetMm, 1.5, accuracy: 0.001)
        XCTAssertEqual(first.rect.width, 16, accuracy: 0.001)

        XCTAssertEqual(manifest.pairs.count, 1)
        let pair = try XCTUnwrap(manifest.pairs.first)
        XCTAssertEqual(pair.id, "pair_1")
        XCTAssertEqual(pair.firstPatchId, "pair_1#first")
        XCTAssertEqual(pair.secondPatchId, "pair_1#second")
        XCTAssertEqual(pair.sourceColors, ["#FF0000", "#00FF00"])
        XCTAssertEqual(pair.gridRow, 0)
        XCTAssertEqual(pair.gridCol, 1)
    }

    func testGetTestSheetManifestSendsGETToManifestPath() async throws {
        let request = try await captureRequestForManifestFetch()
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.url?.path, "/api/v1/test_sheets/lps-7f3k/manifest")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/json")
    }

    // MARK: Recent sheets

    func testListRecentSheetsDecodesNullableTitles() async throws {
        var capturedRequest: URLRequest?
        OpenAPIStubURLProtocol.handler = { request in
            capturedRequest = request
            return Self.okResponse(request, Self.recentSheetsJSON)
        }

        let output = try await makeClient().listRecentTestSheets(.init())

        XCTAssertEqual(capturedRequest?.httpMethod, "GET")
        XCTAssertEqual(capturedRequest?.url?.path, "/api/v1/test_sheets/recent")
        let body = try Self.unwrapOK(output)
        XCTAssertEqual(body.sheets.count, 2)
        XCTAssertEqual(body.sheets.first?.sheetId, "lps-7f3k")
        XCTAssertEqual(
            body.sheets.first?.manifestUrl,
            "https://example.test/api/v1/test_sheets/lps-7f3k/manifest"
        )
        XCTAssertNil(body.sheets.first?.title)
        XCTAssertEqual(body.sheets.last?.title, "July LPS comparison sheet")
    }

    // MARK: Capture creation

    func testCreateCaptureEncodesMetadataAndQualityAndDecodesCaptureID() async throws {
        var capturedRequest: URLRequest?
        OpenAPIStubURLProtocol.handler = { request in
            capturedRequest = request
            return (
                HTTPURLResponse(
                    url: request.url!,
                    statusCode: 201,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "application/json"]
                )!,
                Data(#"{"capture_id":"42"}"#.utf8)
            )
        }

        let output = try await makeClient().createCapture(captureInput())

        let body = try Self.unwrapCreated(output)
        XCTAssertEqual(body.captureId, "42")

        let request = try XCTUnwrap(capturedRequest)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.path, "/api/v1/test_sheets/lps-7f3k/captures")
        XCTAssertTrue(
            (request.value(forHTTPHeaderField: "Content-Type") ?? "").hasPrefix("application/json"),
            "expected a JSON content type, got \(request.value(forHTTPHeaderField: "Content-Type") ?? "nil")"
        )
        XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/json")

        let json = try Self.jsonObject(from: request)
        let metadata = try XCTUnwrap(json["metadata"] as? [String: Any])
        XCTAssertEqual(metadata["device_model"] as? String, "iPhone 15 Pro")
        XCTAssertEqual(metadata["lens"] as? String, "built_in_wide_angle")
        XCTAssertEqual(metadata["exposure_duration_seconds"] as? Double, 0.016)
        XCTAssertEqual(metadata["iso"] as? Int, 100)
        XCTAssertEqual(metadata["focus_lens_position"] as? Double, 0.42)
        XCTAssertEqual(metadata["image_width"] as? Int, 4032)
        XCTAssertEqual(metadata["image_height"] as? Int, 3024)
        XCTAssertEqual(metadata["app_version"] as? String, "0.1.0")
        XCTAssertNotNil(metadata["timestamp"] as? String)
        let gains = try XCTUnwrap(metadata["white_balance_gains"] as? [String: Any])
        XCTAssertEqual(gains["red"] as? Double, 1.2)
        XCTAssertEqual(gains["green"] as? Double, 1.0)
        XCTAssertEqual(gains["blue"] as? Double, 1.4)

        let quality = try XCTUnwrap(json["quality"] as? [String: Any])
        XCTAssertEqual(quality["detected_marker_count"] as? Int, 4)
        XCTAssertEqual(quality["blur_score"] as? Double, 0.82)
        XCTAssertEqual(quality["rejections"] as? [String], [])
    }

    func testBearerAuthMiddlewareAddsAuthorizationHeader() async throws {
        var capturedRequest: URLRequest?
        OpenAPIStubURLProtocol.handler = { request in
            capturedRequest = request
            return Self.okResponse(request, Self.manifestJSON)
        }
        let client = ColorMatchingOpenAPI.Client(
            serverURL: Self.serverURL,
            transport: URLSessionTransport(configuration: .init(session: Self.stubbedSession())),
            middlewares: [BearerAuthMiddleware(token: "token-123")]
        )

        _ = try await client.getTestSheetManifest(.init(path: .init(sheetId: "lps-7f3k")))

        XCTAssertEqual(
            capturedRequest?.value(forHTTPHeaderField: "Authorization"),
            "Bearer token-123"
        )
    }

    // MARK: Measurement upload

    func testUploadMeasurementsEncodesPayloadAndDecodesCounts() async throws {
        var capturedRequest: URLRequest?
        OpenAPIStubURLProtocol.handler = { request in
            capturedRequest = request
            return Self.okResponse(
                request,
                #"{"capture_id":"42","measurement_count":1,"pair_score_count":1}"#
            )
        }

        let output = try await makeClient().uploadMeasurements(measurementInput())

        let body = try Self.unwrapOK(output)
        XCTAssertEqual(body.captureId, "42")
        XCTAssertEqual(body.measurementCount, 1)
        XCTAssertEqual(body.pairScoreCount, 1)

        let request = try XCTUnwrap(capturedRequest)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.path, "/api/v1/captures/42/measurements")

        let json = try Self.jsonObject(from: request)
        XCTAssertEqual(
            json["scoring_algorithm_version"] as? String,
            "lps-distance-v1",
            "the app sends the top-level version today; the vendored schema documents it (delta 8)"
        )
        let measurement = try XCTUnwrap((json["measurements"] as? [[String: Any]])?.first)
        XCTAssertEqual(measurement["patch_id"] as? String, "pair_1#first")
        let median = try XCTUnwrap(measurement["linear_rgb_median"] as? [String: Any])
        XCTAssertEqual(median["r"] as? Double, 0.12)
        XCTAssertEqual(median["g"] as? Double, 0.1)
        XCTAssertEqual(median["b"] as? Double, 0.02)
        XCTAssertNotNil(measurement["normalized_linear_rgb_median"])
        let stats = try XCTUnwrap(measurement["stats"] as? [String: Any])
        XCTAssertEqual(stats["sample_count"] as? Int, 900)
        XCTAssertEqual(stats["clipping_fraction"] as? Double, 0)
        XCTAssertNotNil(stats["mean"])
        XCTAssertNotNil(stats["standard_deviation"])
        let pairScore = try XCTUnwrap((json["pair_scores"] as? [[String: Any]])?.first)
        XCTAssertEqual(pairScore["pair_id"] as? String, "pair_1")
        XCTAssertEqual(pairScore["algorithm_version"] as? String, "lps-distance-v1")
        XCTAssertEqual(pairScore["similarity"] as? Double, 0.965)
        XCTAssertEqual(pairScore["distance"] as? Double, 0.035)
    }

    // MARK: Judgment upload

    func testUploadJudgmentsEncodesPayloadAndDecodesCount() async throws {
        var capturedRequest: URLRequest?
        OpenAPIStubURLProtocol.handler = { request in
            capturedRequest = request
            return Self.okResponse(
                request,
                #"{"capture_id":"42","judgment_count":1}"#
            )
        }

        let input = Operations.UploadJudgments.Input(
            path: .init(captureId: "42"),
            body: .json(.init(judgments: [.init(pairId: "pair_1", judgment: "near_match")]))
        )
        let output = try await makeClient().uploadJudgments(input)

        let body = try Self.unwrapOK(output)
        XCTAssertEqual(body.captureId, "42")
        XCTAssertEqual(body.judgmentCount, 1)

        let request = try XCTUnwrap(capturedRequest)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.path, "/api/v1/captures/42/judgments")
        let json = try Self.jsonObject(from: request)
        let judgment = try XCTUnwrap((json["judgments"] as? [[String: Any]])?.first)
        XCTAssertEqual(judgment["pair_id"] as? String, "pair_1")
        XCTAssertEqual(judgment["judgment"] as? String, "near_match")
    }

    // MARK: Ranked results

    func testGetRankedResultsDecodesGuaranteedFieldsAndToleratesUndocumentedOnes() async throws {
        var capturedRequest: URLRequest?
        OpenAPIStubURLProtocol.handler = { request in
            capturedRequest = request
            return Self.okResponse(request, Self.rankedResultsJSON)
        }

        let input = Operations.GetRankedResults.Input(path: .init(sheetId: "lps-7f3k"))
        let output = try await makeClient().getRankedResults(input)

        XCTAssertEqual(capturedRequest?.httpMethod, "GET")
        XCTAssertEqual(capturedRequest?.url?.path, "/api/v1/test_sheets/lps-7f3k/ranked_results")
        let body = try Self.unwrapOK(output)
        XCTAssertEqual(body.schemaVersion.rawValue, "lps-ranked-results/v1")
        XCTAssertEqual(body.sheetId, "lps-7f3k")
    }
}

// MARK: - Inputs

private extension GeneratedClientStubbedServerTests {
    func captureInput() -> Operations.CreateCapture.Input {
        Operations.CreateCapture.Input(
            path: .init(sheetId: "lps-7f3k"),
            body: .json(.init(
                metadata: .init(
                    deviceModel: "iPhone 15 Pro",
                    lens: "built_in_wide_angle",
                    exposureDurationSeconds: 0.016,
                    iso: 100,
                    focusLensPosition: 0.42,
                    whiteBalanceGains: .init(red: 1.2, green: 1.0, blue: 1.4),
                    imageWidth: 4032,
                    imageHeight: 3024,
                    appVersion: "0.1.0",
                    timestamp: ISO8601DateFormatter().date(from: "2026-07-25T12:00:00Z")!
                ),
                quality: .init(detectedMarkerCount: 4, blurScore: 0.82, rejections: [])
            ))
        )
    }

    func measurementInput() -> Operations.UploadMeasurements.Input {
        Operations.UploadMeasurements.Input(
            path: .init(captureId: "42"),
            body: .json(.init(
                scoringAlgorithmVersion: "lps-distance-v1",
                measurements: [
                    .init(
                        patchId: "pair_1#first",
                        linearRgbMedian: .init(value2: .init(r: 0.12, g: 0.1, b: 0.02)),
                        normalizedLinearRgbMedian: .init(value2: .init(r: 0.15, g: 0.12, b: 0.02)),
                        stats: .init(
                            sampleCount: 900,
                            clippingFraction: 0,
                            mean: .init(r: 0.12, g: 0.1, b: 0.02),
                            standardDeviation: .init(r: 0.01, g: 0.01, b: 0.004)
                        )
                    )
                ],
                pairScores: [
                    .init(
                        pairId: "pair_1",
                        algorithmVersion: "lps-distance-v1",
                        similarity: 0.965,
                        distance: 0.035
                    )
                ]
            ))
        )
    }
}

// MARK: - Transport plumbing

/// Demonstrates the bearer-auth pattern the app adapter must use: the generated
/// client does not add credentials itself; a `ClientMiddleware` does.
private struct BearerAuthMiddleware: ClientMiddleware {
    let token: String

    func intercept(
        _ request: HTTPTypes.HTTPRequest,
        body: OpenAPIRuntime.HTTPBody?,
        baseURL: Foundation.URL,
        operationID: Swift.String,
        next: @Sendable (
            HTTPTypes.HTTPRequest,
            OpenAPIRuntime.HTTPBody?,
            Foundation.URL
        ) async throws -> (HTTPTypes.HTTPResponse, OpenAPIRuntime.HTTPBody?)
    ) async throws -> (HTTPTypes.HTTPResponse, OpenAPIRuntime.HTTPBody?) {
        var request = request
        request.headerFields[.authorization] = "Bearer \(token)"
        return try await next(request, body, baseURL)
    }
}

private enum StubError: Error {
    case noHandlerConfigured
    case unexpectedResponse
}

private final class OpenAPIStubURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        do {
            let handler = try XCTUnwrap(Self.handler)
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

// MARK: - Response unwrapping and fixtures

private extension GeneratedClientStubbedServerTests {
    static func unwrapOK(
        _ output: Operations.ListRecentTestSheets.Output
    ) throws -> Components.Schemas.RecentSheetsResponse {
        guard case .ok(let ok) = output else { throw StubError.unexpectedResponse }
        return try ok.body.json
    }

    static func unwrapOK(
        _ output: Operations.UploadMeasurements.Output
    ) throws -> Components.Schemas.MeasurementUploadResponse {
        guard case .ok(let ok) = output else { throw StubError.unexpectedResponse }
        return try ok.body.json
    }

    static func unwrapOK(
        _ output: Operations.UploadJudgments.Output
    ) throws -> Components.Schemas.JudgmentUploadResponse {
        guard case .ok(let ok) = output else { throw StubError.unexpectedResponse }
        return try ok.body.json
    }

    static func unwrapOK(
        _ output: Operations.GetRankedResults.Output
    ) throws -> Components.Schemas.RankedResults {
        guard case .ok(let ok) = output else { throw StubError.unexpectedResponse }
        return try ok.body.json
    }

    static func unwrapCreated(
        _ output: Operations.CreateCapture.Output
    ) throws -> Components.Schemas.CaptureCreatedResponse {
        guard case .created(let created) = output else { throw StubError.unexpectedResponse }
        return try created.body.json
    }
}

private extension GeneratedClientStubbedServerTests {
    static let serverURL = URL(string: "https://example.test")!

    static let manifestJSON = """
    {
      "schema_version": "lps-sheet-manifest/v1",
      "sheet_id": "lps-7f3k",
      "sheet_version": "lps-letter-grid-v1",
      "manifest_url": "https://example.test/api/v1/test_sheets/lps-7f3k/manifest",
      "created_at": "2026-07-25T12:00:00Z",
      "page": {"units": "mm", "width": 215.9, "height": 279.4},
      "registration_markers": [
        {"role": "top_left", "shape": "solid_square", "rect": {"x": 12, "y": 12, "width": 8, "height": 8}},
        {"role": "top_right", "shape": "solid_square", "rect": {"x": 195.9, "y": 12, "width": 8, "height": 8}},
        {"role": "bottom_left", "shape": "solid_square", "rect": {"x": 12, "y": 259.4, "width": 8, "height": 8}},
        {"role": "bottom_right", "shape": "solid_square", "rect": {"x": 195.9, "y": 259.4, "width": 8, "height": 8}}
      ],
      "printer_profile": {
        "printer_make_model": "Research printer",
        "paper_type": "paper name",
        "ink_type": "ink set"
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
          "rect": {"x": 36, "y": 38, "width": 16, "height": 10}
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

    static let recentSheetsJSON = """
    {
      "sheets": [
        {
          "sheet_id": "lps-7f3k",
          "manifest_url": "https://example.test/api/v1/test_sheets/lps-7f3k/manifest",
          "title": null
        },
        {
          "sheet_id": "lps-9aa2",
          "manifest_url": "https://example.test/api/v1/test_sheets/lps-9aa2/manifest",
          "title": "July LPS comparison sheet"
        }
      ]
    }
    """

    /// Undocumented fields (capture_count, results, ...) are included to prove the
    /// generated client tolerates fields the served schema does not guarantee.
    static let rankedResultsJSON = """
    {
      "schema_version": "lps-ranked-results/v1",
      "sheet_id": "lps-7f3k",
      "capture_count": 3,
      "results": [
        {
          "rank": 1,
          "pair_id": "pair_1",
          "source_colors": {"color_a_hex": "#FF0000", "color_b_hex": "#00FF00"}
        }
      ]
    }
    """

    static func stubbedSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [OpenAPIStubURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    static func okResponse(_ request: URLRequest, _ body: String) -> (HTTPURLResponse, Data) {
        (
            HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!,
            Data(body.utf8)
        )
    }

    static func jsonObject(from request: URLRequest) throws -> [String: Any] {
        let data = try XCTUnwrap(
            request.httpBodyStream.flatMap(Self.readBody) ?? request.httpBody
        )
        return try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    static func readBody(_ stream: InputStream) -> Data {
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

private extension GeneratedClientStubbedServerTests {
    func makeClient() -> ColorMatchingOpenAPI.Client {
        ColorMatchingOpenAPI.Client(
            serverURL: Self.serverURL,
            transport: URLSessionTransport(configuration: .init(session: Self.stubbedSession()))
        )
    }

    func fetchManifest() async throws -> Components.Schemas.TestSheetManifest {
        let output = try await makeClient().getTestSheetManifest(
            .init(path: .init(sheetId: "lps-7f3k"))
        )
        guard case .ok(let ok) = output else { throw StubError.unexpectedResponse }
        return try ok.body.json
    }

    static func stubManifestResponse() {
        OpenAPIStubURLProtocol.handler = { request in
            Self.okResponse(request, Self.manifestJSON)
        }
    }

    func captureRequestForManifestFetch() async throws -> URLRequest {
        var capturedRequest: URLRequest?
        OpenAPIStubURLProtocol.handler = { request in
            capturedRequest = request
            return Self.okResponse(request, Self.manifestJSON)
        }
        _ = try await fetchManifest()
        return try XCTUnwrap(capturedRequest)
    }
}

#else
import XCTest

/// Red-phase marker: fails until the generated client module exists.
final class GeneratedClientAvailabilityTests: XCTestCase {
    func testGeneratedOpenAPIClientModuleExists() {
        XCTFail(
            "ColorMatchingOpenAPI module not found: add the swift-openapi-generator plugin, " +
                "vendor iOS/OpenAPI/color-matching-v1.json, and add the generated client target " +
                "per docs/openapi-client-generation.md (issue #5)."
        )
    }
}
#endif
