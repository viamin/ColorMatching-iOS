import Foundation
import MeasurementCore
import XCTest
@testable import ColorMatchingLPSAppCore

final class APIClientTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.handler = nil
        super.tearDown()
    }

    /// Swap-invariant regression net for issue #5: the manifest surface must keep
    /// returning the client-side `SheetManifest` domain model (patches, pairs,
    /// geometry) whether decoded by hand-written models or a generated client.
    /// Fixture shape mirrors the real `color_matching` manifest renderer
    /// (patch ids `<pair_id>#<side>`, printer profile fields).
    func testFetchManifestDecodesSheetManifestFixture() async throws {
        MockURLProtocol.handler = { request in
            (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, try Self.manifestFixture())
        }

        let manifest = try await client().fetchManifest(
            from: URL(string: "https://example.test/api/v1/test_sheets/sheet_123/manifest")!
        )

        XCTAssertEqual(manifest.schemaVersion, "lps-sheet-manifest/v1")
        XCTAssertEqual(manifest.sheetVersion, "lps-letter-grid-v1")
        XCTAssertEqual(manifest.sheetID, "sheet_123")
        XCTAssertEqual(manifest.manifestURL.absoluteString, "https://example.test/api/v1/test_sheets/sheet_123/manifest")
        XCTAssertEqual(manifest.page, Page(units: "mm", width: 215.9, height: 279.4))
        XCTAssertEqual(manifest.patches.first?.id, "pair_1#first")
        XCTAssertEqual(manifest.patches.first?.pairID, "pair_1")
        XCTAssertEqual(manifest.patches.first?.pairSide, "first")
        XCTAssertEqual(manifest.patches.first?.sourceColor, "#FF0000")
        XCTAssertEqual(manifest.pairs.first?.firstPatchID, "pair_1#first")
        XCTAssertEqual(manifest.pairs.first?.secondPatchID, "pair_1#second")
        XCTAssertEqual(manifest.pairs.first?.sourceColors, ["#FF0000", "#00FF00"])
    }

    func testFetchManifestSendsGETWithBearerToken() async throws {
        var capturedRequest: URLRequest?
        MockURLProtocol.handler = { request in
            capturedRequest = request
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, try Self.manifestFixture())
        }

        _ = try await client().fetchManifest(from: URL(string: "https://example.test/api/v1/test_sheets/sheet_123/manifest")!)

        XCTAssertEqual(capturedRequest?.httpMethod, "GET")
        XCTAssertEqual(capturedRequest?.url?.path, "/api/v1/test_sheets/sheet_123/manifest")
        XCTAssertEqual(capturedRequest?.value(forHTTPHeaderField: "Authorization"), "Bearer token")
    }

    func testFetchManifestThrowsBadStatusOnErrorStatus() async {
        MockURLProtocol.handler = { request in
            (HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!, Data(#"{"errors":{"detail":"Sheet not found"}}"#.utf8))
        }

        do {
            _ = try await client().fetchManifest(from: URL(string: "https://example.test/api/v1/test_sheets/sheet_123/manifest")!)
            XCTFail("Expected APIError.badStatus")
        } catch {
            guard case APIError.badStatus = error else {
                return XCTFail("Expected APIError.badStatus, got \(error)")
            }
        }
    }

    func testFetchRecentSheetsDecodesNullTitleAsOptional() async throws {
        MockURLProtocol.handler = { request in
            (
                HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                Data(#"{"sheets":[{"sheet_id":"sheet_123","manifest_url":"https://example.test/api/v1/test_sheets/sheet_123/manifest","title":null},{"sheet_id":"sheet_456","manifest_url":"https://example.test/api/v1/test_sheets/sheet_456/manifest","title":"July LPS comparison sheet"}]}"#.utf8)
            )
        }

        let sheets = try await client().fetchRecentSheets(baseURL: URL(string: "https://example.test")!)

        XCTAssertEqual(sheets.count, 2)
        XCTAssertEqual(sheets.first?.sheetID, "sheet_123")
        XCTAssertNil(sheets.first?.title)
        XCTAssertEqual(sheets.last?.title, "July LPS comparison sheet")
    }

    func testCreateCaptureEncodesMetadataAndQuality() async throws {
        var capturedRequest: URLRequest?
        var capturedBody: Data?
        MockURLProtocol.handler = { request in
            capturedRequest = request
            capturedBody = request.httpBodyStream.flatMap(Self.readBody) ?? request.httpBody
            return (HTTPURLResponse(url: request.url!, statusCode: 201, httpVersion: nil, headerFields: nil)!, Data(#"{"capture_id":"cap_1"}"#.utf8))
        }

        let response = try await client().createCapture(
            sheetID: "sheet_1",
            baseURL: URL(string: "https://example.test")!,
            metadata: CaptureMetadata(
                deviceModel: "iPhone",
                lens: "wide",
                exposureDurationSeconds: 0.01,
                iso: 100,
                focusLensPosition: 0.4,
                whiteBalanceGains: WhiteBalanceGains(red: 1.1, green: 1.0, blue: 1.2),
                imageWidth: 100,
                imageHeight: 200,
                appVersion: "0.1.0",
                timestamp: Date(timeIntervalSince1970: 0)
            ),
            quality: CaptureQuality(detectedMarkerCount: 4, blurScore: 0.75, rejections: [])
        )

        XCTAssertEqual(response.captureID, "cap_1")
        XCTAssertEqual(capturedRequest?.url?.path, "/api/v1/test_sheets/sheet_1/captures")
        XCTAssertEqual(capturedRequest?.value(forHTTPHeaderField: "Authorization"), "Bearer token")
        let json = try XCTUnwrap(Self.jsonObject(from: capturedBody) as? [String: Any])
        XCTAssertNotNil(json["metadata"])
        let quality = try XCTUnwrap(json["quality"] as? [String: Any])
        XCTAssertEqual(quality["detected_marker_count"] as? Int, 4)
        XCTAssertEqual(quality["rejections"] as? [String], [])
    }

    func testUploadMeasurementsEncodesScoresWithAlgorithmVersion() async throws {
        var capturedBody: Data?
        MockURLProtocol.handler = { request in
            capturedBody = request.httpBodyStream.flatMap(Self.readBody) ?? request.httpBody
            return (HTTPURLResponse(url: request.url!, statusCode: 204, httpVersion: nil, headerFields: nil)!, Data())
        }

        let rgb = RGB(r: 0.2, g: 0.3, b: 0.4)
        let stats = ChannelStats(median: rgb, mean: rgb, standardDeviation: RGB(r: 0.01, g: 0.01, b: 0.01), min: rgb, max: rgb, sampleCount: 9, clippingFraction: 0)
        try await client().uploadMeasurements(
            captureID: "cap_1",
            baseURL: URL(string: "https://example.test")!,
            measurements: [PatchMeasurement(patchID: "patch_1", linearRGBMedian: rgb, normalizedLinearRGBMedian: rgb, stats: stats)],
            scores: [PairScore(pairID: "pair_1", distance: 0.1, similarity: 0.9, algorithmVersion: LPSScorer.algorithmVersion)]
        )

        let json = try XCTUnwrap(Self.jsonObject(from: capturedBody) as? [String: Any])
        XCTAssertEqual(json["scoring_algorithm_version"] as? String, "lps-distance-v1")
        let measurement = try XCTUnwrap((json["measurements"] as? [[String: Any]])?.first)
        XCTAssertEqual(measurement["patch_id"] as? String, "patch_1")
        let statsPayload = try XCTUnwrap(measurement["stats"] as? [String: Any])
        XCTAssertEqual(Set(statsPayload.keys), ["sample_count", "clipping_fraction", "mean", "standard_deviation"])
        XCTAssertEqual((json["pair_scores"] as? [[String: Any]])?.first?["pair_id"] as? String, "pair_1")
    }

    func testUploadJudgmentsEncodesPathAndPayload() async throws {
        var capturedRequest: URLRequest?
        var capturedBody: Data?
        MockURLProtocol.handler = { request in
            capturedRequest = request
            capturedBody = request.httpBodyStream.flatMap(Self.readBody) ?? request.httpBody
            return (HTTPURLResponse(url: request.url!, statusCode: 204, httpVersion: nil, headerFields: nil)!, Data())
        }

        try await client().uploadJudgments(
            captureID: "cap_1",
            baseURL: URL(string: "https://example.test")!,
            judgments: [PairJudgment(pairID: "pair_1", judgment: "near_match")]
        )

        XCTAssertEqual(capturedRequest?.httpMethod, "POST")
        XCTAssertEqual(capturedRequest?.url?.path, "/api/v1/captures/cap_1/judgments")
        let json = try XCTUnwrap(Self.jsonObject(from: capturedBody) as? [String: Any])
        XCTAssertEqual((json["judgments"] as? [[String: Any]])?.first?["judgment"] as? String, "near_match")
    }

    private func client() -> APIClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        return APIClient(token: "token", session: URLSession(configuration: configuration))
    }

    /// Matches the real manifest rendered by `ColorMatchingWeb.TestSheetJSON`
    /// (upstream `viamin/color_matching`), including `pair_1#first` patch ids
    /// and the actual printer-profile field names.
    private static func manifestFixture() throws -> Data {
        let manifest: [String: Any] = [
            "schema_version": "lps-sheet-manifest/v1",
            "sheet_id": "sheet_123",
            "sheet_version": "lps-letter-grid-v1",
            "manifest_url": "https://example.test/api/v1/test_sheets/sheet_123/manifest",
            "created_at": "2026-07-25T12:00:00Z",
            "page": ["units": "mm", "width": 215.9, "height": 279.4],
            "registration_markers": [
                ["role": "top_left", "shape": "solid_square", "rect": ["x": 12, "y": 12, "width": 8, "height": 8]]
            ],
            "printer_profile": [
                "printer_make_model": "Canon Pixma",
                "paper_type": "Photo Paper Plus Glossy II",
                "ink_type": "CLI-42",
                "notes": NSNull()
            ],
            "capture_profile": [
                "expected_illuminant": "low_pressure_sodium",
                "preferred_camera": "built_in_wide_angle_rear",
                "scoring_algorithm_version": "lps-distance-v1"
            ],
            "patches": [
                [
                    "id": "pair_1#first",
                    "role": "pair_color",
                    "pair_id": "pair_1",
                    "pair_side": "first",
                    "reference_role": NSNull(),
                    "source_color": "#FF0000",
                    "safe_inset_mm": 1.5,
                    "rect": ["x": 16, "y": 38, "width": 16, "height": 10]
                ]
            ],
            "pairs": [
                [
                    "id": "pair_1",
                    "first_patch_id": "pair_1#first",
                    "second_patch_id": "pair_1#second",
                    "source_colors": ["#FF0000", "#00FF00"],
                    "grid_row": 0,
                    "grid_col": 1
                ]
            ]
        ]
        return try JSONSerialization.data(withJSONObject: manifest)
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
                data.append(buffer, count: count)
            } else {
                break
            }
        }
        return data
    }
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
