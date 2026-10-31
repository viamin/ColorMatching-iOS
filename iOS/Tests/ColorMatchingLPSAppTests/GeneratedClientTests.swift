import Foundation
import XCTest

#if canImport(OpenAPIRuntime)

import OpenAPIRuntime

@testable import ColorMatchingLPSAppCore

/// Exercises the swift-openapi-generator client generated from the vendored
/// document at `iOS/Sources/ColorMatchingLPSAppCore/openapi.json` against an
/// in-memory stubbed transport — no live server and no network in CI.
///
/// Swift method names come from the vendoring conventions recorded in
/// `docs/color-matching-openapi-deltas.md` (operationIds normalized via the
/// generator's `nameOverrides`):
/// getTestSheetManifest, listRecentTestSheets, getRankedResults,
/// createCapture, uploadMeasurements, uploadJudgments.
///
/// These tests are inactive until the `OpenAPIRuntime` dependency (and with it
/// the generated `Client`, `Components`, and `Operations` types) is wired into
/// the package — that wiring is the missing behavior they demonstrate.
final class GeneratedClientTests: XCTestCase {
    private let serverURL = URL(string: "https://example.test")!

    // MARK: - Test-sheet manifest

    func testGetTestSheetManifestBuildsExpectedRequestAndDecodesSpecFields() async throws {
        let transport = StubTransport(status: .ok, responseBody: Self.manifestJSON)
        let client = Client(serverURL: serverURL, transport: transport)

        let output = try await client.getTestSheetManifest(.init(path: .init(sheet_id: "sheet_123")))

        let recorded = try XCTUnwrap(transport.recorder.requests.first)
        XCTAssertEqual(recorded.method, "GET")
        XCTAssertEqual(recorded.path, "/api/v1/test_sheets/sheet_123/manifest")

        guard case .ok(let payload) = output else {
            return XCTFail("Expected .ok response, got \(output)")
        }
        guard case .json(let manifest) = payload.body else {
            return XCTFail("Expected JSON manifest body")
        }
        // Only the fields the published spec declares are surfaced by the
        // generated types; the richer prose-contract fields (patches, pairs,
        // page, registration markers, printer profile) are dropped. That gap
        // is recorded in docs/color-matching-openapi-deltas.md.
        XCTAssertEqual(manifest.schema_version.rawValue, "lps-sheet-manifest/v1")
        XCTAssertEqual(manifest.sheet_id, "sheet_123")
        XCTAssertEqual(manifest.capture_profile.scoring_algorithm_version.rawValue, "lps-distance-v1")
    }

    func testGetTestSheetManifestSurfacesNotFoundResponse() async throws {
        let transport = StubTransport(
            status: .notFound,
            responseBody: Data(#"{"errors":{"detail":"Sheet not found"}}"#.utf8)
        )
        let client = Client(serverURL: serverURL, transport: transport)

        let output = try await client.getTestSheetManifest(.init(path: .init(sheet_id: "nope")))

        switch output {
        case .ok, .unauthorized:
            XCTFail("Expected .notFound, got \(output)")
        case .notFound:
            break
        }
    }

    // MARK: - Recent sheets

    func testListRecentSheetsDecodesSheetsIncludingNullableTitle() async throws {
        let transport = StubTransport(status: .ok, responseBody: Self.recentSheetsJSON)
        let client = Client(serverURL: serverURL, transport: transport)

        let output = try await client.listRecentSheets(.init())

        guard case .ok(let payload) = output else {
            return XCTFail("Expected .ok response, got \(output)")
        }
        guard case .json(let body) = payload.body else {
            return XCTFail("Expected JSON body")
        }
        XCTAssertEqual(body.sheets.count, 2)
        XCTAssertEqual(body.sheets.first?.sheet_id, "sheet_123")
        XCTAssertNil(body.sheets.first?.title, "title is declared nullable in the published spec")
        XCTAssertEqual(body.sheets.last?.title, "July LPS comparison sheet")
    }

    // MARK: - Ranked results

    func testGetRankedResultsBuildsExpectedRequestAndDecodesSpecFields() async throws {
        let transport = StubTransport(status: .ok, responseBody: Self.rankedResultsJSON)
        let client = Client(serverURL: serverURL, transport: transport)

        let output = try await client.getRankedResults(.init(path: .init(sheet_id: "sheet_123")))

        let recorded = try XCTUnwrap(transport.recorder.requests.first)
        XCTAssertEqual(recorded.method, "GET")
        XCTAssertEqual(recorded.path, "/api/v1/test_sheets/sheet_123/ranked_results")

        guard case .ok(let payload) = output else {
            return XCTFail("Expected .ok response, got \(output)")
        }
        guard case .json(let results) = payload.body else {
            return XCTFail("Expected JSON body")
        }
        XCTAssertEqual(results.schema_version.rawValue, "lps-ranked-results/v1")
        XCTAssertEqual(results.sheet_id, "sheet_123")
    }

    // MARK: - Capture session creation

    func testCreateCapturePostsToCapturePathAndDecodesCaptureID() async throws {
        let transport = StubTransport(status: .created, responseBody: Data(#"{"capture_id":"42"}"#.utf8))
        let client = Client(serverURL: serverURL, transport: transport)

        // The published CaptureRequest schema composes sibling `properties`
        // with `anyOf`, which OpenAPIKit-based tooling drops, so the generated
        // payload cannot yet carry metadata/quality. Only client mechanics are
        // asserted here until upstream fixes the schema composition; see
        // docs/color-matching-openapi-deltas.md.
        let output = try await client.createCapture(
            .init(path: .init(sheet_id: "sheet_123"), body: .json(Components.Schemas.CaptureRequest()))
        )

        let recorded = try XCTUnwrap(transport.recorder.requests.first)
        XCTAssertEqual(recorded.method, "POST")
        XCTAssertEqual(recorded.path, "/api/v1/test_sheets/sheet_123/captures")
        XCTAssertEqual(recorded.contentType, "application/json")

        guard case .created(let payload) = output else {
            return XCTFail("Expected .created response, got \(output)")
        }
        guard case .json(let created) = payload.body else {
            return XCTFail("Expected JSON body")
        }
        XCTAssertEqual(created.capture_id, "42")
    }

    // MARK: - Measurement upload

    func testUploadMeasurementsSendsMeasurementRowsAndDecodesCounts() async throws {
        let transport = StubTransport(
            status: .ok,
            responseBody: Data(
                #"{"capture_id":"42","measurement_count":1,"pair_score_count":1}"#.utf8
            )
        )
        let client = Client(serverURL: serverURL, transport: transport)

        let median = Components.Schemas.RgbPayload(value2: .init(r: 0.12, g: 0.10, b: 0.02))
        let row = Components.Schemas.MeasurementUploadRequest.measurementsPayload(
            patch_id: "pair_1#first",
            linear_rgb_median: median,
            normalized_linear_rgb_median: median
        )
        let input = Operations.uploadMeasurements.Input(
            path: .init(capture_id: "42"),
            body: .json(Components.Schemas.MeasurementUploadRequest(measurements: [row]))
        )
        let output = try await client.uploadMeasurements(input)

        let recorded = try XCTUnwrap(transport.recorder.requests.first)
        XCTAssertEqual(recorded.method, "POST")
        XCTAssertEqual(recorded.path, "/api/v1/captures/42/measurements")

        let body = try XCTUnwrap(try JSONSerialization.jsonObject(with: recorded.body ?? Data()) as? [String: Any])
        let measurements = try XCTUnwrap(body["measurements"] as? [[String: Any]])
        let measurement = try XCTUnwrap(measurements.first)
        XCTAssertEqual(measurement["patch_id"] as? String, "pair_1#first")
        let linearMedian = try XCTUnwrap(measurement["linear_rgb_median"] as? [String: Any])
        XCTAssertEqual(linearMedian["r"] as? Double, 0.12)
        XCTAssertNotNil(measurement["normalized_linear_rgb_median"], "Required on measurement rows by the published spec")

        guard case .ok(let payload) = output else {
            return XCTFail("Expected .ok response, got \(output)")
        }
        guard case .json(let accepted) = payload.body else {
            return XCTFail("Expected JSON body")
        }
        XCTAssertEqual(accepted.capture_id, "42")
        XCTAssertEqual(accepted.measurement_count, 1)
        XCTAssertEqual(accepted.pair_score_count, 1)
    }

    // MARK: - Judgment upload

    func testUploadJudgmentsSendsJudgmentsAndDecodesCounts() async throws {
        let transport = StubTransport(
            status: .ok,
            responseBody: Data(#"{"capture_id":"42","judgment_count":1}"#.utf8)
        )
        let client = Client(serverURL: serverURL, transport: transport)

        let judgment = Components.Schemas.JudgmentUploadRequest.judgmentsPayload(
            pair_id: "pair_1",
            judgment: "near_match"
        )
        let input = Operations.uploadJudgments.Input(
            path: .init(capture_id: "42"),
            body: .json(Components.Schemas.JudgmentUploadRequest(judgments: [judgment]))
        )
        let output = try await client.uploadJudgments(input)

        let recorded = try XCTUnwrap(transport.recorder.requests.first)
        XCTAssertEqual(recorded.method, "POST")
        XCTAssertEqual(recorded.path, "/api/v1/captures/42/judgments")

        let body = try XCTUnwrap(try JSONSerialization.jsonObject(with: recorded.body ?? Data()) as? [String: Any])
        let judgments = try XCTUnwrap(body["judgments"] as? [[String: Any]])
        XCTAssertEqual(judgments.first?["pair_id"] as? String, "pair_1")
        XCTAssertEqual(judgments.first?["judgment"] as? String, "near_match")

        guard case .ok(let payload) = output else {
            return XCTFail("Expected .ok response, got \(output)")
        }
        guard case .json(let accepted) = payload.body else {
            return XCTFail("Expected JSON body")
        }
        XCTAssertEqual(accepted.capture_id, "42")
        XCTAssertEqual(accepted.judgment_count, 1)
    }

    // MARK: - Authentication

    func testClientMiddlewareInjectsBearerAuthorizationHeader() async throws {
        let transport = StubTransport(status: .ok, responseBody: Self.recentSheetsJSON)
        let client = Client(
            serverURL: serverURL,
            transport: transport,
            middlewares: [BearerTokenMiddleware(token: "token")]
        )

        _ = try await client.listRecentSheets(.init())

        let recorded = try XCTUnwrap(transport.recorder.requests.first)
        XCTAssertEqual(recorded.authorization, "Bearer token")
    }

    // MARK: - Stub payloads

    /// Mirrors the payload rendered by `ColorMatchingWeb.TestSheetJSON.manifest/1`.
    /// Extra keys beyond the published schema are allowed (and ignored by the
    /// generated decoder), which keeps this fixture realistic.
    private static let manifestJSON = Data(
        #"""
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
            "paper_type": "paper name",
            "ink_type": "ink set",
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
        """#.utf8
    )

    private static let recentSheetsJSON = Data(
        #"""
        {
          "sheets": [
            {
              "sheet_id": "sheet_123",
              "manifest_url": "https://example.test/api/v1/test_sheets/sheet_123/manifest",
              "title": null
            },
            {
              "sheet_id": "sheet_456",
              "manifest_url": "https://example.test/api/v1/test_sheets/sheet_456/manifest",
              "title": "July LPS comparison sheet"
            }
          ]
        }
        """#.utf8
    )

    /// Mirrors the payload rendered by `ColorMatchingWeb.TestSheetJSON.ranked_results/1`;
    /// the published schema only declares schema_version and sheet_id today.
    private static let rankedResultsJSON = Data(
        #"""
        {
          "schema_version": "lps-ranked-results/v1",
          "sheet_id": "sheet_123",
          "printer_profile": {"printer_make_model": "Research printer"},
          "capture_count": 1,
          "latest_capture_at": "2026-07-25T12:30:00Z",
          "earliest_capture_at": "2026-07-25T12:00:00Z",
          "scoring_algorithm_versions": ["lps-distance-v1"],
          "results": [
            {
              "rank": 1,
              "pair_id": "pair_1",
              "scoring_algorithm_version": "lps-distance-v1",
              "row": 0,
              "col": 1,
              "source_colors": {"color_a_hex": "#FF0000", "color_b_hex": "#00FF00"},
              "score": {
                "average": 0.035,
                "latest": 0.035,
                "minimum": 0.035,
                "maximum": 0.035,
                "capture_count": 1,
                "sample_count": 1,
                "algorithm_versions": ["lps-distance-v1"]
              },
              "current_judgment": "near_match",
              "current_judgment_observed_at": "2026-07-25T12:30:00Z",
              "observation_count": 1,
              "latest_observation": {"judgment": "near_match", "observed_at": "2026-07-25T12:30:00Z"},
              "capture_count": 1,
              "latest_capture_at": "2026-07-25T12:30:00Z",
              "earliest_capture_at": "2026-07-25T12:00:00Z"
            }
          ]
        }
        """#.utf8
    )
}

// MARK: - Test doubles

private struct StubTransport: ClientTransport {
    final class Recorder: @unchecked Sendable {
        struct Request {
            var method: String
            var path: String
            var authorization: String?
            var contentType: String?
            var body: Data?
        }

        private let lock = NSLock()
        private var items: [Request] = []

        var requests: [Request] {
            lock.lock()
            defer { lock.unlock() }
            return items
        }

        func append(_ request: Request) {
            lock.lock()
            defer { lock.unlock() }
            items.append(request)
        }
    }

    let recorder = Recorder()
    let status: HTTPResponse.Status
    let responseBody: Data

    init(status: HTTPResponse.Status, responseBody: Data) {
        self.status = status
        self.responseBody = responseBody
    }

    func send(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String
    ) async throws -> (HTTPResponse, HTTPBody?) {
        var bodyData: Data?
        if let body {
            bodyData = try await Data(collecting: body, upTo: 1 << 20)
        }
        recorder.append(
            .init(
                method: request.method.rawValue,
                path: request.path,
                authorization: request.headerFields[.authorization],
                contentType: request.headerFields[.contentType],
                body: bodyData
            )
        )
        var response = HTTPResponse(status: status)
        response.headerFields[.contentType] = "application/json"
        return (response, HTTPBody(responseBody))
    }
}

/// Mirrors the bearerAuth security scheme declared by the vendored document.
private struct BearerTokenMiddleware: ClientMiddleware {
    var token: String

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

#endif
