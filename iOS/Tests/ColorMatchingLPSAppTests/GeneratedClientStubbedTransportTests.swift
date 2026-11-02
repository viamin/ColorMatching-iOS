// Guarded so this file compiles before the generated module exists: when the
// ColorMatchingOpenAPI target is wired into the test target, the stubbed-response
// tests below activate; until then the #else markers fail red for issue #5.
#if canImport(ColorMatchingOpenAPI)
import XCTest
import OpenAPIRuntime
@testable import ColorMatchingOpenAPI

final class GeneratedClientStubbedTransportTests: XCTestCase {
    func testGetSheetManifestDecodesProseContractExample() async throws {
        let transport = StubbedTransport()
        transport.responder = { _, _ in Self.jsonResponse(200, Self.manifestPayload) }
        let client = Client(serverURL: URL(string: "https://example.test")!, transport: transport)

        let output = try await client.getSheetManifest(.init(path: .init(sheet_id: "sheet_123")))

        guard case .ok(let ok) = output else { return XCTFail("Expected .ok, got \(output)") }
        let manifest = try ok.body.json
        XCTAssertEqual(manifest.schema_version, "lps-sheet-manifest/v1")
        XCTAssertEqual(manifest.sheet_id, "sheet_123")
        XCTAssertEqual(manifest.patches.first?.pair_id, "pair_1")
        XCTAssertEqual(manifest.pairs.first?.id, "pair_1")
        XCTAssertEqual(transport.recorded.first?.operationID, "getSheetManifest")
        XCTAssertEqual(transport.recorded.first?.request.path, "/api/v1/test_sheets/sheet_123/manifest")
        XCTAssertEqual(transport.recorded.first?.request.method, .get)
    }

    func testListRecentSheetsDecodesNullableTitle() async throws {
        let transport = StubbedTransport()
        transport.responder = { _, _ in
            Self.jsonResponse(200, #"{"sheets":[{"sheet_id":"sheet_123","manifest_url":"https://example.test/api/v1/test_sheets/sheet_123/manifest","title":"July LPS comparison sheet"},{"sheet_id":"sheet_124","manifest_url":"https://example.test/api/v1/test_sheets/sheet_124/manifest","title":null}]}"#)
        }
        let client = Client(serverURL: URL(string: "https://example.test")!, transport: transport)

        let output = try await client.listRecentSheets(.init())

        guard case .ok(let ok) = output else { return XCTFail("Expected .ok, got \(output)") }
        let body = try ok.body.json
        XCTAssertEqual(body.sheets.count, 2)
        XCTAssertEqual(body.sheets.first?.sheet_id, "sheet_123")
        XCTAssertEqual(body.sheets.first?.title, "July LPS comparison sheet")
        XCTAssertNil(body.sheets.last?.title)
        XCTAssertEqual(transport.recorded.first?.operationID, "listRecentSheets")
        XCTAssertEqual(transport.recorded.first?.request.path, "/api/v1/test_sheets/recent")
    }

    func testCreateCaptureSessionEncodesMetadataAndQuality() async throws {
        let transport = StubbedTransport()
        transport.responder = { _, _ in Self.jsonResponse(201, #"{"capture_id":"capture_123"}"#) }
        let client = Client(serverURL: URL(string: "https://example.test")!, transport: transport)

        let output = try await client.createCaptureSession(.init(
            path: .init(sheet_id: "sheet_123"),
            body: .json(.init(
                metadata: .init(
                    device_model: "iPhone 15",
                    lens: "built_in_wide_angle",
                    exposure_duration_seconds: 0.016,
                    iso: 100,
                    focus_lens_position: 0.42,
                    white_balance_gains: .init(red: 1.2, green: 1.0, blue: 1.4),
                    image_width: 4032,
                    image_height: 3024,
                    app_version: "0.1.0",
                    timestamp: Date(timeIntervalSince1970: 0)
                ),
                quality: .init(detected_marker_count: 4, blur_score: 0.82, rejections: [])
            ))
        ))

        guard case .created(let created) = output else { return XCTFail("Expected .created, got \(output)") }
        XCTAssertEqual(try created.body.json.capture_id, "capture_123")
        XCTAssertEqual(transport.recorded.first?.operationID, "createCaptureSession")
        XCTAssertEqual(transport.recorded.first?.request.method, .post)
        XCTAssertEqual(transport.recorded.first?.request.path, "/api/v1/test_sheets/sheet_123/captures")
        let json = try Self.jsonObject(from: transport.recorded.first?.body) as? [String: Any]
        let metadata = try XCTUnwrap(json?["metadata"] as? [String: Any])
        XCTAssertEqual(metadata["device_model"] as? String, "iPhone 15")
        XCTAssertEqual(metadata["image_width"] as? Int, 4032)
        let quality = try XCTUnwrap(json?["quality"] as? [String: Any])
        XCTAssertEqual(quality["detected_marker_count"] as? Int, 4)
        XCTAssertEqual(try XCTUnwrap(quality["blur_score"] as? Double), 0.82, accuracy: 0.0001)
    }

    func testUploadMeasurementsEncodesMeasurementsAndPairScores() async throws {
        let transport = StubbedTransport()
        transport.responder = { _, _ in Self.noContentResponse() }
        let client = Client(serverURL: URL(string: "https://example.test")!, transport: transport)

        let output = try await client.uploadMeasurements(.init(
            path: .init(capture_id: "capture_123"),
            body: .json(.init(
                scoring_algorithm_version: "lps-distance-v1",
                measurements: [
                    .init(
                        patch_id: "patch_1",
                        linear_rgb_median: .init(r: 0.12, g: 0.1, b: 0.02),
                        normalized_linear_rgb_median: .init(r: 0.15, g: 0.12, b: 0.02),
                        stats: .init(
                            sample_count: 900,
                            clipping_fraction: 0,
                            mean: .init(r: 0.12, g: 0.1, b: 0.02),
                            standard_deviation: .init(r: 0.01, g: 0.01, b: 0.004)
                        )
                    )
                ],
                pair_scores: [
                    .init(pair_id: "pair_1", distance: 0.035, similarity: 0.965, algorithm_version: "lps-distance-v1")
                ]
            ))
        ))

        guard case .noContent = output else { return XCTFail("Expected .noContent, got \(output)") }
        XCTAssertEqual(transport.recorded.first?.operationID, "uploadMeasurements")
        XCTAssertEqual(transport.recorded.first?.request.path, "/api/v1/captures/capture_123/measurements")
        let json = try Self.jsonObject(from: transport.recorded.first?.body) as? [String: Any]
        XCTAssertEqual(json?["scoring_algorithm_version"] as? String, "lps-distance-v1")
        let measurement = try XCTUnwrap((json?["measurements"] as? [[String: Any]])?.first)
        XCTAssertEqual(measurement["patch_id"] as? String, "patch_1")
        let stats = try XCTUnwrap(measurement["stats"] as? [String: Any])
        XCTAssertEqual(Set(stats.keys), ["sample_count", "clipping_fraction", "mean", "standard_deviation"])
        let pairScore = try XCTUnwrap((json?["pair_scores"] as? [[String: Any]])?.first)
        XCTAssertEqual(pairScore["pair_id"] as? String, "pair_1")
        XCTAssertEqual(try XCTUnwrap(pairScore["similarity"] as? Double), 0.965, accuracy: 0.0001)
    }

    func testUploadJudgmentsEncodesPairJudgments() async throws {
        let transport = StubbedTransport()
        transport.responder = { _, _ in Self.noContentResponse() }
        let client = Client(serverURL: URL(string: "https://example.test")!, transport: transport)

        let output = try await client.uploadJudgments(.init(
            path: .init(capture_id: "capture_123"),
            body: .json(.init(judgments: [.init(pair_id: "pair_1", judgment: .near_match)]))
        ))

        guard case .noContent = output else { return XCTFail("Expected .noContent, got \(output)") }
        XCTAssertEqual(transport.recorded.first?.operationID, "uploadJudgments")
        XCTAssertEqual(transport.recorded.first?.request.path, "/api/v1/captures/capture_123/judgments")
        let json = try Self.jsonObject(from: transport.recorded.first?.body) as? [String: Any]
        let judgment = try XCTUnwrap((json?["judgments"] as? [[String: Any]])?.first)
        XCTAssertEqual(judgment["pair_id"] as? String, "pair_1")
        XCTAssertEqual(judgment["judgment"] as? String, "near_match")
    }

    func testGetRankedResultsMapsOkResponse() async throws {
        let transport = StubbedTransport()
        transport.responder = { _, _ in Self.jsonResponse(200, #"{"pairs":[]}"#) }
        let client = Client(serverURL: URL(string: "https://example.test")!, transport: transport)

        let output = try await client.getRankedResults(.init(path: .init(sheet_id: "sheet_123")))

        guard case .ok = output else { return XCTFail("Expected .ok, got \(output)") }
        XCTAssertEqual(transport.recorded.first?.operationID, "getRankedResults")
        XCTAssertEqual(transport.recorded.first?.request.path, "/api/v1/test_sheets/sheet_123/ranked_results")
    }

    private static let manifestPayload = #"{"schema_version":"lps-sheet-manifest/v1","sheet_version":"lps-letter-grid-v1","sheet_id":"sheet_123","manifest_url":"https://example.test/api/v1/test_sheets/sheet_123/manifest","created_at":"2026-07-25T12:00:00Z","page":{"units":"mm","width":215.9,"height":279.4},"registration_markers":[{"role":"top_left","shape":"solid_square","rect":{"x":12,"y":12,"width":8,"height":8}}],"printer_profile":{"id":"printer_profile_1","name":"Research printer","paper":"paper name","ink":"ink set","settings":{}},"capture_profile":{"expected_illuminant":"low_pressure_sodium","preferred_camera":"built_in_wide_angle_rear","scoring_algorithm_version":"lps-distance-v1"},"patches":[{"id":"patch_1","role":"pair_color","pair_id":"pair_1","pair_side":"first","reference_role":null,"source_color":"#FF0000","safe_inset_mm":1.5,"rect":{"x":16,"y":38,"width":16,"height":10}}],"pairs":[{"id":"pair_1","first_patch_id":"patch_1","second_patch_id":"patch_2","source_colors":["#FF0000","#00FF00"],"grid_row":0,"grid_col":1}]}"#

    private static func jsonResponse(_ statusCode: Int, _ payload: String) -> (HTTPResponse, HTTPBody) {
        let fields = [HeaderField(name: "Content-Type", value: "application/json")]
        return (HTTPResponse(statusCode: statusCode, headerFields: fields), HTTPBody(Data(payload.utf8)))
    }

    private static func noContentResponse() -> (HTTPResponse, HTTPBody) {
        (HTTPResponse(statusCode: 204, headerFields: []), HTTPBody(Data()))
    }

    private static func jsonObject(from data: Data?) throws -> Any {
        try JSONSerialization.jsonObject(with: XCTUnwrap(data))
    }
}

private enum StubbedTransportError: Error {
    case noResponderAttached
}

private final class StubbedTransport: ClientTransport, @unchecked Sendable {
    struct Recorded {
        let operationID: String
        let request: HTTPRequest
        let body: Data
    }

    private(set) var recorded: [Recorded] = []
    var responder: ((String, HTTPRequest) -> (HTTPResponse, HTTPBody))?

    func send(_ request: HTTPRequest, body: HTTPBody, baseURL: URL, operationID: String) async throws -> (HTTPResponse, HTTPBody) {
        recorded.append(Recorded(operationID: operationID, request: request, body: try await body.collected()))
        guard let responder else { throw StubbedTransportError.noResponderAttached }
        return responder(operationID, request)
    }
}
#else
import XCTest

final class GeneratedClientNotYetWiredTests: XCTestCase {
    func testGeneratedClientModuleIsImportable() {
        XCTFail("Module 'ColorMatchingOpenAPI' is not generated/wired into the test target yet (issue #5 red phase)")
    }

    func testGetSheetManifestSurface() {
        XCTFail("Sheet manifest surface awaits the generated client (issue #5 red phase)")
    }

    func testListRecentSheetsSurface() {
        XCTFail("Recent sheets surface awaits the generated client (issue #5 red phase)")
    }

    func testCreateCaptureSessionSurface() {
        XCTFail("Capture session creation surface awaits the generated client (issue #5 red phase)")
    }

    func testUploadMeasurementsSurface() {
        XCTFail("Measurement upload surface awaits the generated client (issue #5 red phase)")
    }

    func testUploadJudgmentsSurface() {
        XCTFail("Judgment upload surface awaits the generated client (issue #5 red phase)")
    }

    func testGetRankedResultsSurface() {
        XCTFail("Ranked results surface awaits the generated client (issue #5 red phase)")
    }
}
#endif
