import Foundation
import MeasurementCore
import XCTest
@testable import ColorMatchingLPSAppCore

/// Exercises the app's `/api/v1` API layer against stubbed responses and
/// request payloads shaped by the OpenAPI document published by
/// `viamin/color_matching` (`GET /api/v1/openapi.json`, PR #113).
///
/// These are wire-format conformance tests: they are independent of whether
/// the requests are produced by the hand-written `APIClient` or by the
/// generated OpenAPI client, so they keep the generated client honest once
/// the hand-written models are replaced. No live server is contacted — all
/// responses come from `SpecStubURLProtocol`.
///
/// Documented deltas between the prose contract
/// (`docs/color-matching-api-contract.md`) and the published spec are
/// recorded in `docs/openapi-generated-client-verification.md`.
final class OpenAPIWireConformanceTests: XCTestCase {
    override func tearDown() {
        SpecStubURLProtocol.handler = nil
        super.tearDown()
    }

    // MARK: - Test-sheet manifest

    func testFetchManifestDecodesPublishedSpecManifestFixture() async throws {
        SpecStubURLProtocol.handler = { request in
            Self.ok(request, Self.manifestFixture)
        }

        let manifest = try await client().fetchManifest(
            baseURL: URL(string: "https://example.test")!,
            sheetCode: "sheet_123"
        )

        XCTAssertEqual(manifest.schemaVersion, "lps-sheet-manifest/v1")
        XCTAssertEqual(manifest.sheetID, "sheet_123")
        XCTAssertEqual(manifest.patches.first?.pairID, "pair_1")
        XCTAssertEqual(manifest.pairs.first?.firstPatchID, "patch_1")
        XCTAssertEqual(
            SpecStubURLProtocol.lastRequest?.url?.path,
            "/api/v1/test_sheets/sheet_123/manifest"
        )
    }

    // MARK: - Recent sheets

    func testFetchRecentSheetsDecodesNullableTitleFixture() async throws {
        SpecStubURLProtocol.handler = { request in
            Self.ok(
                request,
                #"{"sheets":[{"sheet_id":"sheet_123","manifest_url":"https://example.test/api/v1/test_sheets/sheet_123/manifest","title":null}]}"#
            )
        }

        let sheets = try await client().fetchRecentSheets(baseURL: URL(string: "https://example.test")!)

        XCTAssertEqual(sheets.count, 1)
        XCTAssertEqual(sheets.first?.sheetID, "sheet_123")
        XCTAssertNil(sheets.first?.title)
        XCTAssertEqual(
            SpecStubURLProtocol.lastRequest?.url?.path,
            "/api/v1/test_sheets/recent"
        )
    }

    // MARK: - Capture session creation

    func testCreateCaptureEncodesNestedMetadataVariantAcceptedByPublishedSpec() async throws {
        SpecStubURLProtocol.handler = { request in
            Self.response(request, status: 201, body: #"{"capture_id":"capture_123"}"#)
        }

        let created = try await client().createCapture(
            sheetID: "sheet_123",
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
                timestamp: Date(timeIntervalSince1970: 1_785_000_000)
            ),
            quality: CaptureQuality(detectedMarkerCount: 4, blurScore: 0.82, rejections: [])
        )

        XCTAssertEqual(created.captureID, "capture_123")
        let request = try XCTUnwrap(SpecStubURLProtocol.lastRequest)
        XCTAssertEqual(request.url?.path, "/api/v1/test_sheets/sheet_123/captures")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer token")

        let body = try Self.jsonObject(request)
        // The published CaptureRequest accepts the nested `metadata` variant
        // (viamin/color_matching ApiSchemas.CaptureRequest anyOf branch) with
        // `exposure_duration_seconds` naming, plus a nested `quality` block.
        let metadata = try XCTUnwrap(body["metadata"] as? [String: Any])
        XCTAssertEqual(metadata["device_model"] as? String, "iPhone")
        XCTAssertEqual(metadata["exposure_duration_seconds"] as? Double, 0.016)
        XCTAssertEqual(metadata["image_width"] as? Int, 4032)
        XCTAssertNotNil(metadata["app_version"])
        XCTAssertNotNil(metadata["timestamp"])
        let quality = try XCTUnwrap(body["quality"] as? [String: Any])
        XCTAssertEqual(quality["detected_marker_count"] as? Int, 4)
        XCTAssertEqual(quality["rejections"] as? [String], [])
    }

    // MARK: - Measurement upload

    func testUploadMeasurementsAcceptsDocumented200ResponseBody() async throws {
        SpecStubURLProtocol.handler = { request in
            Self.ok(
                request,
                #"{"capture_id":"capture_123","measurement_count":1,"pair_score_count":1}"#
            )
        }

        try await client().uploadMeasurements(
            captureID: "capture_123",
            baseURL: URL(string: "https://example.test")!,
            measurements: [Self.measurement(normalized: Self.rgb)],
            scores: [Self.score]
        )

        XCTAssertEqual(
            SpecStubURLProtocol.lastRequest?.url?.path,
            "/api/v1/captures/capture_123/measurements"
        )
    }

    func testUploadMeasurementsIncludesSpecRequiredNormalizedMedianForEachPatch() async throws {
        SpecStubURLProtocol.handler = { request in
            Self.ok(
                request,
                #"{"capture_id":"capture_123","measurement_count":1,"pair_score_count":1}"#
            )
        }

        try await client().uploadMeasurements(
            captureID: "capture_123",
            baseURL: URL(string: "https://example.test")!,
            measurements: [Self.measurement(normalized: nil)],
            scores: [Self.score]
        )

        let body = try Self.jsonObject(try XCTUnwrap(SpecStubURLProtocol.lastRequest))
        let measurement = try XCTUnwrap((body["measurements"] as? [[String: Any]])?.first)
        // MeasurementUploadRequest.items.required includes
        // normalized_linear_rgb_median in the published spec; a client that
        // omits it for un-normalized patches drifts from the contract.
        XCTAssertNotNil(
            measurement["normalized_linear_rgb_median"],
            "every uploaded measurement must carry normalized_linear_rgb_median"
        )
    }

    func testUploadMeasurementsEncodesPairScoreWithAlgorithmVersionAndDistance() async throws {
        SpecStubURLProtocol.handler = { request in
            Self.ok(request, #"{"capture_id":"c","measurement_count":0,"pair_score_count":1}"#)
        }

        try await client().uploadMeasurements(
            captureID: "capture_123",
            baseURL: URL(string: "https://example.test")!,
            measurements: [Self.measurement(normalized: Self.rgb)],
            scores: [Self.score]
        )

        let body = try Self.jsonObject(try XCTUnwrap(SpecStubURLProtocol.lastRequest))
        let score = try XCTUnwrap((body["pair_scores"] as? [[String: Any]])?.first)
        XCTAssertEqual(score["pair_id"] as? String, "pair_1")
        XCTAssertEqual(score["algorithm_version"] as? String, LPSScorer.algorithmVersion)
        XCTAssertNotNil(score["distance"], "PairScoreRequest requires one of score/similarity/distance")
        XCTAssertNotNil(score["similarity"])
    }

    // MARK: - Judgment upload

    func testUploadJudgmentsAcceptsDocumented200ResponseBody() async throws {
        SpecStubURLProtocol.handler = { request in
            Self.ok(request, #"{"capture_id":"capture_123","judgment_count":1}"#)
        }

        try await client().uploadJudgments(
            captureID: "capture_123",
            baseURL: URL(string: "https://example.test")!,
            judgments: [PairJudgment(pairID: "pair_1", judgment: "near_match")]
        )

        let request = try XCTUnwrap(SpecStubURLProtocol.lastRequest)
        XCTAssertEqual(request.url?.path, "/api/v1/captures/capture_123/judgments")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
    }
}

private extension OpenAPIWireConformanceTests {
    static let rgb = RGB(r: 0.12, g: 0.10, b: 0.02)

    static let score = PairScore(
        pairID: "pair_1",
        distance: 0.035,
        similarity: 0.965,
        algorithmVersion: LPSScorer.algorithmVersion
    )

    static func measurement(normalized: RGB?) -> PatchMeasurement {
        PatchMeasurement(
            patchID: "patch_1",
            linearRGBMedian: rgb,
            normalizedLinearRGBMedian: normalized,
            stats: ChannelStats(
                median: rgb,
                mean: rgb,
                standardDeviation: RGB(r: 0.01, g: 0.01, b: 0.004),
                min: rgb,
                max: rgb,
                sampleCount: 900,
                clippingFraction: 0
            )
        )
    }

    static func ok(_ request: URLRequest, _ body: String) -> (HTTPURLResponse, Data) {
        response(request, status: 200, body: body)
    }

    static func response(_ request: URLRequest, status: Int, body: String) -> (HTTPURLResponse, Data) {
        (
            HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!,
            Data(body.utf8)
        )
    }

    static func jsonObject(_ request: URLRequest) throws -> [String: Any] {
        let stream = request.httpBodyStream
        var data = request.httpBody ?? Data()
        if let stream {
            stream.open()
            defer { stream.close() }
            var buffer = [UInt8](repeating: 0, count: 4096)
            while stream.hasBytesAvailable {
                let read = stream.read(&buffer, maxLength: buffer.count)
                if read > 0 {
                    data.append(buffer, count: read)
                } else {
                    break
                }
            }
        }
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    static let manifestFixture = ##"{"schema_version":"lps-sheet-manifest/v1","sheet_version":"lps-letter-grid-v1","sheet_id":"sheet_123","manifest_url":"https://example.test/api/v1/test_sheets/sheet_123/manifest","created_at":"2026-07-25T12:00:00Z","page":{"units":"mm","width":215.9,"height":279.4},"registration_markers":[{"role":"top_left","shape":"solid_square","rect":{"x":12,"y":12,"width":8,"height":8}}],"printer_profile":{"id":"printer_profile_1","name":"Research printer","paper":"paper name","ink":"ink set","settings":{}},"capture_profile":{"expected_illuminant":"low_pressure_sodium","preferred_camera":"built_in_wide_angle_rear","scoring_algorithm_version":"lps-distance-v1"},"patches":[{"id":"patch_1","role":"pair_color","pair_id":"pair_1","pair_side":"first","reference_role":null,"source_color":"#FF0000","safe_inset_mm":1.5,"rect":{"x":16,"y":38,"width":16,"height":10}}],"pairs":[{"id":"pair_1","first_patch_id":"patch_1","second_patch_id":"patch_2","source_colors":["#FF0000","#00FF00"],"grid_row":0,"grid_col":1}]}"##
}

private func client() -> APIClient {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [SpecStubURLProtocol.self]
    return APIClient(token: "token", session: URLSession(configuration: configuration))
}

/// Stub transport replaying published-spec-shaped responses; no live server.
private final class SpecStubURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?
    static var lastRequest: URLRequest?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        Self.lastRequest = request
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
