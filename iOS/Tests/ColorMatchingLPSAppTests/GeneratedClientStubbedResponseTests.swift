#if canImport(ColorMatchingAPI)
import Foundation
import OpenAPIRuntime
import ColorMatchingAPI
import XCTest

final class GeneratedClientStubbedResponseTests: XCTestCase {
    private static let baseURL = URL(string: "https://example.test")!

    private func makeClient(_ transport: StubTransport) -> Client {
        Client(serverURL: Self.baseURL, transport: transport)
    }

    private func jsonObject(from body: Data?) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(body)) as? [String: Any])
    }

    private func dictionary(_ json: [String: Any], _ key: String) throws -> [String: Any] {
        try XCTUnwrap(json[key] as? [String: Any])
    }

    private func objectArray(_ json: [String: Any], _ key: String) throws -> [[String: Any]] {
        try XCTUnwrap(json[key] as? [[String: Any]])
    }

    func testManifestOperationDecodesVersionedManifest() async throws {
        let transport = StubTransport()
        transport.respond(with: Self.jsonResponse(.ok, """
        {"schema_version":"lps-sheet-manifest/v1","sheet_id":"sheet_123","capture_profile":{"scoring_algorithm_version":"lps-distance-v1"}}
        """))
        let response = try await makeClient(transport).ColorMatchingWeb_period_TestSheetController_period_manifest(
            .init(path: .init(sheet_id: "sheet_123"))
        )

        guard case .ok(let ok) = response else { return XCTFail("expected 200 for manifest") }
        guard case .json(let manifest) = ok.body else { return XCTFail("expected JSON manifest body") }
        XCTAssertEqual(manifest.sheet_id, "sheet_123")
        XCTAssertEqual(manifest.schema_version, .lps_hyphen_sheet_hyphen_manifest_sol_v1)
        XCTAssertEqual(manifest.capture_profile.scoring_algorithm_version, .lps_hyphen_distance_sol_v1)

        let request = try XCTUnwrap(transport.recordedRequests.first)
        XCTAssertEqual(request.method, "GET")
        XCTAssertEqual(request.path, "/api/v1/test_sheets/sheet_123/manifest")
        XCTAssertEqual(request.operationID, "ColorMatchingWeb.TestSheetController.manifest")
    }

    func testManifestOperationSurfacesNotFoundError() async throws {
        let transport = StubTransport()
        transport.respond(with: Self.jsonResponse(.notFound, #"{"errors":{"detail":"Sheet not found"}}"#))
        let response = try await makeClient(transport).ColorMatchingWeb_period_TestSheetController_period_manifest(
            .init(path: .init(sheet_id: "missing"))
        )

        guard case .notFound = response else { return XCTFail("expected 404 for missing sheet") }
    }

    func testRecentSheetsOperationDecodesNullableTitles() async throws {
        let transport = StubTransport()
        transport.respond(with: Self.jsonResponse(.ok, """
        {"sheets":[
          {"sheet_id":"sheet_123","manifest_url":"https://example.test/api/v1/test_sheets/sheet_123/manifest","title":"July LPS comparison sheet"},
          {"sheet_id":"sheet_456","manifest_url":"https://example.test/api/v1/test_sheets/sheet_456/manifest","title":null}
        ]}
        """))
        let response = try await makeClient(transport).ColorMatchingWeb_period_TestSheetController_period_recent(.init())

        guard case .ok(let ok) = response else { return XCTFail("expected 200 for recent sheets") }
        guard case .json(let payload) = ok.body else { return XCTFail("expected JSON recent sheets body") }
        XCTAssertEqual(payload.sheets.count, 2)
        XCTAssertEqual(payload.sheets.first?.title, "July LPS comparison sheet")
        XCTAssertEqual(payload.sheets.last?.sheet_id, "sheet_456")
        XCTAssertNil(payload.sheets.last?.title)

        let request = try XCTUnwrap(transport.recordedRequests.first)
        XCTAssertEqual(request.method, "GET")
        XCTAssertEqual(request.path, "/api/v1/test_sheets/recent")
        XCTAssertEqual(request.operationID, "ColorMatchingWeb.TestSheetController.recent")
    }

    func testRankedResultsOperationDecodesVersionedPayload() async throws {
        let transport = StubTransport()
        transport.respond(with: Self.jsonResponse(.ok, """
        {"schema_version":"lps-ranked-results/v1","sheet_id":"sheet_123"}
        """))
        let response = try await makeClient(transport).ColorMatchingWeb_period_TestSheetController_period_ranked_results(
            .init(path: .init(sheet_id: "sheet_123"))
        )

        guard case .ok(let ok) = response else { return XCTFail("expected 200 for ranked results") }
        guard case .json(let payload) = ok.body else { return XCTFail("expected JSON ranked results body") }
        XCTAssertEqual(payload.sheet_id, "sheet_123")
        XCTAssertEqual(payload.schema_version, .lps_hyphen_ranked_hyphen_results_sol_v1)

        let request = try XCTUnwrap(transport.recordedRequests.first)
        XCTAssertEqual(request.path, "/api/v1/test_sheets/sheet_123/ranked_results")
        XCTAssertEqual(request.operationID, "ColorMatchingWeb.TestSheetController.ranked_results")
    }

    func testCreateCaptureEncodesNestedMetadataAndQuality() async throws {
        let transport = StubTransport()
        transport.respond(with: Self.jsonResponse(.created, #"{"capture_id":"capture_123"}"#))
        let response = try await makeClient(transport).ColorMatchingWeb_period_CaptureController_period_create(
            .init(
                path: .init(sheet_id: "sheet_123"),
                body: .json(
                    .init(
                        metadata: .init(
                            device_model: "iPhone 15",
                            lens: "built_in_wide_angle_rear",
                            image_width: 4032,
                            image_height: 3024,
                            app_version: "0.1.0",
                            timestamp: Date(timeIntervalSince1970: 1_782_649_200)
                        ),
                        quality: .init(detected_marker_count: 4, blur_score: 0.75, rejections: [])
                    )
                )
            )
        )

        guard case .created(let created) = response else { return XCTFail("expected 201 for capture creation") }
        guard case .json(let payload) = created.body else { return XCTFail("expected JSON capture body") }
        XCTAssertEqual(payload.capture_id, "capture_123")

        let request = try XCTUnwrap(transport.recordedRequests.first)
        XCTAssertEqual(request.method, "POST")
        XCTAssertEqual(request.path, "/api/v1/test_sheets/sheet_123/captures")
        XCTAssertEqual(request.operationID, "ColorMatchingWeb.CaptureController.create")
        let body = try jsonObject(from: request.body)
        let metadata = try dictionary(body, "metadata")
        XCTAssertEqual(metadata["device_model"] as? String, "iPhone 15")
        XCTAssertEqual(metadata["lens"] as? String, "built_in_wide_angle_rear")
        XCTAssertEqual(metadata["image_width"] as? Int, 4032)
        XCTAssertEqual(metadata["image_height"] as? Int, 3024)
        XCTAssertEqual(metadata["app_version"] as? String, "0.1.0")
        let timestamp = try XCTUnwrap(metadata["timestamp"] as? String)
        XCTAssertNotNil(ISO8601DateFormatter().date(from: timestamp))
        let quality = try dictionary(body, "quality")
        XCTAssertEqual(quality["detected_marker_count"] as? Int, 4)
        XCTAssertEqual(quality["blur_score"] as? Double ?? -1, 0.75, accuracy: 0.0001)
        XCTAssertEqual((quality["rejections"] as? [String])?.count, 0)
    }

    func testUploadMeasurementsEncodesRgbObjectsAndPairScores() async throws {
        let transport = StubTransport()
        transport.respond(
            with: Self.jsonResponse(.ok, #"{"capture_id":"42","measurement_count":1,"pair_score_count":1}"#)
        )
        let response = try await makeClient(transport).ColorMatchingWeb_period_CaptureController_period_upload_measurements(
            .init(
                path: .init(capture_id: "42"),
                body: .json(
                    .init(
                        measurements: [
                            .init(
                                patch_id: "patch_1",
                                linear_rgb_median: .case2(.init(r: 0.12, g: 0.1, b: 0.02)),
                                normalized_linear_rgb_median: .case2(.init(r: 0.15, g: 0.12, b: 0.02))
                            )
                        ],
                        pair_scores: [
                            .init(pair_id: "pair_1", algorithm_version: "lps-distance-v1", similarity: 0.965)
                        ]
                    )
                )
            )
        )

        guard case .ok(let ok) = response else { return XCTFail("expected 200 for measurement upload") }
        guard case .json(let payload) = ok.body else { return XCTFail("expected JSON measurement upload body") }
        XCTAssertEqual(payload.capture_id, "42")
        XCTAssertEqual(payload.measurement_count, 1)
        XCTAssertEqual(payload.pair_score_count, 1)

        let request = try XCTUnwrap(transport.recordedRequests.first)
        XCTAssertEqual(request.method, "POST")
        XCTAssertEqual(request.path, "/api/v1/captures/42/measurements")
        XCTAssertEqual(request.operationID, "ColorMatchingWeb.CaptureController.upload_measurements")
        let body = try jsonObject(from: request.body)
        let measurements = try objectArray(body, "measurements")
        XCTAssertEqual(measurements.count, 1)
        XCTAssertEqual(measurements.first?["patch_id"] as? String, "patch_1")
        let median = try XCTUnwrap(measurements.first?["linear_rgb_median"] as? [String: Any])
        XCTAssertEqual(median["r"] as? Double ?? -1, 0.12, accuracy: 0.0001)
        XCTAssertEqual(median["g"] as? Double ?? -1, 0.1, accuracy: 0.0001)
        XCTAssertEqual(median["b"] as? Double ?? -1, 0.02, accuracy: 0.0001)
        let pairScores = try objectArray(body, "pair_scores")
        XCTAssertEqual(pairScores.first?["pair_id"] as? String, "pair_1")
        XCTAssertEqual(pairScores.first?["algorithm_version"] as? String, "lps-distance-v1")
        XCTAssertEqual(pairScores.first?["similarity"] as? Double ?? -1, 0.965, accuracy: 0.0001)
    }

    func testUploadJudgmentsEncodesPairJudgments() async throws {
        let transport = StubTransport()
        transport.respond(with: Self.jsonResponse(.ok, #"{"capture_id":"42","judgment_count":1}"#))
        let response = try await makeClient(transport).ColorMatchingWeb_period_CaptureController_period_upload_judgments(
            .init(
                path: .init(capture_id: "42"),
                body: .json(.init(judgments: [.init(pair_id: "pair_1", judgment: "near_match")]))
            )
        )

        guard case .ok(let ok) = response else { return XCTFail("expected 200 for judgment upload") }
        guard case .json(let payload) = ok.body else { return XCTFail("expected JSON judgment upload body") }
        XCTAssertEqual(payload.capture_id, "42")
        XCTAssertEqual(payload.judgment_count, 1)

        let request = try XCTUnwrap(transport.recordedRequests.first)
        XCTAssertEqual(request.method, "POST")
        XCTAssertEqual(request.path, "/api/v1/captures/42/judgments")
        XCTAssertEqual(request.operationID, "ColorMatchingWeb.CaptureController.upload_judgments")
        let body = try jsonObject(from: request.body)
        let judgments = try objectArray(body, "judgments")
        XCTAssertEqual(judgments.first?["pair_id"] as? String, "pair_1")
        XCTAssertEqual(judgments.first?["judgment"] as? String, "near_match")
    }

    private static func jsonResponse(_ status: HTTPResponse.Status, _ payload: String) -> (HTTPResponse, HTTPBody?) {
        var response = HTTPResponse(status: status)
        response.headerFields = [.init(name: .contentType, value: "application/json")]
        return (response, HTTPBody(Data(payload.data(using: .utf8)!)))
    }
}

private final class StubTransport: ClientTransport, @unchecked Sendable {
    private let lock = NSLock()
    private var handler: ((HTTPRequest) -> (HTTPResponse, HTTPBody?))?
    private var recorded: [(method: String, path: String, operationID: String, body: Data?)] = []

    var recordedRequests: [(method: String, path: String, operationID: String, body: Data?)] {
        lock.lock()
        defer { lock.unlock() }
        return recorded
    }

    func respond(with handler: @escaping (HTTPRequest) -> (HTTPResponse, HTTPBody?)) {
        lock.lock()
        defer { lock.unlock() }
        self.handler = handler
    }

    func send(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String
    ) async throws -> (HTTPResponse, HTTPBody?) {
        let collected = try await Self.collect(body)
        lock.lock()
        defer { lock.unlock() }
        recorded.append((request.method.name, request.path ?? "", operationID, collected))
        return try XCTUnwrap(handler)(request)
    }

    private static func collect(_ body: HTTPBody?) async throws -> Data? {
        guard let body else { return nil }
        var data = Data()
        for try await chunk in body {
            data.append(contentsOf: chunk)
        }
        return data
    }
}
#endif
