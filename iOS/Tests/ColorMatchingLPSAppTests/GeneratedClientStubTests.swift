import Foundation
import XCTest

#if canImport(ColorMatchingOpenAPI) && canImport(OpenAPIRuntime)
import ColorMatchingOpenAPI
import OpenAPIRuntime

/// Exercises the swift-openapi-generator client (issue #5, deliverables 2–4)
/// against local stubbed responses. No live server and no URLSession: every
/// response comes from `StubTransport`, which also records the outgoing
/// requests so wire-format assertions (paths, methods, JSON bodies) are made
/// on what the generated client actually serialized.
///
/// The generated method names below are derived from the vendored document's
/// operationIds (`ColorMatchingWeb.TestSheetController.manifest` →
/// `colorMatchingWeb_TestSheetController_manifest`, per the generator's
/// IdiomaticSafeNameGenerator). Vendoring is verbatim; renaming an operationId
/// upstream becomes a visible regeneration diff — update these call sites then.
///
/// Until the generated module exists this whole file compiles down to a single
/// failing marker test (see the #else branch below).
final class GeneratedClientStubTests: XCTestCase {
    // MARK: - Test sheet manifest

    func testFetchManifestDecodesVersionedManifest() async throws {
        let manifestJSON = """
        {
          "schema_version": "lps-sheet-manifest/v1",
          "sheet_id": "sheet_1",
          "sheet_version": "lps-letter-grid-v1",
          "manifest_url": "https://example.test/api/v1/test_sheets/sheet_1/manifest",
          "created_at": "2026-07-25T12:00:00Z",
          "page": {"units": "mm", "width": 215.9, "height": 279.4},
          "registration_markers": [{"role": "top_left", "shape": "solid_square", "rect": {"x": 12, "y": 12, "width": 8, "height": 8}}],
          "capture_profile": {
            "expected_illuminant": "low_pressure_sodium",
            "preferred_camera": "built_in_wide_angle_rear",
            "scoring_algorithm_version": "lps-distance-v1"
          },
          "patches": [{"id": "pair_1#first", "role": "pair_color", "pair_id": "pair_1", "pair_side": "first", "reference_role": null, "source_color": "#FF0000", "safe_inset_mm": 1.5, "rect": {"x": 16, "y": 38, "width": 16, "height": 10}}],
          "pairs": [{"id": "pair_1", "first_patch_id": "pair_1#first", "second_patch_id": "pair_1#second", "source_colors": ["#FF0000", "#00FF00"], "grid_row": 0, "grid_col": 1}]
        }
        """
        let (client, transport) = Self.makeClient { _ in (200, Data(manifestJSON.utf8)) }

        let output = try await client.colorMatchingWeb_TestSheetController_manifest(
            .init(path: .init(sheet_id: "sheet_1"))
        )

        guard case .ok(let ok) = output else {
            return XCTFail("expected 200 for manifest, got status \(Self.status(of: output))")
        }
        guard case .json(let manifest) = ok.body else {
            return XCTFail("expected JSON manifest body")
        }

        XCTAssertEqual(manifest.schema_version.rawValue, "lps-sheet-manifest/v1")
        XCTAssertEqual(manifest.sheet_id, "sheet_1")
        XCTAssertEqual(manifest.capture_profile.scoring_algorithm_version.rawValue, "lps-distance-v1")

        let request = try XCTUnwrap(transport.recorded.first)
        XCTAssertEqual(request.operationID, "ColorMatchingWeb.TestSheetController.manifest")
        XCTAssertEqual(try Self.recordedPath(request), "/api/v1/test_sheets/sheet_1/manifest")
        XCTAssertEqual(request.method, "GET")
    }

    // MARK: - Recent sheets

    func testFetchRecentSheetsDecodesNullableTitles() async throws {
        let recentJSON = """
        {
          "sheets": [
            {"sheet_id": "sheet_1", "manifest_url": "https://example.test/api/v1/test_sheets/sheet_1/manifest", "title": null},
            {"sheet_id": "sheet_2", "manifest_url": "https://example.test/api/v1/test_sheets/sheet_2/manifest", "title": "July LPS sheet"}
          ]
        }
        """
        let (client, transport) = Self.makeClient { _ in (200, Data(recentJSON.utf8)) }

        let output = try await client.colorMatchingWeb_TestSheetController_recent(.init())

        guard case .ok(let ok) = output else {
            return XCTFail("expected 200 for recent sheets, got status \(Self.status(of: output))")
        }
        guard case .json(let recent) = ok.body else {
            return XCTFail("expected JSON recent-sheets body")
        }

        XCTAssertEqual(recent.sheets.count, 2)
        XCTAssertEqual(recent.sheets.first?.sheet_id, "sheet_1")
        XCTAssertNil(recent.sheets.first?.title, "untitled sheets decode with a null title")
        XCTAssertEqual(recent.sheets.last?.title, "July LPS sheet")

        let request = try XCTUnwrap(transport.recorded.first)
        XCTAssertEqual(request.operationID, "ColorMatchingWeb.TestSheetController.recent")
        XCTAssertEqual(try Self.recordedPath(request), "/api/v1/test_sheets/recent")
    }

    // MARK: - Capture session creation

    func testCreateCapturePostsNestedMetadataAndQuality() async throws {
        let (client, transport) = Self.makeClient { _ in (201, Data(#"{"capture_id": "cap_1"}"#.utf8)) }

        let request = Components.Schemas.CaptureRequest(
            metadata: Components.Schemas.CaptureMetadata(
                device_model: "iPhone",
                lens: "built_in_wide_angle",
                image_width: 4032,
                image_height: 3024,
                app_version: "0.1.0",
                timestamp: Date(timeIntervalSince1970: 1_784_986_800)
            ),
            quality: .init(detected_marker_count: 4, blur_score: 0.82, rejections: [])
        )

        let output = try await client.colorMatchingWeb_CaptureController_create(
            .init(path: .init(sheet_id: "sheet_1"), body: .json(request))
        )

        guard case .created(let created) = output else {
            return XCTFail("expected 201 for capture creation, got status \(Self.status(of: output))")
        }
        guard case .json(let payload) = created.body else {
            return XCTFail("expected JSON capture body")
        }
        XCTAssertEqual(payload.capture_id, "cap_1")

        let recorded = try XCTUnwrap(transport.recorded.first)
        XCTAssertEqual(recorded.operationID, "ColorMatchingWeb.CaptureController.create")
        XCTAssertEqual(recorded.method, "POST")
        XCTAssertEqual(try Self.recordedPath(recorded), "/api/v1/test_sheets/sheet_1/captures")
        XCTAssertTrue(
            try XCTUnwrap(recorded.contentType, "capture creation must send a content type").contains("application/json")
        )

        let json = try Self.jsonObject(recorded.body)
        let metadata = try XCTUnwrap(json["metadata"] as? [String: Any], "nested metadata form must be encoded")
        XCTAssertEqual(metadata["device_model"] as? String, "iPhone")
        XCTAssertEqual(metadata["image_width"] as? Int, 4032)
        XCTAssertEqual(metadata["app_version"] as? String, "0.1.0")
        XCTAssertNotNil(metadata["timestamp"], "capture metadata must carry a timestamp")
        let quality = try XCTUnwrap(json["quality"] as? [String: Any], "nested quality form must be encoded")
        XCTAssertEqual(quality["detected_marker_count"] as? Int, 4)
        XCTAssertEqual(quality["rejections"] as? [String], [])
    }

    // MARK: - Measurement upload

    func testUploadMeasurementsCarryPerScoreAlgorithmVersionAndDecodeCounts() async throws {
        let uploadJSON = """
        {
          "measurements": [
            {"patch_id": "pair_1#first", "linear_rgb_median": {"r": 0.12, "g": 0.1, "b": 0.02}, "normalized_linear_rgb_median": {"r": 0.15, "g": 0.12, "b": 0.02}},
            {"patch_id": "pair_1#second", "linear_rgb_median": [0.2, 0.3, 0.4], "normalized_linear_rgb_median": [0.2, 0.3, 0.4]}
          ],
          "pair_scores": [
            {"pair_id": "pair_1", "algorithm_version": "lps-distance-v1", "distance": 0.035, "similarity": 0.965}
          ]
        }
        """
        // The published spec (unlike the prose contract) accepts RGB medians as
        // objects or arrays (RgbPayload anyOf), drops the per-measurement stats
        // block, and requires normalized_linear_rgb_median.
        let upload = try JSONDecoder().decode(
            Components.Schemas.MeasurementUploadRequest.self,
            from: Data(uploadJSON.utf8)
        )

        let responseJSON = #"{"capture_id": "cap_1", "measurement_count": 2, "pair_score_count": 1}"#
        let (client, transport) = Self.makeClient { _ in (200, Data(responseJSON.utf8)) }

        let output = try await client.colorMatchingWeb_CaptureController_upload_measurements(
            .init(path: .init(capture_id: "cap_1"), body: .json(upload))
        )

        guard case .ok(let ok) = output else {
            return XCTFail("expected 200 for measurement upload, got status \(Self.status(of: output))")
        }
        guard case .json(let counts) = ok.body else {
            return XCTFail("expected JSON counting body")
        }
        XCTAssertEqual(counts.capture_id, "cap_1")
        XCTAssertEqual(counts.measurement_count, 2)
        XCTAssertEqual(counts.pair_score_count, 1)

        let recorded = try XCTUnwrap(transport.recorded.first)
        XCTAssertEqual(recorded.operationID, "ColorMatchingWeb.CaptureController.upload_measurements")
        XCTAssertEqual(recorded.method, "POST")
        XCTAssertEqual(try Self.recordedPath(recorded), "/api/v1/captures/cap_1/measurements")

        let json = try Self.jsonObject(recorded.body)
        XCTAssertNil(
            json["scoring_algorithm_version"],
            "prose-contract delta: the published spec has no top-level scoring_algorithm_version"
        )
        let measurements = try XCTUnwrap(json["measurements"] as? [[String: Any]])
        XCTAssertEqual(measurements.first?["patch_id"] as? String, "pair_1#first")
        XCTAssertNotNil(measurements.first?["linear_rgb_median"])
        XCTAssertNil(measurements.first?["stats"], "prose-contract delta: the published spec has no stats block")
        let scores = try XCTUnwrap(json["pair_scores"] as? [[String: Any]])
        XCTAssertEqual(scores.first?["algorithm_version"] as? String, "lps-distance-v1")
        XCTAssertEqual(scores.first?["distance"] as? Double, 0.035)
    }

    // MARK: - Judgment upload

    func testUploadJudgmentsDecodeCountingBody() async throws {
        let upload = try JSONDecoder().decode(
            Components.Schemas.JudgmentUploadRequest.self,
            from: Data(#"{"judgments": [{"pair_id": "pair_1", "judgment": "near_match"}]}"#.utf8)
        )

        let responseJSON = #"{"capture_id": "cap_1", "judgment_count": 1}"#
        let (client, transport) = Self.makeClient { _ in (200, Data(responseJSON.utf8)) }

        let output = try await client.colorMatchingWeb_CaptureController_upload_judgments(
            .init(path: .init(capture_id: "cap_1"), body: .json(upload))
        )

        guard case .ok(let ok) = output else {
            return XCTFail("expected 200 for judgment upload, got status \(Self.status(of: output))")
        }
        guard case .json(let counts) = ok.body else {
            return XCTFail("expected JSON counting body")
        }
        XCTAssertEqual(counts.capture_id, "cap_1")
        XCTAssertEqual(counts.judgment_count, 1)

        let recorded = try XCTUnwrap(transport.recorded.first)
        XCTAssertEqual(recorded.operationID, "ColorMatchingWeb.CaptureController.upload_judgments")
        XCTAssertEqual(try Self.recordedPath(recorded), "/api/v1/captures/cap_1/judgments")
        let json = try Self.jsonObject(recorded.body)
        let judgments = try XCTUnwrap(json["judgments"] as? [[String: Any]])
        XCTAssertEqual(judgments.first?["pair_id"] as? String, "pair_1")
        XCTAssertEqual(judgments.first?["judgment"] as? String, "near_match")
    }

    // MARK: - Ranked results

    func testFetchRankedResultsDecodesVersionEnvelope() async throws {
        let rankedJSON = """
        {
          "schema_version": "lps-ranked-results/v1",
          "sheet_id": "sheet_1",
          "capture_count": 3,
          "latest_capture_at": "2026-08-01T09:00:00Z",
          "earliest_capture_at": "2026-07-25T12:00:00Z",
          "scoring_algorithm_versions": ["lps-distance-v1"],
          "results": [
            {"rank": 1, "pair_id": "pair_1", "scoring_algorithm_version": "lps-distance-v1", "current_judgment": "near_match"}
          ]
        }
        """
        let (client, transport) = Self.makeClient { _ in (200, Data(rankedJSON.utf8)) }

        let output = try await client.colorMatchingWeb_TestSheetController_ranked_results(
            .init(path: .init(sheet_id: "sheet_1"))
        )

        guard case .ok(let ok) = output else {
            return XCTFail("expected 200 for ranked results, got status \(Self.status(of: output))")
        }
        guard case .json(let ranked) = ok.body else {
            return XCTFail("expected JSON ranked-results body")
        }
        XCTAssertEqual(ranked.schema_version.rawValue, "lps-ranked-results/v1")
        XCTAssertEqual(ranked.sheet_id, "sheet_1")

        let recorded = try XCTUnwrap(transport.recorded.first)
        XCTAssertEqual(recorded.operationID, "ColorMatchingWeb.TestSheetController.ranked_results")
        XCTAssertEqual(try Self.recordedPath(recorded), "/api/v1/test_sheets/sheet_1/ranked_results")
    }

    // MARK: - Bearer authentication wiring

    func testBearerMiddlewareInjectsAuthorizationHeader() async throws {
        let transport = StubTransport { _ in (200, Data(#"{"sheets": []}"#.utf8)) }
        let client = Client(
            serverURL: Self.baseURL,
            transport: transport,
            middlewares: [BearerTokenMiddleware(token: "token")]
        )

        _ = try await client.colorMatchingWeb_TestSheetController_recent(.init())

        let recorded = try XCTUnwrap(transport.recorded.first)
        XCTAssertEqual(recorded.authorization, "Bearer token", "the app's bearer-token flow must survive the generated-client swap")
    }

    // MARK: - Test helpers

    private static let baseURL = URL(string: "https://example.test")!

    private static func makeClient(
        responder: @escaping @Sendable (StubTransport.Recorded) throws -> (Int, Data)
    ) -> (ColorMatchingOpenAPI.Client, StubTransport) {
        let transport = StubTransport(responder: responder)
        let client = ColorMatchingOpenAPI.Client(serverURL: baseURL, transport: transport)
        return (client, transport)
    }

    private static func recordedPath(_ request: StubTransport.Recorded) throws -> String {
        try XCTUnwrap(request.path)
    }

    private static func jsonObject(_ data: Data) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    /// Status-code extraction for failure messages only; never asserted on success paths.
    private static func status(of output: Any) -> Int {
        let mirror = Mirror(reflecting: output)
        for child in mirror.children {
            if let statusCode = statusCode(of: child.value) { return statusCode }
        }
        return -1
    }

    private static func statusCode(of value: Any) -> Int? {
        let mirror = Mirror(reflecting: value)
        for child in mirror.children where child.label == "statusCode" {
            if let code = child.value as? Int { return code }
        }
        return nil
    }
}

/// Records outgoing requests and answers with canned responses; never touches
/// the network. Signature matches swift-openapi-runtime 1.x `ClientTransport`.
private final class StubTransport: ClientTransport, @unchecked Sendable {
    struct Recorded: Sendable {
        let operationID: String
        let path: String?
        let method: String
        let contentType: String?
        let authorization: String?
        let body: Data
    }

    private let lock = NSLock()
    private var recordedRequests: [Recorded] = []
    private let responder: @Sendable (Recorded) throws -> (Int, Data)

    init(responder: @escaping @Sendable (Recorded) throws -> (Int, Data)) {
        self.responder = responder
    }

    var recorded: [Recorded] {
        lock.lock()
        defer { lock.unlock() }
        return recordedRequests
    }

    func send(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String
    ) async throws -> (HTTPResponse, HTTPBody?) {
        let data = try await Data(collecting: body ?? HTTPBody(), upTo: 1_048_576)
        let entry = Recorded(
            operationID: operationID,
            path: request.path,
            method: request.method.rawValue,
            contentType: request.headerFields[.contentType],
            authorization: request.headerFields[.authorization],
            body: data
        )
        lock.lock()
        recordedRequests.append(entry)
        lock.unlock()

        let (statusCode, payload) = try responder(entry)
        let response = HTTPResponse(
            status: HTTPResponse.Status(code: statusCode),
            headerFields: [.contentType: "application/json"]
        )
        return (response, HTTPBody(payload))
    }
}

/// Mirrors how the app injects its shared bearer token (the hand-written
/// APIClient's `Authorization: Bearer <token>` behavior) through a
/// swift-openapi-runtime middleware.
private struct BearerTokenMiddleware: ClientMiddleware {
    let token: String

    func intercept(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String,
        next: @Sendable (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
    ) async throws -> (HTTPResponse, HTTPBody?) {
        var request = request
        request.headerFields[.authorization] = "Bearer \(token)"
        return try await next(request, body, baseURL)
    }
}

#else

import XCTest

/// Red-phase marker: the generated client does not exist yet. Issue #5
/// deliverables 1–2 add `swift-openapi-generator` + `swift-openapi-runtime`,
/// vendor the spec at `iOS/Sources/ColorMatchingOpenAPI/openapi.json`, and link
/// `ColorMatchingOpenAPI` + `OpenAPIRuntime` into this test target. The
/// stubbed-response tests above activate automatically once the module can be
/// imported. See docs/openapi-generated-client-plan.md.
final class GeneratedClientStubTests: XCTestCase {
    func testGeneratedClientModuleIsWiredIntoThePackage() async throws {
        XCTFail(
            """
            The generated OpenAPI client module 'ColorMatchingOpenAPI' is not \
            wired into the package yet (issue #5 deliverables 1–2). Add \
            swift-openapi-generator + swift-openapi-runtime, vendor the document \
            published by viamin/color_matching#110 at \
            Sources/ColorMatchingOpenAPI/openapi.json, and link the generated \
            module into the ColorMatchingLPSAppTests target.
            """
        )
    }
}

#endif
