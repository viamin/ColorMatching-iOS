#if canImport(ColorMatchingOpenAPI) && canImport(OpenAPIRuntime)
import Foundation
import OpenAPIRuntime
import ColorMatchingOpenAPI
import XCTest

final class GeneratedClientStubbedTransportTests: XCTestCase {
    func testFetchManifestDecodesGeneratedSchemaAndToleratesUndeclaredFields() async throws {
        let manifestJSON = """
        {
          "schema_version": "lps-sheet-manifest/v1",
          "sheet_id": "sheet_1",
          "sheet_version": "lps-letter-grid-v1",
          "manifest_url": "https://example.test/api/v1/test_sheets/sheet_1/manifest",
          "page": {"units": "mm", "width": 215.9, "height": 279.4},
          "registration_markers": [],
          "capture_profile": {"scoring_algorithm_version": "lps-distance-v1"},
          "patches": [{"id": "patch_1", "role": "pair_color", "safe_inset_mm": 1.5, "rect": {"x": 16, "y": 38, "width": 16, "height": 10}}],
          "pairs": [{"id": "pair_1", "first_patch_id": "patch_1", "second_patch_id": "patch_2", "source_colors": ["#FF0000", "#00FF00"], "grid_row": 0, "grid_col": 1}]
        }
        """
        let (client, transport) = Self.stubClient(json: manifestJSON)
        let output = try await client.getTestSheetManifest(.init(path: .init(sheet_id: "sheet_1")))
        let record = try XCTUnwrap(transport.recordedRequests.first)
        XCTAssertEqual(record.method, "GET")
        XCTAssertTrue(record.path.hasSuffix("/api/v1/test_sheets/sheet_1/manifest"))
        guard case let .ok(manifest) = output else { return XCTFail("expected .ok, got \(output)") }
        XCTAssertEqual(manifest.schema_version, .lps_sheet_manifest_v1)
        XCTAssertEqual(manifest.sheet_id, "sheet_1")
        XCTAssertEqual(manifest.capture_profile.scoring_algorithm_version, .lps_distance_v1)
    }

    func testListRecentSheetsDecodesNullableTitle() async throws {
        let recentJSON = """
        {"sheets": [{"sheet_id": "sheet_1", "manifest_url": "https://example.test/api/v1/test_sheets/sheet_1/manifest", "title": null}]}
        """
        let (client, transport) = Self.stubClient(json: recentJSON)
        let output = try await client.listRecentTestSheets(.init())
        let record = try XCTUnwrap(transport.recordedRequests.first)
        XCTAssertEqual(record.method, "GET")
        XCTAssertTrue(record.path.hasSuffix("/api/v1/test_sheets/recent"))
        guard case let .ok(recent) = output else { return XCTFail("expected .ok, got \(output)") }
        let sheet = try XCTUnwrap(recent.sheets.first)
        XCTAssertEqual(sheet.sheet_id, "sheet_1")
        XCTAssertEqual(sheet.manifest_url, "https://example.test/api/v1/test_sheets/sheet_1/manifest")
        XCTAssertNil(sheet.title)
    }

    func testCreateCaptureEncodesMetadataAndQualityAndDecodesCaptureID() async throws {
        let metadata = Components.Schemas.CaptureMetadata(
            device_model: "iPhone",
            lens: "wide",
            exposure_duration_seconds: 0.01,
            iso: 100,
            focus_lens_position: 0.4,
            white_balance_gains: nil,
            image_width: 100,
            image_height: 200,
            app_version: "0.1.0",
            timestamp: Date(timeIntervalSince1970: 0)
        )
        let quality = Components.Schemas.CaptureRequest.qualityPayload(
            detected_marker_count: 4,
            blur_score: 0.75,
            rejections: []
        )
        let body = Components.Schemas.CaptureRequest(metadata: metadata, quality: quality)
        let input = Operations.createCapture.Input(path: .init(sheet_id: "sheet_1"), body: .json(body))
        let (client, transport) = Self.stubClient(status: 201, json: #"{"capture_id": "cap_1"}"#)
        let output = try await client.createCapture(input)
        let record = try XCTUnwrap(transport.recordedRequests.first)
        XCTAssertEqual(record.method, "POST")
        XCTAssertTrue(record.path.hasSuffix("/api/v1/test_sheets/sheet_1/captures"))
        let json = try Self.jsonObject(record.body)
        let metadataPayload = try XCTUnwrap(json["metadata"] as? [String: Any])
        XCTAssertEqual(metadataPayload["device_model"] as? String, "iPhone")
        let qualityPayload = try XCTUnwrap(json["quality"] as? [String: Any])
        XCTAssertEqual(qualityPayload["detected_marker_count"] as? Int, 4)
        XCTAssertEqual(qualityPayload["rejections"] as? [String], [])
        guard case let .created(created) = output else { return XCTFail("expected .created, got \(output)") }
        XCTAssertEqual(created.capture_id, "cap_1")
    }

    func testUploadMeasurementsEncodesPairScoresAndDecodesCounts() async throws {
        let rgb = Components.Schemas.RgbPayload.case2(.init(r: 0.2, g: 0.3, b: 0.4))
        let measurement = Components.Schemas.MeasurementUploadRequest.measurementsPayload(
            patch_id: "patch_1",
            linear_rgb_median: rgb,
            normalized_linear_rgb_median: rgb
        )
        let score = Components.Schemas.PairScoreRequest(
            pair_id: "pair_1",
            algorithm_version: "lps-distance-v1",
            score: nil,
            similarity: 0.9,
            distance: 0.1
        )
        let body = Components.Schemas.MeasurementUploadRequest(measurements: [measurement], pair_scores: [score])
        let input = Operations.uploadMeasurements.Input(path: .init(capture_id: "cap_1"), body: .json(body))
        let responseJSON = #"{"capture_id": "cap_1", "measurement_count": 1, "pair_score_count": 1}"#
        let (client, transport) = Self.stubClient(json: responseJSON)
        let output = try await client.uploadMeasurements(input)
        let record = try XCTUnwrap(transport.recordedRequests.first)
        XCTAssertEqual(record.method, "POST")
        XCTAssertTrue(record.path.hasSuffix("/api/v1/captures/cap_1/measurements"))
        let json = try Self.jsonObject(record.body)
        XCTAssertNil(json["scoring_algorithm_version"], "published spec carries the algorithm version per pair score, not top level")
        let measurementPayload = try XCTUnwrap((json["measurements"] as? [[String: Any]])?.first)
        XCTAssertNotNil(measurementPayload["normalized_linear_rgb_median"], "published spec requires normalized_linear_rgb_median")
        XCTAssertNil(measurementPayload["stats"], "published spec does not declare stats; tracked as an endpoint gap")
        let scorePayload = try XCTUnwrap((json["pair_scores"] as? [[String: Any]])?.first)
        XCTAssertEqual(scorePayload["algorithm_version"] as? String, "lps-distance-v1")
        XCTAssertEqual(scorePayload["distance"] as? Double, 0.1)
        guard case let .ok(uploaded) = output else { return XCTFail("expected .ok, got \(output)") }
        XCTAssertEqual(uploaded.measurement_count, 1)
        XCTAssertEqual(uploaded.pair_score_count, 1)
    }

    func testUploadJudgmentsEncodesJudgmentsAndDecodesCount() async throws {
        let judgment = Components.Schemas.JudgmentUploadRequest.judgmentsPayload(pair_id: "pair_1", judgment: "near_match")
        let body = Components.Schemas.JudgmentUploadRequest(judgments: [judgment])
        let input = Operations.uploadJudgments.Input(path: .init(capture_id: "cap_1"), body: .json(body))
        let (client, transport) = Self.stubClient(json: #"{"capture_id": "cap_1", "judgment_count": 1}"#)
        let output = try await client.uploadJudgments(input)
        let record = try XCTUnwrap(transport.recordedRequests.first)
        XCTAssertEqual(record.method, "POST")
        XCTAssertTrue(record.path.hasSuffix("/api/v1/captures/cap_1/judgments"))
        let json = try Self.jsonObject(record.body)
        let judgmentPayload = try XCTUnwrap((json["judgments"] as? [[String: Any]])?.first)
        XCTAssertEqual(judgmentPayload["judgment"] as? String, "near_match")
        guard case let .ok(uploaded) = output else { return XCTFail("expected .ok, got \(output)") }
        XCTAssertEqual(uploaded.judgment_count, 1)
    }

    func testFetchRankedResultsDecodesSchemaVersion() async throws {
        let rankedJSON = #"{"schema_version": "lps-ranked-results/v1", "sheet_id": "sheet_1"}"#
        let (client, transport) = Self.stubClient(json: rankedJSON)
        let output = try await client.getRankedResults(.init(path: .init(sheet_id: "sheet_1")))
        let record = try XCTUnwrap(transport.recordedRequests.first)
        XCTAssertEqual(record.method, "GET")
        XCTAssertTrue(record.path.hasSuffix("/api/v1/test_sheets/sheet_1/ranked_results"))
        guard case let .ok(ranked) = output else { return XCTFail("expected .ok, got \(output)") }
        XCTAssertEqual(ranked.schema_version, .lps_ranked_results_v1)
        XCTAssertEqual(ranked.sheet_id, "sheet_1")
    }

    func testUnauthorizedSurfacesAsTypedErrorCase() async throws {
        let (client, _) = Self.stubClient(status: 401, json: #"{"errors": {"detail": "Unauthorized"}}"#)
        let output = try await client.getTestSheetManifest(.init(path: .init(sheet_id: "sheet_1")))
        guard case .unauthorized = output else { return XCTFail("expected .unauthorized, got \(output)") }
    }

    private static func stubClient(status: Int = 200, json: String) -> (APIClient, StubTransport) {
        let transport = StubTransport(status: status, json: json)
        let client = APIClient(client: UniversalClient(transport: transport, config: Configuration()))
        return (client, transport)
    }

    private static func jsonObject(_ data: Data) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }
}

private final class StubTransport: ClientTransport {
    struct Record: Equatable {
        let method: String
        let path: String
        let body: Data
    }

    private let status: Int
    private let json: String
    private let lock = NSLock()
    private var records: [Record] = []

    init(status: Int = 200, json: String) {
        self.status = status
        self.json = json
    }

    var recordedRequests: [Record] {
        lock.withLock { records }
    }

    func send(_ request: HTTPRequest, metadata: HTTPRequestMetadata?, config: Config) async throws -> HTTPResponse {
        let body = try await request.body.collect(upTo: 8 * 1024 * 1024)
        lock.withLock {
            records.append(Record(method: request.method.rawValue.uppercased(), path: request.path, body: body))
        }
        return HTTPResponse(
            status: HTTPResponseStatus(statusCode: status),
            headerFields: [HTTPHeader(name: "Content-Type", value: "application/json")],
            body: HTTPBody(Data(json.utf8))
        )
    }
}

#endif
