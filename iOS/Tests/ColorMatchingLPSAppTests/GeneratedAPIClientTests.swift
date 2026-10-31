import ColorMatchingOpenAPI
import Foundation
import MeasurementCore
import XCTest
@testable import ColorMatchingLPSAppCore

final class GeneratedAPIClientTests: XCTestCase {
    private let base = URL(string: "https://example.test")!

    override func tearDown() {
        StubURLProtocol.handler = nil
        super.tearDown()
    }

    func testFetchManifestSurfacesSpecGuaranteedAndBeyondSpecFields() async throws {
        let stub = StubURLProtocol.record(status: 200, body: Self.manifestJSON)

        let manifest = try await makeClient().fetchManifest(
            from: base.appending(path: "api/v1/test_sheets/sheet_1/manifest")
        )

        XCTAssertEqual(stub.request?.url?.path, "/api/v1/test_sheets/sheet_1/manifest")
        XCTAssertEqual(stub.request?.value(forHTTPHeaderField: "Authorization"), "Bearer token")
        XCTAssertEqual(manifest.schemaVersion, "lps-sheet-manifest/v1")
        XCTAssertEqual(manifest.sheetID, "sheet_1")
        XCTAssertEqual(manifest.scoringAlgorithmVersion, "lps-distance-v1")
        XCTAssertEqual(manifest.patches.first?.id, "patch_1")
        XCTAssertEqual(manifest.pairs.first?.id, "pair_1")
    }

    func testFetchManifestThrowsOnDocumentedNotFound() async throws {
        _ = StubURLProtocol.record(status: 404, body: #"{"errors":{"detail":"Sheet not found"}}"#)

        do {
            _ = try await makeClient().fetchManifest(
                from: base.appending(path: "api/v1/test_sheets/missing/manifest")
            )
            XCTFail("Expected a documented 404 to surface as an error")
        } catch {}
    }

    func testFetchRecentSheetsReturnsGeneratedTypes() async throws {
        let stub = StubURLProtocol.record(
            status: 200,
            body: #"{"sheets":[{"sheet_id":"sheet_1","manifest_url":"https://example.test/api/v1/test_sheets/sheet_1/manifest","title":null},{"sheet_id":"sheet_2","manifest_url":"https://example.test/api/v1/test_sheets/sheet_2/manifest","title":"July sheet"}]}"#
        )

        let response: Components.Schemas.RecentSheetsResponse = try await makeClient()
            .fetchRecentSheets(baseURL: base)

        XCTAssertEqual(stub.request?.url?.path, "/api/v1/test_sheets/recent")
        XCTAssertEqual(response.sheets.map(\.sheetId), ["sheet_1", "sheet_2"])
        XCTAssertEqual(response.sheets.first?.title, nil)
        XCTAssertEqual(response.sheets.last?.title, "July sheet")
        XCTAssertEqual(
            response.sheets.first?.manifestUrl,
            "https://example.test/api/v1/test_sheets/sheet_1/manifest"
        )
    }

    func testCreateCapturePostsSpecRequestBodyAndReturnsGeneratedTypes() async throws {
        let stub = StubURLProtocol.record(status: 201, body: #"{"capture_id":"cap_1"}"#)

        let response: Components.Schemas.CaptureCreatedResponse = try await makeClient()
            .createCapture(
                sheetID: "sheet_1",
                baseURL: base,
                metadata: CaptureMetadata(
                    deviceModel: "iPhone",
                    lens: "wide",
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

        XCTAssertEqual(response.captureId, "cap_1")
        XCTAssertEqual(stub.request?.url?.path, "/api/v1/test_sheets/sheet_1/captures")
        XCTAssertTrue(
            (stub.request?.value(forHTTPHeaderField: "Content-Type") ?? "").contains("application/json")
        )
        let json = try Self.jsonObject(from: stub.body)
        let metadata = try XCTUnwrap(json["metadata"] as? [String: Any])
        XCTAssertEqual(metadata["device_model"] as? String, "iPhone")
        XCTAssertEqual(metadata["lens"] as? String, "wide")
        XCTAssertEqual(metadata["image_width"] as? Int, 4032)
        XCTAssertEqual(metadata["image_height"] as? Int, 3024)
        XCTAssertEqual(metadata["app_version"] as? String, "0.1.0")
        XCTAssertEqual(metadata["timestamp"] as? String, "1970-01-01T00:00:00Z")
        let quality = try XCTUnwrap(json["quality"] as? [String: Any])
        XCTAssertEqual(quality["detected_marker_count"] as? Int, 4)
        XCTAssertEqual(quality["rejections"] as? [String], [])
    }

    func testUploadMeasurementsReturnsGeneratedCountedResponse() async throws {
        let stub = StubURLProtocol.record(
            status: 200,
            body: #"{"capture_id":"cap_1","measurement_count":1,"pair_score_count":1}"#
        )

        let response: Components.Schemas.MeasurementUploadResponse = try await makeClient()
            .uploadMeasurements(
                captureID: "cap_1",
                baseURL: base,
                measurements: [Self.measurement],
                scores: [
                    PairScore(
                        pairID: "pair_1",
                        distance: 0.1,
                        similarity: 0.9,
                        algorithmVersion: "lps-distance-v1"
                    )
                ]
            )

        XCTAssertEqual(response.captureId, "cap_1")
        XCTAssertEqual(response.measurementCount, 1)
        XCTAssertEqual(response.pairScoreCount, 1)
        XCTAssertEqual(stub.request?.url?.path, "/api/v1/captures/cap_1/measurements")
        let json = try Self.jsonObject(from: stub.body)
        XCTAssertNil(
            json["scoring_algorithm_version"],
            "Published spec moved the algorithm version onto each pair score"
        )
        let measurement = try XCTUnwrap((json["measurements"] as? [[String: Any]])?.first)
        XCTAssertEqual(measurement["patch_id"] as? String, "patch_1")
        XCTAssertEqual((measurement["linear_rgb_median"] as? [String: Any])?["r"] as? Double, 0.2)
        XCTAssertNotNil(measurement["normalized_linear_rgb_median"])
        let pairScore = try XCTUnwrap((json["pair_scores"] as? [[String: Any]])?.first)
        XCTAssertEqual(pairScore["pair_id"] as? String, "pair_1")
        XCTAssertEqual(pairScore["algorithm_version"] as? String, "lps-distance-v1")
        XCTAssertNotNil(pairScore["distance"])
        XCTAssertNotNil(pairScore["similarity"])
    }

    func testUploadJudgmentsReturnsGeneratedCountedResponse() async throws {
        let stub = StubURLProtocol.record(
            status: 200,
            body: #"{"capture_id":"cap_1","judgment_count":1}"#
        )

        let response: Components.Schemas.JudgmentUploadResponse = try await makeClient()
            .uploadJudgments(
                captureID: "cap_1",
                baseURL: base,
                judgments: [PairJudgment(pairID: "pair_1", judgment: "near_match")]
            )

        XCTAssertEqual(response.captureId, "cap_1")
        XCTAssertEqual(response.judgmentCount, 1)
        XCTAssertEqual(stub.request?.url?.path, "/api/v1/captures/cap_1/judgments")
        let json = try Self.jsonObject(from: stub.body)
        let judgment = try XCTUnwrap((json["judgments"] as? [[String: Any]])?.first)
        XCTAssertEqual(judgment["pair_id"] as? String, "pair_1")
        XCTAssertEqual(judgment["judgment"] as? String, "near_match")
    }

    func testFetchRankedResultsReturnsGeneratedTypes() async throws {
        let stub = StubURLProtocol.record(
            status: 200,
            body: #"{"schema_version":"lps-ranked-results/v1","sheet_id":"sheet_1"}"#
        )

        let response: Components.Schemas.RankedResults = try await makeClient()
            .fetchRankedResults(sheetID: "sheet_1", baseURL: base)

        XCTAssertEqual(stub.request?.url?.path, "/api/v1/test_sheets/sheet_1/ranked_results")
        XCTAssertEqual(response.sheetId, "sheet_1")
    }

    private func makeClient() -> APIClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return APIClient(token: "token", session: URLSession(configuration: configuration))
    }

    private static var measurement: PatchMeasurement {
        let rgb = RGB(r: 0.2, g: 0.3, b: 0.4)
        return PatchMeasurement(
            patchID: "patch_1",
            linearRGBMedian: rgb,
            normalizedLinearRGBMedian: rgb,
            stats: ChannelStats(
                median: rgb,
                mean: rgb,
                standardDeviation: RGB(r: 0.01, g: 0.01, b: 0.01),
                min: rgb,
                max: rgb,
                sampleCount: 900,
                clippingFraction: 0
            )
        )
    }

    private static func jsonObject(from data: Data?) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(data)) as? [String: Any])
    }

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
    """#
}

private final class StubURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    static func record(status: Int, body: String) -> Recording {
        let recording = Recording()
        handler = { request in
            recording.request = request
            recording.body = request.httpBodyStream.flatMap(Self.read) ?? request.httpBody
            return (
                HTTPURLResponse(
                    url: request.url!,
                    statusCode: status,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "application/json"]
                )!,
                Data(body.utf8)
            )
        }
        return recording
    }

    final class Recording {
        var request: URLRequest?
        var body: Data?
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
