import Foundation
import MeasurementCore
import XCTest
import ColorMatchingLPSAppCore

/// Wire-contract regression net for issue #5 (generated OpenAPI client migration).
///
/// These tests pin the observable wire behavior of the public API surface using
/// response fixtures shaped like the published `color_matching` API
/// (viamin/color_matching#110, delivered upstream in PR #113). The generated
/// client swap must keep every test here green; any intentional wire change
/// must arrive as a visible diff alongside the regenerated client and be
/// recorded in the PR description per docs/openapi-client-migration.md.
final class APIClientWireContractTests: XCTestCase {
    override func tearDown() {
        WireContractURLProtocol.handler = nil
        super.tearDown()
    }

    func testFetchManifestBySheetCodeRequestsManifestRouteAndDecodesPublishedManifest() async throws {
        var capturedRequest: URLRequest?
        WireContractURLProtocol.handler = { request in
            capturedRequest = request
            return (Self.httpResponse(request, status: 200), Data(Self.manifestJSON.utf8))
        }

        let manifest = try await makeClient(token: "token").fetchManifest(
            baseURL: URL(string: "https://example.test")!,
            sheetCode: "sheet_123"
        )

        XCTAssertEqual(capturedRequest?.httpMethod, "GET")
        XCTAssertEqual(capturedRequest?.url?.path, "/api/v1/test_sheets/sheet_123/manifest")
        XCTAssertEqual(capturedRequest?.value(forHTTPHeaderField: "Authorization"), "Bearer token")
        XCTAssertEqual(manifest.schemaVersion, "lps-sheet-manifest/v1")
        XCTAssertEqual(manifest.sheetID, "sheet_123")
        XCTAssertEqual(manifest.page.units, "mm")
        XCTAssertEqual(manifest.registrationMarkers.first?.role, "top_left")
        XCTAssertEqual(manifest.patches.map(\.id), ["pair_1#first", "pair_1#second"])
        XCTAssertEqual(manifest.patches.first?.sourceColor, "#FF0000")
        XCTAssertEqual(manifest.patches.first?.safeInsetMM, 1.5)
        XCTAssertEqual(manifest.pairs.first?.sourceColors, ["#FF0000", "#00FF00"])
        XCTAssertEqual(manifest.pairs.first?.gridRow, 0)
    }

    func testFetchManifestFromFullURLSendsExactRequestAndOmitsAuthWhenNoToken() async throws {
        var capturedRequest: URLRequest?
        WireContractURLProtocol.handler = { request in
            capturedRequest = request
            return (Self.httpResponse(request, status: 200), Data(Self.manifestJSON.utf8))
        }

        let manifest = try await APIClient().fetchManifest(
            from: URL(string: "https://example.test/api/v1/test_sheets/sheet_123/manifest")!
        )

        XCTAssertEqual(capturedRequest?.httpMethod, "GET")
        XCTAssertEqual(capturedRequest?.url?.path, "/api/v1/test_sheets/sheet_123/manifest")
        XCTAssertNil(capturedRequest?.value(forHTTPHeaderField: "Authorization"))
        XCTAssertEqual(manifest.sheetID, "sheet_123")
    }

    func testFetchRecentSheetsDecodesPublishedResponseIncludingNullTitle() async throws {
        var capturedRequest: URLRequest?
        WireContractURLProtocol.handler = { request in
            capturedRequest = request
            return (
                Self.httpResponse(request, status: 200),
                Data(#"{"sheets":[{"sheet_id":"sheet_1","manifest_url":"https://example.test/api/v1/test_sheets/sheet_1/manifest","title":null},{"sheet_id":"sheet_2","manifest_url":"https://example.test/api/v1/test_sheets/sheet_2/manifest","title":"July LPS comparison sheet"}]}"#.utf8)
            )
        }

        let sheets = try await makeClient(token: "token").fetchRecentSheets(
            baseURL: URL(string: "https://example.test")!
        )

        XCTAssertEqual(capturedRequest?.httpMethod, "GET")
        XCTAssertEqual(capturedRequest?.url?.path, "/api/v1/test_sheets/recent")
        XCTAssertEqual(sheets.count, 2)
        XCTAssertEqual(sheets[0].sheetID, "sheet_1")
        XCTAssertNil(sheets[0].title)
        XCTAssertEqual(sheets[1].title, "July LPS comparison sheet")
    }

    func testUploadMeasurementsAcceptsPublishedSuccessResponseWithCounts() async throws {
        var capturedRequest: URLRequest?
        var capturedBody: Data?
        WireContractURLProtocol.handler = { request in
            capturedRequest = request
            capturedBody = request.httpBodyStream.flatMap(Self.readBody) ?? request.httpBody
            return (
                Self.httpResponse(request, status: 200),
                Data(#"{"capture_id":"cap_1","measurement_count":1,"pair_score_count":1}"#.utf8)
            )
        }

        let rgb = RGB(r: 0.12, g: 0.1, b: 0.02)
        let stats = ChannelStats(median: rgb, mean: rgb, standardDeviation: RGB(r: 0.01, g: 0.01, b: 0.01), min: rgb, max: rgb, sampleCount: 900, clippingFraction: 0)
        try await makeClient(token: "token").uploadMeasurements(
            captureID: "cap_1",
            baseURL: URL(string: "https://example.test")!,
            measurements: [PatchMeasurement(patchID: "pair_1#first", linearRGBMedian: rgb, normalizedLinearRGBMedian: rgb, stats: stats)],
            scores: [PairScore(pairID: "pair_1", distance: 0.035, similarity: 0.965, algorithmVersion: LPSScorer.algorithmVersion)]
        )

        XCTAssertEqual(capturedRequest?.httpMethod, "POST")
        XCTAssertEqual(capturedRequest?.url?.path, "/api/v1/captures/cap_1/measurements")
        let json = try XCTUnwrap(Self.jsonObject(from: capturedBody) as? [String: Any])
        let measurement = try XCTUnwrap((json["measurements"] as? [[String: Any]])?.first)
        XCTAssertEqual(measurement["patch_id"] as? String, "pair_1#first")
        let median = try XCTUnwrap(measurement["linear_rgb_median"] as? [String: Double])
        XCTAssertEqual(median["r"] ?? 0, 0.12, accuracy: 0.0001)
        XCTAssertEqual(median["g"] ?? 0, 0.1, accuracy: 0.0001)
        XCTAssertEqual(median["b"] ?? 0, 0.02, accuracy: 0.0001)
        let pairScore = try XCTUnwrap((json["pair_scores"] as? [[String: Any]])?.first)
        XCTAssertEqual(pairScore["pair_id"] as? String, "pair_1")
        XCTAssertEqual(pairScore["algorithm_version"] as? String, "lps-distance-v1")
    }

    func testUploadJudgmentsAcceptsPublishedSuccessResponseWithCount() async throws {
        var capturedRequest: URLRequest?
        var capturedBody: Data?
        WireContractURLProtocol.handler = { request in
            capturedRequest = request
            capturedBody = request.httpBodyStream.flatMap(Self.readBody) ?? request.httpBody
            return (
                Self.httpResponse(request, status: 200),
                Data(#"{"capture_id":"cap_1","judgment_count":1}"#.utf8)
            )
        }

        try await makeClient(token: "token").uploadJudgments(
            captureID: "cap_1",
            baseURL: URL(string: "https://example.test")!,
            judgments: [PairJudgment(pairID: "pair_1", judgment: "near_match")]
        )

        XCTAssertEqual(capturedRequest?.httpMethod, "POST")
        XCTAssertEqual(capturedRequest?.url?.path, "/api/v1/captures/cap_1/judgments")
        let json = try XCTUnwrap(Self.jsonObject(from: capturedBody) as? [String: Any])
        let judgment = try XCTUnwrap((json["judgments"] as? [[String: Any]])?.first)
        XCTAssertEqual(judgment["pair_id"] as? String, "pair_1")
        XCTAssertEqual(judgment["judgment"] as? String, "near_match")
    }

    func testFetchManifestThrowsBadStatusOnErrorResponses() async throws {
        WireContractURLProtocol.handler = { request in
            (
                Self.httpResponse(request, status: 401),
                Data(#"{"errors":{"detail":"Unauthorized"}}"#.utf8)
            )
        }

        do {
            _ = try await makeClient(token: "token").fetchManifest(
                baseURL: URL(string: "https://example.test")!,
                sheetCode: "sheet_123"
            )
            XCTFail("Expected non-2xx status to throw APIError.badStatus")
        } catch {
            XCTAssertTrue(error is APIError, "Unexpected error type: \(error)")
        }
    }

    private func makeClient(token: String?) -> APIClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [WireContractURLProtocol.self]
        return APIClient(token: token, session: URLSession(configuration: configuration))
    }

    private static func httpResponse(_ request: URLRequest, status: Int) -> HTTPURLResponse {
        HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
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

    private static let manifestJSON = #"""
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
        "paper_type": "Research paper",
        "ink_type": "Research ink set",
        "icc_profile": null,
        "print_settings": {},
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
    """#
}

private final class WireContractURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
            return
        }
        do {
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
