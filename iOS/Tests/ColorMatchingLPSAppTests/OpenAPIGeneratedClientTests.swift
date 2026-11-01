import Foundation
import XCTest

// Issue #5 red-phase gate: the tests below exercise the generated OpenAPI client
// (swift-openapi-generator output, module `OpenAPIGenerated`) against local stubbed
// responses. They compile only once that target is wired into the package; the
// sentinel test below fails until then. Conventions are pinned in
// docs/openapi-generated-client-test-plan.md.
#if canImport(OpenAPIGenerated)
import OpenAPIGenerated
import OpenAPIRuntime
#endif

final class OpenAPIGeneratedClientTests: XCTestCase {
    override func tearDown() {
        StubURLProtocol.handler = nil
        StubURLProtocol.lastRequest = nil
        StubURLProtocol.lastBody = nil
        super.tearDown()
    }

    func testGeneratedClientModuleIsWiredIntoPackage() throws {
        #if canImport(OpenAPIGenerated)
        // Generated client target exists; the stubbed-response tests below are active.
        #else
        XCTFail("OpenAPIGenerated target is not wired into ColorMatchingLPSAppTests yet (issue #5: generated OpenAPI client missing)")
        #endif
    }

    #if canImport(OpenAPIGenerated)
    private let serverURL = URL(string: "https://example.test")!

    func testFetchTestSheetManifestDecodesDocumentedManifest() async throws {
        stub(statusCode: 200, json: Self.manifestJSON)

        let response = try await makeClient().fetchTestSheetManifest(
            .init(path: .init(sheetId: "sheet_1"))
        )

        guard case let .ok(ok) = response else {
            return XCTFail("Expected 200 ok for manifest fetch, got: \(response)")
        }
        guard case let .json(manifest) = ok.body else {
            return XCTFail("Expected JSON body for manifest fetch")
        }
        XCTAssertEqual(manifest.schemaVersion, "lps-sheet-manifest/v1")
        XCTAssertEqual(manifest.sheetId, "sheet_1")
        XCTAssertEqual(manifest.patches.count, 2)
        XCTAssertEqual(manifest.pairs.first?.id, "pair_1")
        XCTAssertEqual(StubURLProtocol.lastRequest?.httpMethod, "GET")
        XCTAssertEqual(StubURLProtocol.lastRequest?.url?.path, "/api/v1/test_sheets/sheet_1/manifest")
    }

    func testFetchRecentSheetsDecodesSheetsIncludingNullTitle() async throws {
        stub(statusCode: 200, json: Self.recentSheetsJSON)

        let response = try await makeClient().fetchRecentTestSheets(.init())

        guard case let .ok(ok) = response else {
            return XCTFail("Expected 200 ok for recent sheets fetch, got: \(response)")
        }
        guard case let .json(payload) = ok.body else {
            return XCTFail("Expected JSON body for recent sheets fetch")
        }
        XCTAssertEqual(payload.sheets.count, 2)
        XCTAssertEqual(payload.sheets.first?.sheetId, "sheet_1")
        XCTAssertNil(payload.sheets.first?.title)
        XCTAssertEqual(payload.sheets.last?.title, "July LPS comparison sheet")
        XCTAssertEqual(StubURLProtocol.lastRequest?.url?.path, "/api/v1/test_sheets/recent")
    }

    func testCreateCaptureSessionPostsMetadataQualityAndDecodesCaptureID() async throws {
        stub(statusCode: 201, json: #"{"capture_id":"cap_1"}"#)

        let metadata = try Self.decode(Components.Schemas.CaptureMetadata.self, from: Self.captureMetadataJSON)
        let quality = try Self.decode(Components.Schemas.CaptureQuality.self, from: Self.captureQualityJSON)
        let response = try await makeClient().createCaptureSession(
            .init(
                path: .init(sheetId: "sheet_1"),
                body: .json(Components.Schemas.CreateCaptureSessionRequest(metadata: metadata, quality: quality))
            )
        )

        guard case let .created(created) = response else {
            return XCTFail("Expected 201 created for capture session creation, got: \(response)")
        }
        guard case let .json(payload) = created.body else {
            return XCTFail("Expected JSON body for capture session creation")
        }
        XCTAssertEqual(payload.captureId, "cap_1")
        XCTAssertEqual(StubURLProtocol.lastRequest?.httpMethod, "POST")
        XCTAssertEqual(StubURLProtocol.lastRequest?.url?.path, "/api/v1/test_sheets/sheet_1/captures")
        XCTAssertEqual(StubURLProtocol.lastRequest?.value(forHTTPHeaderField: "Content-Type"), "application/json")
        let json = try XCTUnwrap(Self.jsonObject(from: StubURLProtocol.lastBody) as? [String: Any])
        let metadataPayload = try XCTUnwrap(json["metadata"] as? [String: Any])
        XCTAssertEqual(metadataPayload["device_model"] as? String, "iPhone 15 Pro")
        XCTAssertEqual(metadataPayload["image_width"] as? Int, 4032)
        let qualityPayload = try XCTUnwrap(json["quality"] as? [String: Any])
        XCTAssertEqual(qualityPayload["detected_marker_count"] as? Int, 4)
        XCTAssertEqual(qualityPayload["rejections"] as? [String], [])
    }

    func testUploadMeasurementsPostsAlgorithmVersionMeasurementsAndScores() async throws {
        stub(statusCode: 204)

        let measurement = try Self.decode(Components.Schemas.MeasurementUpload.self, from: Self.measurementJSON)
        let score = try Self.decode(Components.Schemas.PairScoreUpload.self, from: Self.pairScoreJSON)
        let response = try await makeClient().uploadMeasurements(
            .init(
                path: .init(captureId: "cap_1"),
                body: .json(Components.Schemas.MeasurementUploadRequest(
                    scoringAlgorithmVersion: "lps-distance-v1",
                    measurements: [measurement],
                    pairScores: [score]
                ))
            )
        )

        guard case .noContent = response else {
            return XCTFail("Expected 204 no content for measurement upload, got: \(response)")
        }
        XCTAssertEqual(StubURLProtocol.lastRequest?.url?.path, "/api/v1/captures/cap_1/measurements")
        let json = try XCTUnwrap(Self.jsonObject(from: StubURLProtocol.lastBody) as? [String: Any])
        XCTAssertEqual(json["scoring_algorithm_version"] as? String, "lps-distance-v1")
        let measurementPayload = try XCTUnwrap((json["measurements"] as? [[String: Any]])?.first)
        XCTAssertEqual(measurementPayload["patch_id"] as? String, "patch_1")
        let statsPayload = try XCTUnwrap(measurementPayload["stats"] as? [String: Any])
        XCTAssertEqual(Set(statsPayload.keys), ["sample_count", "clipping_fraction", "mean", "standard_deviation"])
        let scorePayload = try XCTUnwrap((json["pair_scores"] as? [[String: Any]])?.first)
        XCTAssertEqual(scorePayload["pair_id"] as? String, "pair_1")
        XCTAssertEqual(scorePayload["algorithm_version"] as? String, "lps-distance-v1")
    }

    func testUploadJudgmentsPostsDocumentedJudgments() async throws {
        stub(statusCode: 204)

        let judgments = try Self.decode([Components.Schemas.PairJudgment].self, from: Self.judgmentsJSON)
        let response = try await makeClient().uploadJudgments(
            .init(
                path: .init(captureId: "cap_1"),
                body: .json(Components.Schemas.JudgmentUploadRequest(judgments: judgments))
            )
        )

        guard case .noContent = response else {
            return XCTFail("Expected 204 no content for judgment upload, got: \(response)")
        }
        XCTAssertEqual(StubURLProtocol.lastRequest?.httpMethod, "POST")
        XCTAssertEqual(StubURLProtocol.lastRequest?.url?.path, "/api/v1/captures/cap_1/judgments")
        let json = try XCTUnwrap(Self.jsonObject(from: StubURLProtocol.lastBody) as? [String: Any])
        let judgmentPayload = try XCTUnwrap((json["judgments"] as? [[String: Any]])?.first)
        XCTAssertEqual(judgmentPayload["pair_id"] as? String, "pair_1")
        XCTAssertEqual(judgmentPayload["judgment"] as? String, "near_match")
    }

    func testFetchRankedResultsDecodesScoresAndAlgorithmVersion() async throws {
        stub(statusCode: 200, json: Self.rankedResultsJSON)

        let response = try await makeClient().fetchRankedResults(
            .init(path: .init(sheetId: "sheet_1"))
        )

        guard case let .ok(ok) = response else {
            return XCTFail("Expected 200 ok for ranked results fetch, got: \(response)")
        }
        guard case let .json(payload) = ok.body else {
            return XCTFail("Expected JSON body for ranked results fetch")
        }
        XCTAssertEqual(payload.sheetId, "sheet_1")
        XCTAssertEqual(payload.scoringAlgorithmVersion, "lps-distance-v1")
        let topResult = try XCTUnwrap(payload.results.first)
        XCTAssertEqual(topResult.pairId, "pair_1")
        XCTAssertEqual(topResult.rank, 1)
        XCTAssertEqual(topResult.distance, 0.035, accuracy: 0.0001)
        XCTAssertEqual(StubURLProtocol.lastRequest?.url?.path, "/api/v1/test_sheets/sheet_1/ranked_results")
    }

    func testFetchManifestSurfacesErrorForUndeclaredNotFoundStatus() async throws {
        stub(statusCode: 404, json: #"{"error":"not_found"}"#)

        await XCTAssertThrowsError(
            try await makeClient().fetchTestSheetManifest(.init(path: .init(sheetId: "missing_sheet")))
        )
    }

    private func makeClient() -> OpenAPIGenerated.Client {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return OpenAPIGenerated.Client(
            serverURL: serverURL,
            transport: URLSessionTransport(configuration: configuration)
        )
    }

    private func stub(statusCode: Int, json: String = "") {
        StubURLProtocol.handler = { request in
            let headers = json.isEmpty ? nil : ["Content-Type": "application/json"]
            return (
                HTTPURLResponse(url: request.url!, statusCode: statusCode, httpVersion: nil, headerFields: headers)!,
                Data(json.utf8)
            )
        }
    }

    private static func decode<T: Decodable>(_ type: T.Type, from json: String) throws -> T {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(type, from: Data(json.utf8))
    }

    private static func jsonObject(from data: Data?) throws -> Any {
        try JSONSerialization.jsonObject(with: XCTUnwrap(data))
    }

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
        },
        {
          "id": "patch_2",
          "role": "pair_color",
          "pair_id": "pair_1",
          "pair_side": "second",
          "reference_role": null,
          "source_color": "#00FF00",
          "safe_inset_mm": 1.5,
          "rect": {"x": 16, "y": 52, "width": 16, "height": 10}
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
          "title": null
        },
        {
          "sheet_id": "sheet_2",
          "manifest_url": "https://example.test/api/v1/test_sheets/sheet_2/manifest",
          "title": "July LPS comparison sheet"
        }
      ]
    }
    """

    private static let captureMetadataJSON = """
    {
      "device_model": "iPhone 15 Pro",
      "lens": "built_in_wide_angle",
      "exposure_duration_seconds": 0.016,
      "iso": 100,
      "focus_lens_position": 0.42,
      "white_balance_gains": {"red": 1.2, "green": 1.0, "blue": 1.4},
      "image_width": 4032,
      "image_height": 3024,
      "app_version": "0.1.0",
      "timestamp": "2026-07-25T12:00:00Z"
    }
    """

    private static let captureQualityJSON = """
    {
      "detected_marker_count": 4,
      "blur_score": 0.82,
      "rejections": []
    }
    """

    private static let measurementJSON = """
    {
      "patch_id": "patch_1",
      "linear_rgb_median": {"r": 0.12, "g": 0.1, "b": 0.02},
      "normalized_linear_rgb_median": {"r": 0.15, "g": 0.12, "b": 0.02},
      "stats": {
        "sample_count": 900,
        "clipping_fraction": 0.0,
        "mean": {"r": 0.12, "g": 0.1, "b": 0.02},
        "standard_deviation": {"r": 0.01, "g": 0.01, "b": 0.004}
      }
    }
    """

    private static let pairScoreJSON = """
    {
      "pair_id": "pair_1",
      "distance": 0.035,
      "similarity": 0.965,
      "algorithm_version": "lps-distance-v1"
    }
    """

    private static let judgmentsJSON = """
    [
      {"pair_id": "pair_1", "judgment": "near_match"}
    ]
    """

    private static let rankedResultsJSON = """
    {
      "sheet_id": "sheet_1",
      "scoring_algorithm_version": "lps-distance-v1",
      "results": [
        {"pair_id": "pair_1", "distance": 0.035, "similarity": 0.965, "rank": 1}
      ]
    }
    """
    #endif
}

private final class StubURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?
    static var lastRequest: URLRequest?
    static var lastBody: Data?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        Self.lastRequest = request
        Self.lastBody = request.httpBodyStream.flatMap(Self.readBody) ?? request.httpBody
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
