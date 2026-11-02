#if canImport(OpenAPIGeneratedCore) && canImport(OpenAPIRuntime)
#if canImport(HTTPTypes)
import HTTPTypes
#endif
import Foundation
import OpenAPIGeneratedCore
import OpenAPIRuntime
import XCTest

final class GeneratedClientContractTests: XCTestCase {
    private let serverURL = URL(string: "https://example.test")!

    func test_getManifest_buildsExpectedRequestAndDecodesRenderedManifest() async throws {
        let recorder = RequestRecorder()
        let client = makeClient(recorder: recorder) { _, _, _ in
            Self.jsonResponse(.ok, Self.renderedManifestJSON)
        }

        let response = try await client.getManifest(.init(path: .init(sheet_id: "SHEET1")))

        let manifest = try response.ok.body.json
        XCTAssertEqual(manifest.schema_version, "lps-sheet-manifest/v1")
        XCTAssertEqual(manifest.sheet_id, "SHEET1")
        XCTAssertEqual(manifest.sheet_version, "lps-letter-grid-v1")
        XCTAssertEqual(manifest.manifest_url, "/api/v1/test_sheets/SHEET1/manifest")
        XCTAssertEqual(manifest.created_at, Self.iso8601Date("2026-07-25T12:00:00Z"))
        XCTAssertEqual(manifest.page.units, "mm")
        XCTAssertEqual(manifest.page.width, 215.9)
        XCTAssertEqual(manifest.registration_markers.first?.role, "top_left")
        XCTAssertEqual(manifest.registration_markers.first?.rect.width, 8)
        XCTAssertEqual(manifest.printer_profile.printer_make_model, "Research printer")
        XCTAssertEqual(manifest.capture_profile.scoring_algorithm_version, "lps-distance-v1")
        XCTAssertEqual(manifest.patches.first?.id, "pair_1#first")
        XCTAssertEqual(manifest.patches.first?.pair_id, "pair_1")
        XCTAssertEqual(manifest.patches.first?.pair_side, "first")
        XCTAssertEqual(manifest.patches.first?.safe_inset_mm, 1.5)
        XCTAssertEqual(manifest.pairs.first?.id, "pair_1")
        XCTAssertEqual(manifest.pairs.first?.first_patch_id, "pair_1#first")
        XCTAssertEqual(manifest.pairs.first?.second_patch_id, "pair_1#second")
        XCTAssertEqual(manifest.pairs.first?.grid_row, 0)
        XCTAssertEqual(manifest.pairs.first?.grid_col, 1)

        let request = try XCTUnwrap(recorder.requests.first)
        XCTAssertEqual(request.method, "GET")
        XCTAssertEqual(request.path, "/api/v1/test_sheets/SHEET1/manifest")
        XCTAssertEqual(request.operationID, "getManifest")
        XCTAssertNil(request.bodyJSON)
    }

    func test_getManifest_surfacesUnauthorizedAsDocumentedResponse() async throws {
        let client = makeClient { _, _, _ in
            Self.jsonResponse(.unauthorized, #"{"errors":{"detail":"Unauthorized"}}"#)
        }

        let response = try await client.getManifest(.init(path: .init(sheet_id: "SHEET1")))

        switch response {
        case .unauthorized:
            break
        case .ok, .notFound, .undocumented:
            XCTFail("expected .unauthorized, got \(response)")
        }
    }

    func test_getRecentSheets_decodesSheetsListWithNullableTitle() async throws {
        let recorder = RequestRecorder()
        let payload = #"""
        {"sheets":[
          {"sheet_id":"SHEET1","manifest_url":"/api/v1/test_sheets/SHEET1/manifest","title":null},
          {"sheet_id":"SHEET2","manifest_url":"/api/v1/test_sheets/SHEET2/manifest","title":"July LPS sheet"}
        ]}
        """#
        let client = makeClient(recorder: recorder) { _, _, _ in
            Self.jsonResponse(.ok, payload)
        }

        let response = try await client.getRecentSheets(.init())

        let body = try response.ok.body.json
        XCTAssertEqual(body.sheets.map(\.sheet_id), ["SHEET1", "SHEET2"])
        XCTAssertEqual(body.sheets.first?.manifest_url, "/api/v1/test_sheets/SHEET1/manifest")
        XCTAssertNil(body.sheets.first?.title)
        XCTAssertEqual(body.sheets.last?.title, "July LPS sheet")

        let request = try XCTUnwrap(recorder.requests.first)
        XCTAssertEqual(request.method, "GET")
        XCTAssertEqual(request.path, "/api/v1/test_sheets/recent")
        XCTAssertEqual(request.operationID, "getRecentSheets")
    }

    func test_createCapture_postsNestedMetadataAndQualityAndDecodesCreatedCapture() async throws {
        let recorder = RequestRecorder()
        let client = makeClient(recorder: recorder) { _, _, _ in
            Self.jsonResponse(.created, #"{"capture_id":"42"}"#)
        }

        let metadata = Components.Schemas.CaptureMetadata(
            device_model: "iPhone 15",
            lens: "built_in_wide_angle",
            exposure_duration_seconds: 0.016,
            iso: 100,
            focus_lens_position: 0.42,
            white_balance_gains: nil,
            image_width: 4032,
            image_height: 3024,
            app_version: "0.1.0",
            timestamp: Self.iso8601Date("2026-07-25T12:00:00Z")
        )
        let quality = Components.Schemas.CaptureRequest.QualityPayload(
            detected_marker_count: 4,
            blur_score: 0.82,
            rejections: ["glare"]
        )
        let body = Components.Schemas.CaptureRequest(metadata: metadata, quality: quality)

        let response = try await client.createCapture(
            .init(path: .init(sheet_id: "SHEET1"), body: .json(body))
        )

        XCTAssertEqual(try response.created.body.json.capture_id, "42")

        let request = try XCTUnwrap(recorder.requests.first)
        XCTAssertEqual(request.method, "POST")
        XCTAssertEqual(request.path, "/api/v1/test_sheets/SHEET1/captures")
        XCTAssertEqual(request.operationID, "createCapture")
        let json = try XCTUnwrap(request.bodyJSON)
        let metadataJSON = try XCTUnwrap(json["metadata"] as? [String: Any])
        XCTAssertEqual(metadataJSON["device_model"] as? String, "iPhone 15")
        XCTAssertEqual(metadataJSON["iso"] as? Int, 100)
        XCTAssertEqual(metadataJSON["exposure_duration_seconds"] as? Double, 0.016)
        XCTAssertEqual(metadataJSON["timestamp"] as? String, "2026-07-25T12:00:00Z")
        let qualityJSON = try XCTUnwrap(json["quality"] as? [String: Any])
        XCTAssertEqual(qualityJSON["detected_marker_count"] as? Int, 4)
        XCTAssertEqual(qualityJSON["rejections"] as? [String], ["glare"])
    }

    func test_uploadMeasurements_sendsSpecPayloadAndDecodesCountedResponse() async throws {
        let recorder = RequestRecorder()
        let client = makeClient(recorder: recorder) { _, _, _ in
            Self.jsonResponse(.ok, #"{"capture_id":"42","measurement_count":1,"pair_score_count":1}"#)
        }

        let rgb = Components.Schemas.RgbPayload(value2: .init(r: 0.12, g: 0.1, b: 0.02))
        let measurement = Components.Schemas.MeasurementPayload(
            patch_id: "pair_1#first",
            linear_rgb_median: rgb,
            normalized_linear_rgb_median: rgb
        )
        let score = Components.Schemas.PairScoreRequest(
            pair_id: "pair_1",
            algorithm_version: "lps-distance-v1",
            score: nil,
            similarity: 0.965,
            distance: 0.035
        )
        let body = Components.Schemas.MeasurementUploadRequest(
            measurements: [measurement],
            pair_scores: [score]
        )

        let response = try await client.uploadMeasurements(
            .init(path: .init(capture_id: "42"), body: .json(body))
        )

        let counted = try response.ok.body.json
        XCTAssertEqual(counted.capture_id, "42")
        XCTAssertEqual(counted.measurement_count, 1)
        XCTAssertEqual(counted.pair_score_count, 1)

        let request = try XCTUnwrap(recorder.requests.first)
        XCTAssertEqual(request.method, "POST")
        XCTAssertEqual(request.path, "/api/v1/captures/42/measurements")
        XCTAssertEqual(request.operationID, "uploadMeasurements")
        let json = try XCTUnwrap(request.bodyJSON)
        let measurementJSON = try XCTUnwrap((json["measurements"] as? [[String: Any]])?.first)
        XCTAssertEqual(measurementJSON["patch_id"] as? String, "pair_1#first")
        let medianJSON = try XCTUnwrap(measurementJSON["linear_rgb_median"] as? [String: Any])
        XCTAssertEqual(medianJSON["r"] as? Double, 0.12)
        XCTAssertEqual(medianJSON["g"] as? Double, 0.1)
        XCTAssertEqual(medianJSON["b"] as? Double, 0.02)
        let scoreJSON = try XCTUnwrap((json["pair_scores"] as? [[String: Any]])?.first)
        XCTAssertEqual(scoreJSON["pair_id"] as? String, "pair_1")
        XCTAssertEqual(scoreJSON["algorithm_version"] as? String, "lps-distance-v1")
        XCTAssertEqual(scoreJSON["similarity"] as? Double, 0.965)
        XCTAssertEqual(scoreJSON["distance"] as? Double, 0.035)
    }

    func test_uploadJudgments_sendsSpecPayloadAndDecodesCountedResponse() async throws {
        let recorder = RequestRecorder()
        let client = makeClient(recorder: recorder) { _, _, _ in
            Self.jsonResponse(.ok, #"{"capture_id":"42","judgment_count":1}"#)
        }

        let judgment = Components.Schemas.JudgmentPayload(pair_id: "pair_1", judgment: "near_match")
        let body = Components.Schemas.JudgmentUploadRequest(judgments: [judgment])

        let response = try await client.uploadJudgments(
            .init(path: .init(capture_id: "42"), body: .json(body))
        )

        let counted = try response.ok.body.json
        XCTAssertEqual(counted.capture_id, "42")
        XCTAssertEqual(counted.judgment_count, 1)

        let request = try XCTUnwrap(recorder.requests.first)
        XCTAssertEqual(request.method, "POST")
        XCTAssertEqual(request.path, "/api/v1/captures/42/judgments")
        XCTAssertEqual(request.operationID, "uploadJudgments")
        let json = try XCTUnwrap(request.bodyJSON)
        let judgmentJSON = try XCTUnwrap((json["judgments"] as? [[String: Any]])?.first)
        XCTAssertEqual(judgmentJSON["pair_id"] as? String, "pair_1")
        XCTAssertEqual(judgmentJSON["judgment"] as? String, "near_match")
    }

    func test_getRankedResults_decodesSchemaVersionedPayload() async throws {
        let recorder = RequestRecorder()
        let client = makeClient(recorder: recorder) { _, _, _ in
            Self.jsonResponse(.ok, #"{"schema_version":"lps-ranked-results/v1","sheet_id":"SHEET1"}"#)
        }

        let response = try await client.getRankedResults(.init(path: .init(sheet_id: "SHEET1")))

        let results = try response.ok.body.json
        XCTAssertEqual(results.schema_version, "lps-ranked-results/v1")
        XCTAssertEqual(results.sheet_id, "SHEET1")

        let request = try XCTUnwrap(recorder.requests.first)
        XCTAssertEqual(request.method, "GET")
        XCTAssertEqual(request.path, "/api/v1/test_sheets/SHEET1/ranked_results")
        XCTAssertEqual(request.operationID, "getRankedResults")
    }

    func test_bearerMiddlewareAuthorizesRequestsPerSecurityScheme() async throws {
        let recorder = RequestRecorder()
        let transport = StubTransport { request, body, operationID in
            await recorder.record(request, body: body, operationID: operationID)
            return Self.jsonResponse(.ok, #"{"sheets":[]}"#)
        }
        let client = Client(
            serverURL: serverURL,
            transport: transport,
            middlewares: [BearerMiddleware(token: "t0k3n")]
        )

        _ = try await client.getRecentSheets(.init())

        let request = try XCTUnwrap(recorder.requests.first)
        XCTAssertEqual(request.authorization, "Bearer t0k3n")
    }
}

private extension GeneratedClientContractTests {
    static let renderedManifestJSON = #"""
    {
      "schema_version": "lps-sheet-manifest/v1",
      "sheet_id": "SHEET1",
      "sheet_version": "lps-letter-grid-v1",
      "manifest_url": "/api/v1/test_sheets/SHEET1/manifest",
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
    """#

    static func iso8601Date(_ string: String) -> Date {
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: string)!
    }

    static func jsonResponse(_ status: HTTPRequest.Status, _ payload: String) -> (HTTPResponse, HTTPBody?) {
        (
            HTTPResponse(
                status: status,
                headerFields: [HTTPField(name: "content-type", value: "application/json")]
            ),
            HTTPBody(Data(payload.utf8))
        )
    }

    func makeClient(
        recorder: RequestRecorder? = nil,
        respond: @escaping @Sendable (HTTPRequest, HTTPBody?, String) async throws -> (HTTPResponse, HTTPBody?)
    ) -> Client {
        let transport: StubTransport
        if let recorder {
            transport = StubTransport { request, body, operationID in
                await recorder.record(request, body: body, operationID: operationID)
                return try await respond(request, body, operationID)
            }
        } else {
            transport = StubTransport(respond: respond)
        }
        return Client(serverURL: serverURL, transport: transport)
    }
}

private struct StubTransport: ClientTransport {
    let respond: @Sendable (HTTPRequest, HTTPBody?, String) async throws -> (HTTPResponse, HTTPBody?)

    init(respond: @escaping @Sendable (HTTPRequest, HTTPBody?, String) async throws -> (HTTPResponse, HTTPBody?)) {
        self.respond = respond
    }

    func send(_ request: HTTPRequest, body: HTTPBody?, baseURL: URL, operationID: String) async throws -> (HTTPResponse, HTTPBody?) {
        try await respond(request, body, operationID)
    }
}

private struct BearerMiddleware: ClientMiddleware {
    let token: String

    func intercept(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String,
        next: @Sendable (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
    ) async throws -> (HTTPResponse, HTTPBody?) {
        var authorizedRequest = request
        authorizedRequest.headerFields.append(HTTPField(name: "authorization", value: "Bearer \(token)"))
        return try await next(authorizedRequest, body, baseURL)
    }
}

private final class RequestRecorder: @unchecked Sendable {
    struct RecordedRequest {
        var method: String
        var path: String
        var operationID: String
        var authorization: String?
        var bodyJSON: [String: Any]?
    }

    private let lock = NSLock()
    private var recordedRequests: [RecordedRequest] = []

    var requests: [RecordedRequest] {
        lock.lock()
        defer { lock.unlock() }
        return recordedRequests
    }

    func record(_ request: HTTPRequest, body: HTTPBody?, operationID: String) async {
        var bodyJSON: [String: Any]?
        if let body, let data = try? await Data(collecting: body, upTo: 1 << 24) {
            bodyJSON = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        }
        let recorded = RecordedRequest(
            method: request.method.rawValue,
            path: request.path ?? "",
            operationID: operationID,
            authorization: request.headerFields.first { $0.name == .authorization }?.value,
            bodyJSON: bodyJSON
        )
        lock.lock()
        defer { lock.unlock() }
        recordedRequests.append(recorded)
    }
}
#endif
