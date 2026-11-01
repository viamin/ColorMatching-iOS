import Foundation
import MeasurementCore
import XCTest
@testable import ColorMatchingLPSAppCore

final class APIClientTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.handler = nil
        super.tearDown()
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

    // MARK: - Real API contract characterization (viamin/color_matching#110 published spec)
    //
    // These fixtures mirror the actual JSON produced by `ColorMatchingWeb.TestSheetJSON` /
    // `ColorMatchingWeb.CaptureController` in the now-published OpenAPI spec
    // (`GET /api/v1/openapi.json`), not the illustrative examples in
    // docs/color-matching-api-contract.md. They pin today's hand-written `APIClient` behavior
    // against the real wire shapes so a later swap to a generated client can be checked for
    // regressions against this baseline.

    func testFetchManifestDecodesRealShapeIgnoringUndocumentedPrinterAndCaptureProfile() async throws {
        let fixture = Data(#"""
        {
          "schema_version": "lps-sheet-manifest/v1",
          "sheet_version": "lps-letter-grid-v1",
          "sheet_id": "sheet_123",
          "manifest_url": "https://example.test/api/v1/test_sheets/sheet_123/manifest",
          "created_at": "2026-07-25T12:00:00Z",
          "page": {"units": "mm", "width": 215.9, "height": 279.4},
          "registration_markers": [
            {"role": "top_left", "shape": "solid_square", "rect": {"x": 12, "y": 12, "width": 8, "height": 8}}
          ],
          "printer_profile": {
            "printer_make_model": "Research printer",
            "paper_type": "paper name",
            "ink_type": "ink set",
            "icc_profile": null,
            "print_settings": {},
            "driver_name": "driver",
            "driver_version": "1.0",
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
            {"id": "pair_1#second", "role": "pair_color", "pair_id": "pair_1", "pair_side": "second", "reference_role": null, "source_color": "#00FF00", "safe_inset_mm": 1.5, "rect": {"x": 40, "y": 38, "width": 16, "height": 10}}
          ],
          "pairs": [
            {"id": "pair_1", "first_patch_id": "pair_1#first", "second_patch_id": "pair_1#second", "source_colors": ["#FF0000", "#00FF00"], "grid_row": 0, "grid_col": 1}
          ]
        }
        """#.utf8)
        MockURLProtocol.handler = { request in
            (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, fixture)
        }

        let manifest = try await client().fetchManifest(baseURL: URL(string: "https://example.test")!, sheetCode: "sheet_123")

        XCTAssertEqual(manifest.schemaVersion, "lps-sheet-manifest/v1")
        XCTAssertEqual(manifest.sheetID, "sheet_123")
        XCTAssertEqual(manifest.patches.count, 2)
        XCTAssertEqual(manifest.pairs.first?.sourceColors, ["#FF0000", "#00FF00"])

        // `printer_profile` and `capture_profile` are real, present fields the Phoenix app
        // sends today (confirmed via lib/color_matching_web/controllers/test_sheet_json.ex at
        // viamin/color_matching@094bd6d), but `SheetManifest` has no properties for either one.
        // This is a genuine endpoint surface the generated client must expose that the current
        // hand-written model silently drops.
        let raw = try XCTUnwrap(JSONSerialization.jsonObject(with: fixture) as? [String: Any])
        XCTAssertNotNil(raw["printer_profile"], "fixture must mirror the real API's printer_profile field")
        XCTAssertNotNil(raw["capture_profile"], "fixture must mirror the real API's capture_profile field")
    }

    func testFetchRecentSheetsAlwaysDecodesNullTitle() async throws {
        // `ColorMatchingWeb.TestSheetJSON.render_recent_sheet/1` hardcodes `title: nil` today;
        // the populated "July LPS comparison sheet" example in
        // docs/color-matching-api-contract.md does not reflect any real response yet.
        MockURLProtocol.handler = { request in
            let body = Data(#"""
            {"sheets": [{"sheet_id": "sheet_123", "manifest_url": "https://example.test/api/v1/test_sheets/sheet_123/manifest", "title": null}]}
            """#.utf8)
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, body)
        }

        let sheets = try await client().fetchRecentSheets(baseURL: URL(string: "https://example.test")!)

        XCTAssertEqual(sheets.count, 1)
        XCTAssertNil(sheets.first?.title)
    }

    func testUploadMeasurementsSucceedsAgainstRealOKJSONResponse() async throws {
        // The real endpoint responds 200 with a JSON body (capture_id/measurement_count/
        // pair_score_count), not the 204-empty-body shape assumed elsewhere in this file.
        // `APIClient.uploadMeasurements` discards the response body entirely today, so it must
        // tolerate this shape without decoding it.
        MockURLProtocol.handler = { request in
            let body = Data(#"{"capture_id":"7","measurement_count":1,"pair_score_count":1}"#.utf8)
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, body)
        }

        let rgb = RGB(r: 0.2, g: 0.3, b: 0.4)
        let stats = ChannelStats(median: rgb, mean: rgb, standardDeviation: RGB(r: 0.01, g: 0.01, b: 0.01), min: rgb, max: rgb, sampleCount: 9, clippingFraction: 0)
        try await client().uploadMeasurements(
            captureID: "7",
            baseURL: URL(string: "https://example.test")!,
            measurements: [PatchMeasurement(patchID: "patch_1", linearRGBMedian: rgb, normalizedLinearRGBMedian: rgb, stats: stats)],
            scores: [PairScore(pairID: "pair_1", distance: 0.1, similarity: 0.9, algorithmVersion: LPSScorer.algorithmVersion)]
        )
    }

    func testUploadMeasurementsSendsFieldsNotPresentInPublishedSchema() async throws {
        // `ColorMatchingWeb.ApiSchemas.MeasurementUploadRequest` (the published OpenAPI schema)
        // only declares `measurements` (patch_id/linear_rgb_median/normalized_linear_rgb_median)
        // and `pair_scores`. It does not declare a top-level `scoring_algorithm_version`, nor a
        // per-measurement `stats` object, yet the hand-written client sends both. The Phoenix
        // controller tolerates (ignores) them since `CaptureController` applies no
        // `CastAndValidate` plug, but a generated client built strictly from the spec would drop
        // them unless deliberately kept. Pinning today's payload so that choice is visible as a
        // diff instead of a silent behavior change.
        var capturedBody: Data?
        MockURLProtocol.handler = { request in
            capturedBody = request.httpBodyStream.flatMap(Self.readBody) ?? request.httpBody
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data(#"{"capture_id":"7","measurement_count":1,"pair_score_count":1}"#.utf8))
        }

        let rgb = RGB(r: 0.2, g: 0.3, b: 0.4)
        let stats = ChannelStats(median: rgb, mean: rgb, standardDeviation: RGB(r: 0.01, g: 0.01, b: 0.01), min: rgb, max: rgb, sampleCount: 9, clippingFraction: 0)
        try await client().uploadMeasurements(
            captureID: "7",
            baseURL: URL(string: "https://example.test")!,
            measurements: [PatchMeasurement(patchID: "patch_1", linearRGBMedian: rgb, normalizedLinearRGBMedian: rgb, stats: stats)],
            scores: [PairScore(pairID: "pair_1", distance: 0.1, similarity: 0.9, algorithmVersion: LPSScorer.algorithmVersion)]
        )

        let json = try XCTUnwrap(Self.jsonObject(from: capturedBody) as? [String: Any])
        XCTAssertNotNil(json["scoring_algorithm_version"], "not declared on MeasurementUploadRequest in the published spec")
        let measurement = try XCTUnwrap((json["measurements"] as? [[String: Any]])?.first)
        XCTAssertNotNil(measurement["stats"], "not declared on the measurement item schema in the published spec")
    }

    func testUploadJudgmentsSucceedsAgainstRealOKJSONResponse() async throws {
        // Real endpoint responds 200 with {capture_id, judgment_count}, not 204-empty-body.
        MockURLProtocol.handler = { request in
            let body = Data(#"{"capture_id":"7","judgment_count":1}"#.utf8)
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, body)
        }

        try await client().uploadJudgments(
            captureID: "7",
            baseURL: URL(string: "https://example.test")!,
            judgments: [PairJudgment(pairID: "pair_1", judgment: "near_match")]
        )
    }

    func testBadStatusErrorDiscardsStructuredErrorBody() async throws {
        // Real validation failures come back as 422 with a structured `errors` payload
        // (`ColorMatchingWeb.ApiSchemas.ErrorResponse`). `APIClient` only inspects the status
        // code today and throws the untyped `APIError.badStatus`, discarding `errors` entirely.
        // A generated client should surface this structurally instead.
        MockURLProtocol.handler = { request in
            let body = Data(#"{"errors": {"metadata": ["can't be blank"]}}"#.utf8)
            return (HTTPURLResponse(url: request.url!, statusCode: 422, httpVersion: nil, headerFields: nil)!, body)
        }

        do {
            _ = try await client().createCapture(
                sheetID: "sheet_1",
                baseURL: URL(string: "https://example.test")!,
                metadata: CaptureMetadata(
                    deviceModel: "iPhone",
                    lens: "wide",
                    exposureDurationSeconds: nil,
                    iso: nil,
                    focusLensPosition: nil,
                    whiteBalanceGains: nil,
                    imageWidth: nil,
                    imageHeight: nil,
                    appVersion: "0.1.0",
                    timestamp: Date(timeIntervalSince1970: 0)
                ),
                quality: CaptureQuality(detectedMarkerCount: 0, blurScore: 0, rejections: [])
            )
            XCTFail("expected APIError.badStatus for a 422 response")
        } catch APIError.badStatus {
            // expected: the structured `errors` body above is discarded today.
        } catch {
            XCTFail("expected APIError.badStatus, got \(error)")
        }
    }

    private func client() -> APIClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        return APIClient(token: "token", session: URLSession(configuration: configuration))
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
