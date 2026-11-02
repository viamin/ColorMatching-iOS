import Foundation
import XCTest
#if canImport(ColorMatchingOpenAPI)
import ColorMatchingOpenAPI
#endif
#if canImport(OpenAPIRuntime)
import OpenAPIRuntime
#endif

#if canImport(ColorMatchingOpenAPI) && canImport(OpenAPIRuntime)
final class OpenAPIClientStubbedResponseTests: XCTestCase {
    override func tearDown() {
        OpenAPIStubURLProtocol.handler = nil
        super.tearDown()
    }

    func testGetTestSheetManifestDecodesContractFields() async throws {
        var capturedRequest: URLRequest?
        OpenAPIStubURLProtocol.handler = { request in
            capturedRequest = request
            return Self.ok(Self.manifestJSON)
        }

        let response = try await makeClient().getTestSheetManifest(.init(path: .init(sheet_id: "sheet_1")))

        XCTAssertEqual(capturedRequest?.url?.path, "/api/v1/test_sheets/sheet_1/manifest")
        XCTAssertEqual(capturedRequest?.httpMethod, "GET")
        guard case .ok(let ok) = response else {
            return XCTFail("Expected 200 response for manifest fetch")
        }
        guard case .json(let manifest) = ok.body else {
            return XCTFail("Expected JSON body for manifest fetch")
        }
        XCTAssertEqual(manifest.schema_version, "lps-sheet-manifest/v1")
        XCTAssertEqual(manifest.sheet_version, "lps-letter-grid-v1")
        XCTAssertEqual(manifest.sheet_id, "sheet_1")
        XCTAssertEqual(manifest.page.units, "mm")
        XCTAssertEqual(manifest.page.width, 215.9, accuracy: 0.001)
        XCTAssertEqual(manifest.registration_markers.first?.role, "top_left")
        XCTAssertEqual(manifest.registration_markers.first?.rect.width ?? 0, 8, accuracy: 0.001)
        XCTAssertEqual(manifest.patches.first?.role, .pair_color)
        XCTAssertEqual(manifest.patches.first?.source_color, "#FF0000")
        XCTAssertEqual(manifest.patches.first?.safe_inset_mm ?? 0, 1.5, accuracy: 0.001)
        XCTAssertEqual(manifest.pairs.first?.grid_row, 0)
        XCTAssertEqual(manifest.printer_profile.name, "Research printer")
        XCTAssertEqual(manifest.capture_profile.expected_illuminant, "low_pressure_sodium")
    }

    func testListRecentTestSheetsDecodesSheetsAndNullableTitle() async throws {
        OpenAPIStubURLProtocol.handler = { _ in Self.ok(Self.recentSheetsJSON) }

        let response = try await makeClient().listRecentTestSheets(.init())

        guard case .ok(let ok) = response else {
            return XCTFail("Expected 200 response for recent sheets")
        }
        guard case .json(let body) = ok.body else {
            return XCTFail("Expected JSON body for recent sheets")
        }
        XCTAssertEqual(body.sheets.count, 2)
        XCTAssertEqual(body.sheets.first?.sheet_id, "sheet_1")
        XCTAssertEqual(body.sheets.first?.title, "July LPS comparison sheet")
        XCTAssertEqual(body.sheets.first?.manifest_url, "https://example.test/api/v1/test_sheets/sheet_1/manifest")
        XCTAssertEqual(body.sheets.last?.sheet_id, "sheet_2")
        XCTAssertEqual(body.sheets.last?.title, nil)
    }

    func testCreateCaptureEncodesMetadataAndQuality() async throws {
        var capturedRequest: URLRequest?
        var capturedBody: Data?
        OpenAPIStubURLProtocol.handler = { request in
            capturedRequest = request
            capturedBody = request.httpBodyStream.flatMap(Self.readBody) ?? request.httpBody
            return Self.created(#"{"capture_id": "cap_1"}"#)
        }

        let response = try await makeClient().createCapture(
            .init(
                path: .init(sheet_id: "sheet_1"),
                body: .json(
                    .init(
                        metadata: .init(
                            device_model: "iPhone",
                            lens: "built_in_wide_angle",
                            exposure_duration_seconds: 0.016,
                            iso: 100,
                            focus_lens_position: 0.42,
                            white_balance_gains: .init(red: 1.2, green: 1.0, blue: 1.4),
                            image_width: 4032,
                            image_height: 3024,
                            app_version: "0.1.0",
                            timestamp: Self.captureTimestamp
                        ),
                        quality: .init(detected_marker_count: 4, blur_score: 0.82, rejections: [])
                    )
                )
            )
        )

        XCTAssertEqual(capturedRequest?.url?.path, "/api/v1/test_sheets/sheet_1/captures")
        XCTAssertEqual(capturedRequest?.httpMethod, "POST")
        XCTAssertEqual(capturedRequest?.value(forHTTPHeaderField: "Content-Type"), "application/json")
        let json = try XCTUnwrap(Self.jsonObject(from: capturedBody) as? [String: Any])
        let metadata = try XCTUnwrap(json["metadata"] as? [String: Any])
        XCTAssertEqual(metadata["device_model"] as? String, "iPhone")
        XCTAssertEqual(metadata["image_width"] as? Int, 4032)
        let gains = try XCTUnwrap(metadata["white_balance_gains"] as? [String: Double])
        XCTAssertEqual(gains["red"] ?? 0, 1.2, accuracy: 0.0001)
        let quality = try XCTUnwrap(json["quality"] as? [String: Any])
        XCTAssertEqual(quality["detected_marker_count"] as? Int, 4)
        XCTAssertEqual(quality["rejections"] as? [String], [])
        guard case .created(let created) = response else {
            return XCTFail("Expected 201 response for capture creation")
        }
        guard case .json(let body) = created.body else {
            return XCTFail("Expected JSON body for capture creation")
        }
        XCTAssertEqual(body.capture_id, "cap_1")
    }

    func testUploadMeasurementsEncodesScoresWithAlgorithmVersion() async throws {
        var capturedRequest: URLRequest?
        var capturedBody: Data?
        OpenAPIStubURLProtocol.handler = { request in
            capturedRequest = request
            capturedBody = request.httpBodyStream.flatMap(Self.readBody) ?? request.httpBody
            return Self.noContent()
        }

        let response = try await makeClient().uploadMeasurements(
            .init(
                path: .init(capture_id: "cap_1"),
                body: .json(
                    .init(
                        scoring_algorithm_version: "lps-distance-v1",
                        measurements: [
                            .init(
                                patch_id: "patch_1",
                                linear_rgb_median: .init(r: 0.12, g: 0.10, b: 0.02),
                                normalized_linear_rgb_median: .init(r: 0.15, g: 0.12, b: 0.02),
                                stats: .init(
                                    sample_count: 900,
                                    clipping_fraction: 0.0,
                                    mean: .init(r: 0.12, g: 0.10, b: 0.02),
                                    standard_deviation: .init(r: 0.01, g: 0.01, b: 0.004)
                                )
                            )
                        ],
                        pair_scores: [
                            .init(pair_id: "pair_1", distance: 0.035, similarity: 0.965, algorithm_version: "lps-distance-v1")
                        ]
                    )
                )
            )
        )

        XCTAssertEqual(capturedRequest?.url?.path, "/api/v1/captures/cap_1/measurements")
        XCTAssertEqual(capturedRequest?.httpMethod, "POST")
        let json = try XCTUnwrap(Self.jsonObject(from: capturedBody) as? [String: Any])
        XCTAssertEqual(json["scoring_algorithm_version"] as? String, "lps-distance-v1")
        let measurement = try XCTUnwrap((json["measurements"] as? [[String: Any]])?.first)
        XCTAssertEqual(measurement["patch_id"] as? String, "patch_1")
        let stats = try XCTUnwrap(measurement["stats"] as? [String: Any])
        XCTAssertEqual(Set(stats.keys), ["sample_count", "clipping_fraction", "mean", "standard_deviation"])
        let pairScore = try XCTUnwrap((json["pair_scores"] as? [[String: Any]])?.first)
        XCTAssertEqual(pairScore["pair_id"] as? String, "pair_1")
        XCTAssertEqual(pairScore["similarity"] as? Double ?? -1, 0.965, accuracy: 0.0001)
        guard case .noContent = response else {
            return XCTFail("Expected 204 response for measurement upload")
        }
    }

    func testUploadJudgmentsEncodesTypedJudgments() async throws {
        var capturedRequest: URLRequest?
        var capturedBody: Data?
        OpenAPIStubURLProtocol.handler = { request in
            capturedRequest = request
            capturedBody = request.httpBodyStream.flatMap(Self.readBody) ?? request.httpBody
            return Self.noContent()
        }

        let response = try await makeClient().uploadJudgments(
            .init(
                path: .init(capture_id: "cap_1"),
                body: .json(.init(judgments: [.init(pair_id: "pair_1", judgment: .near_match)]))
            )
        )

        XCTAssertEqual(capturedRequest?.url?.path, "/api/v1/captures/cap_1/judgments")
        XCTAssertEqual(capturedRequest?.httpMethod, "POST")
        let json = try XCTUnwrap(Self.jsonObject(from: capturedBody) as? [String: Any])
        let judgment = try XCTUnwrap((json["judgments"] as? [[String: Any]])?.first)
        XCTAssertEqual(judgment["pair_id"] as? String, "pair_1")
        XCTAssertEqual(judgment["judgment"] as? String, "near_match")
        guard case .noContent = response else {
            return XCTFail("Expected 204 response for judgment upload")
        }
    }

    func testGetRankedResultsDecodesRankedPairs() async throws {
        OpenAPIStubURLProtocol.handler = { _ in Self.ok(Self.rankedResultsJSON) }

        let response = try await makeClient().getRankedResults(.init(path: .init(sheet_id: "sheet_1")))

        guard case .ok(let ok) = response else {
            return XCTFail("Expected 200 response for ranked results")
        }
        guard case .json(let ranked) = ok.body else {
            return XCTFail("Expected JSON body for ranked results")
        }
        XCTAssertEqual(ranked.sheet_id, "sheet_1")
        XCTAssertEqual(ranked.capture_id, "cap_1")
        XCTAssertEqual(ranked.scoring_algorithm_version, "lps-distance-v1")
        XCTAssertEqual(ranked.printer_profile.name, "Research printer")
        XCTAssertEqual(ranked.ranked_pairs.count, 2)
        XCTAssertEqual(ranked.ranked_pairs.first?.rank, 1)
        XCTAssertEqual(ranked.ranked_pairs.first?.judgment, .near_match)
        XCTAssertEqual(ranked.ranked_pairs.last?.judgment, nil)
        XCTAssertEqual(ranked.ranked_pairs.first?.source_colors, ["#FF0000", "#00FF00"])
        XCTAssertEqual(ranked.ranked_pairs.first?.distance ?? 0, 0.035, accuracy: 0.0001)
    }

    func testBearerTokenMiddlewareAppliesAuthorizationHeader() async throws {
        var capturedRequest: URLRequest?
        OpenAPIStubURLProtocol.handler = { request in
            capturedRequest = request
            return Self.ok(Self.recentSheetsJSON)
        }

        let client = Client(
            serverURL: Self.baseURL,
            transport: URLSessionTransport(configuration: .init(session: Self.stubSession())),
            middlewares: [BearerTokenMiddleware(token: "token")]
        )
        _ = try await client.listRecentTestSheets(.init())

        XCTAssertEqual(capturedRequest?.value(forHTTPHeaderField: "Authorization"), "Bearer token")
    }

    private func makeClient() -> Client {
        Client(
            serverURL: Self.baseURL,
            transport: URLSessionTransport(configuration: .init(session: Self.stubSession()))
        )
    }

    private static let baseURL = URL(string: "https://example.test")!

    private static let captureTimestamp = Date(timeIntervalSince1970: 1_784_987_200)

    private static let manifestJSON = """
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
    """

    private static let recentSheetsJSON = """
    {
      "sheets": [
        {
          "sheet_id": "sheet_1",
          "manifest_url": "https://example.test/api/v1/test_sheets/sheet_1/manifest",
          "title": "July LPS comparison sheet"
        },
        {
          "sheet_id": "sheet_2",
          "manifest_url": "https://example.test/api/v1/test_sheets/sheet_2/manifest",
          "title": null
        }
      ]
    }
    """

    private static let rankedResultsJSON = """
    {
      "sheet_id": "sheet_1",
      "capture_id": "cap_1",
      "scoring_algorithm_version": "lps-distance-v1",
      "printer_profile": {"id": "printer_profile_1", "name": "Research printer"},
      "ranked_pairs": [
        {
          "pair_id": "pair_1",
          "rank": 1,
          "distance": 0.035,
          "similarity": 0.965,
          "source_colors": ["#FF0000", "#00FF00"],
          "judgment": "near_match"
        },
        {
          "pair_id": "pair_2",
          "rank": 2,
          "distance": 0.18,
          "similarity": 0.82,
          "source_colors": ["#0000FF", "#00FF00"],
          "judgment": null
        }
      ]
    }
    """

    private static func stubSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [OpenAPIStubURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    private static func ok(_ body: String) -> (HTTPURLResponse, Data) {
        (
            HTTPURLResponse(
                url: baseURL,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!,
            Data(body.utf8)
        )
    }

    private static func created(_ body: String) -> (HTTPURLResponse, Data) {
        (
            HTTPURLResponse(
                url: baseURL,
                statusCode: 201,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!,
            Data(body.utf8)
        )
    }

    private static func noContent() -> (HTTPURLResponse, Data) {
        (HTTPURLResponse(url: baseURL, statusCode: 204, httpVersion: nil, headerFields: nil)!, Data())
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
}

private struct BearerTokenMiddleware: ClientMiddleware {
    let token: String

    func send(
        _ request: inout Request,
        baseURL: URL,
        operation: Operation,
        next: @Sendable (inout Request, URL) async throws -> Response
    ) async throws -> Response {
        request.headerFields.append(.init(name: "Authorization", value: "Bearer \(token)"))
        return try await next(&request, baseURL, operation)
    }
}

private final class OpenAPIStubURLProtocol: URLProtocol {
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
#endif
