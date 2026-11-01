#if canImport(OpenAPIGenerated) && canImport(OpenAPIRuntime) && canImport(HTTPTypes)
import Foundation
import HTTPTypes
import OpenAPIGenerated
import OpenAPIRuntime
import XCTest

/// Exercises the generated OpenAPI client for the surfaces this app consumes,
/// against locally stubbed HTTP responses (no live server).
///
/// The generated module must be named `OpenAPIGenerated` and produced with
/// `namingStrategy: idiomatic` from the vendored `openapi.json` published by
/// viamin/color_matching#110. The full contract — including the operationId to
/// method-name mapping these tests rely on — is pinned in
/// docs/color-matching-openapi-client.md.
final class OpenAPIGeneratedClientTests: XCTestCase {
    private static let baseURL = URL(string: "https://color-matching.example.test")!

    func testFetchManifestDecodesVersionedManifestAndSendsExpectedRequest() async throws {
        let transport = RecordingStubTransport { _ in
            Self.okJSON(#"""
            {
              "schema_version": "lps-sheet-manifest/v1",
              "sheet_id": "sheet_123",
              "capture_profile": {"scoring_algorithm_version": "lps-distance-v1"},
              "sheet_version": "lps-letter-grid-v1",
              "patches": [{"id": "patch_1", "role": "pair_color"}]
            }
            """#)
        }

        let response = try await Self.makeClient(transport)
            .colorMatchingWeb_TestSheetController_manifest(.init(path: .init(sheetId: "sheet_123")))

        guard case let .ok(payload) = response else { return XCTFail("Expected 200 ok, got: \(response)") }
        let manifest = payload.body.json
        XCTAssertEqual(manifest.schemaVersion, .lpsSheetManifestV1)
        XCTAssertEqual(manifest.schemaVersion.rawValue, "lps-sheet-manifest/v1")
        XCTAssertEqual(manifest.sheetId, "sheet_123")
        XCTAssertEqual(manifest.captureProfile.scoringAlgorithmVersion, .lpsDistanceV1)

        let call = try XCTUnwrap(transport.recordedCalls.first)
        XCTAssertEqual(call.method, "GET")
        XCTAssertEqual(call.path, "/api/v1/test_sheets/sheet_123/manifest")
        XCTAssertEqual(call.operationID, "ColorMatchingWeb.TestSheetController.manifest")
    }

    func testFetchManifestSurfacesNotFoundErrorCase() async throws {
        let transport = RecordingStubTransport { _ in
            Self.statusJSON(.notFound, #"{"errors":{"detail":"Sheet not found"}}"#)
        }

        let response = try await Self.makeClient(transport)
            .colorMatchingWeb_TestSheetController_manifest(.init(path: .init(sheetId: "missing")))

        guard case .notFound = response else { return XCTFail("Expected 404 notFound, got: \(response)") }
        let call = try XCTUnwrap(transport.recordedCalls.first)
        XCTAssertEqual(call.path, "/api/v1/test_sheets/missing/manifest")
    }

    func testFetchRecentSheetsDecodesNullableTitles() async throws {
        let transport = RecordingStubTransport { _ in
            Self.okJSON(#"""
            {
              "sheets": [
                {
                  "sheet_id": "sheet_123",
                  "manifest_url": "https://color-matching.example.test/api/v1/test_sheets/sheet_123/manifest",
                  "title": "July LPS comparison sheet"
                },
                {
                  "sheet_id": "sheet_456",
                  "manifest_url": "https://color-matching.example.test/api/v1/test_sheets/sheet_456/manifest",
                  "title": null
                }
              ]
            }
            """#)
        }

        let response = try await Self.makeClient(transport).colorMatchingWeb_TestSheetController_recent(.init())

        guard case let .ok(payload) = response else { return XCTFail("Expected 200 ok, got: \(response)") }
        let sheets = payload.body.json.sheets
        XCTAssertEqual(sheets.count, 2)
        XCTAssertEqual(sheets.first?.sheetId, "sheet_123")
        XCTAssertEqual(sheets.first?.title, "July LPS comparison sheet")
        XCTAssertEqual(sheets.last?.sheetId, "sheet_456")
        XCTAssertNil(sheets.last?.title)
        XCTAssertEqual(sheets.last?.manifestUrl, "https://color-matching.example.test/api/v1/test_sheets/sheet_456/manifest")
        XCTAssertEqual(transport.recordedCalls.first?.path, "/api/v1/test_sheets/recent")
    }

    func testCreateCaptureEncodesMetadataAndQualityAndDecodesCaptureID() async throws {
        let transport = RecordingStubTransport { _ in
            Self.statusJSON(.created, #"{"capture_id":"capture_123"}"#)
        }

        let response = try await Self.makeClient(transport).colorMatchingWeb_CaptureController_create(
            .init(
                path: .init(sheetId: "sheet_123"),
                body: .init(
                    metadata: .init(
                        deviceModel: "iPhone 15",
                        lens: "built_in_wide_angle",
                        imageWidth: 4032,
                        imageHeight: 3024,
                        appVersion: "0.1.0",
                        timestamp: Date(timeIntervalSince1970: 1_782_000_000)
                    ),
                    quality: .init(detectedMarkerCount: 4, blurScore: 0.82, rejections: [])
                )
            )
        )

        guard case let .created(payload) = response else { return XCTFail("Expected 201 created, got: \(response)") }
        XCTAssertEqual(payload.body.json.captureId, "capture_123")

        let call = try XCTUnwrap(transport.recordedCalls.first)
        XCTAssertEqual(call.method, "POST")
        XCTAssertEqual(call.path, "/api/v1/test_sheets/sheet_123/captures")
        XCTAssertEqual(call.operationID, "ColorMatchingWeb.CaptureController.create")
        XCTAssertEqual(call.contentType, "application/json")

        let json = try Self.jsonObject(call.body)
        let metadata = try XCTUnwrap(json["metadata"] as? [String: Any])
        XCTAssertEqual(metadata["device_model"] as? String, "iPhone 15")
        XCTAssertEqual(metadata["lens"] as? String, "built_in_wide_angle")
        XCTAssertEqual(metadata["image_width"] as? Int, 4032)
        XCTAssertEqual(metadata["image_height"] as? Int, 3024)
        XCTAssertNotNil(metadata["timestamp"] as? String)
        let quality = try XCTUnwrap(json["quality"] as? [String: Any])
        XCTAssertEqual(quality["detected_marker_count"] as? Int, 4)
        XCTAssertEqual(try XCTUnwrap(quality["blur_score"] as? Double), 0.82, accuracy: 1e-9)
        XCTAssertEqual(quality["rejections"] as? [String], [])
    }

    func testUploadMeasurementsEncodesPublishedWireShapeAndDecodesCounts() async throws {
        let transport = RecordingStubTransport { _ in
            Self.okJSON(#"{"capture_id":"cap_1","measurement_count":1,"pair_score_count":1}"#)
        }

        let response = try await Self.makeClient(transport)
            .colorMatchingWeb_CaptureController_uploadMeasurements(
                .init(
                    path: .init(captureId: "cap_1"),
                    body: .init(
                        measurements: [
                            .init(
                                patchId: "patch_1",
                                linearRgbMedian: .init(case2: .init(r: 0.12, g: 0.1, b: 0.02)),
                                normalizedLinearRgbMedian: .init(case1: [0.15, 0.12, 0.02])
                            )
                        ],
                        pairScores: [
                            .init(pairId: "pair_1", algorithmVersion: "lps-distance-v1", similarity: 0.965)
                        ]
                    )
                )
            )

        guard case let .ok(payload) = response else { return XCTFail("Expected 200 ok, got: \(response)") }
        XCTAssertEqual(payload.body.json.captureId, "cap_1")
        XCTAssertEqual(payload.body.json.measurementCount, 1)
        XCTAssertEqual(payload.body.json.pairScoreCount, 1)

        let call = try XCTUnwrap(transport.recordedCalls.first)
        XCTAssertEqual(call.method, "POST")
        XCTAssertEqual(call.path, "/api/v1/captures/cap_1/measurements")
        XCTAssertEqual(call.operationID, "ColorMatchingWeb.CaptureController.upload_measurements")

        let json = try Self.jsonObject(call.body)
        XCTAssertNil(json["scoring_algorithm_version"], "published spec moved the algorithm version onto each pair score")
        let measurements = try XCTUnwrap(json["measurements"] as? [[String: Any]])
        XCTAssertEqual(measurements.count, 1)
        let measurement = try XCTUnwrap(measurements.first)
        XCTAssertEqual(measurement["patch_id"] as? String, "patch_1")
        XCTAssertNil(measurement["stats"], "published spec has no per-measurement stats block")
        let median = try XCTUnwrap(measurement["linear_rgb_median"] as? [String: Double])
        XCTAssertEqual(median["r"] ?? 0, 0.12, accuracy: 1e-9)
        XCTAssertEqual(median["g"] ?? 0, 0.1, accuracy: 1e-9)
        XCTAssertEqual(median["b"] ?? 0, 0.02, accuracy: 1e-9)
        XCTAssertEqual(measurement["normalized_linear_rgb_median"] as? [Double], [0.15, 0.12, 0.02])
        let pairScores = try XCTUnwrap(json["pair_scores"] as? [[String: Any]])
        XCTAssertEqual(pairScores.first?["pair_id"] as? String, "pair_1")
        XCTAssertEqual(pairScores.first?["algorithm_version"] as? String, "lps-distance-v1")
        XCTAssertEqual(try XCTUnwrap(pairScores.first?["similarity"] as? Double), 0.965, accuracy: 1e-9)
    }

    func testUploadJudgmentsEncodesPairJudgmentsAndDecodesCount() async throws {
        let transport = RecordingStubTransport { _ in
            Self.okJSON(#"{"capture_id":"cap_1","judgment_count":2}"#)
        }

        let response = try await Self.makeClient(transport).colorMatchingWeb_CaptureController_uploadJudgments(
            .init(
                path: .init(captureId: "cap_1"),
                body: .init(
                    judgments: [
                        .init(pairId: "pair_1", judgment: "near_match"),
                        .init(pairId: "pair_2", judgment: "match")
                    ]
                )
            )
        )

        guard case let .ok(payload) = response else { return XCTFail("Expected 200 ok, got: \(response)") }
        XCTAssertEqual(payload.body.json.captureId, "cap_1")
        XCTAssertEqual(payload.body.json.judgmentCount, 2)

        let call = try XCTUnwrap(transport.recordedCalls.first)
        XCTAssertEqual(call.method, "POST")
        XCTAssertEqual(call.path, "/api/v1/captures/cap_1/judgments")
        XCTAssertEqual(call.operationID, "ColorMatchingWeb.CaptureController.upload_judgments")

        let json = try Self.jsonObject(call.body)
        let judgments = try XCTUnwrap(json["judgments"] as? [[String: Any]])
        XCTAssertEqual(judgments.count, 2)
        XCTAssertEqual(judgments.first?["pair_id"] as? String, "pair_1")
        XCTAssertEqual(judgments.first?["judgment"] as? String, "near_match")
        XCTAssertEqual(judgments.last?["pair_id"] as? String, "pair_2")
        XCTAssertEqual(judgments.last?["judgment"] as? String, "match")
    }

    func testFetchRankedResultsDecodesVersionedResults() async throws {
        let transport = RecordingStubTransport { _ in
            Self.okJSON(#"""
            {
              "schema_version": "lps-ranked-results/v1",
              "sheet_id": "sheet_123",
              "pairs": [{"pair_id": "pair_1", "distance": 0.035, "similarity": 0.965}]
            }
            """#)
        }

        let response = try await Self.makeClient(transport)
            .colorMatchingWeb_TestSheetController_rankedResults(.init(path: .init(sheetId: "sheet_123")))

        guard case let .ok(payload) = response else { return XCTFail("Expected 200 ok, got: \(response)") }
        let ranked = payload.body.json
        XCTAssertEqual(ranked.schemaVersion, .lpsRankedResultsV1)
        XCTAssertEqual(ranked.schemaVersion.rawValue, "lps-ranked-results/v1")
        XCTAssertEqual(ranked.sheetId, "sheet_123")

        let call = try XCTUnwrap(transport.recordedCalls.first)
        XCTAssertEqual(call.method, "GET")
        XCTAssertEqual(call.path, "/api/v1/test_sheets/sheet_123/ranked_results")
        XCTAssertEqual(call.operationID, "ColorMatchingWeb.TestSheetController.ranked_results")
    }

    private static func makeClient(_ transport: RecordingStubTransport) -> OpenAPIGenerated.Client {
        OpenAPIGenerated.Client(serverURL: baseURL, transport: transport)
    }

    private static func okJSON(_ payload: String) -> (HTTPResponse, Data?) {
        statusJSON(.ok, payload)
    }

    private static func statusJSON(_ status: HTTPResponse.Status, _ payload: String) -> (HTTPResponse, Data?) {
        (HTTPResponse(status: status, headerFields: [.contentType: "application/json"]), Data(payload.utf8))
    }

    private static func jsonObject(_ data: Data?) throws -> [String: Any] {
        try XCTUnwrap(try JSONSerialization.jsonObject(with: XCTUnwrap(data)) as? [String: Any])
    }
}

/// A `ClientTransport` that records the generated client's outgoing requests
/// and replies with canned responses.
private final class RecordingStubTransport: ClientTransport, @unchecked Sendable {
    struct RecordedCall {
        let method: String
        let path: String
        let operationID: String
        let contentType: String?
        let body: Data?
    }

    private let respond: @Sendable (RecordedCall) -> (HTTPResponse, Data?)
    private var calls: [RecordedCall] = []
    var recordedCalls: [RecordedCall] { calls }

    init(respond: @escaping @Sendable (RecordedCall) -> (HTTPResponse, Data?)) {
        self.respond = respond
    }

    func send(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String
    ) async throws -> (HTTPResponse, HTTPBody?) {
        let call = RecordedCall(
            method: request.method.rawValue,
            path: request.path ?? "",
            operationID: operationID,
            contentType: request.headerFields[.contentType],
            body: try await Self.collect(body)
        )
        calls.append(call)
        let (response, data) = respond(call)
        return (response, data.map { HTTPBody($0) })
    }

    private static func collect(_ body: HTTPBody?) async throws -> Data? {
        guard let body else { return nil }
        Data(try await [UInt8](collecting: body, upTo: 1 << 20))
    }
}
#else
import XCTest

/// Red-phase placeholder: fails until issue #5's implementation vendors the
/// OpenAPI document and adds the generated `OpenAPIGenerated` client target.
final class OpenAPIGeneratedClientTests: XCTestCase {
    func testGeneratedOpenAPIClientTargetExists() {
        XCTFail(
            "The OpenAPIGenerated client target is not wired up yet. Issue #5 requires vendoring "
                + "the OpenAPI document published by viamin/color_matching#110 and generating a typed "
                + "client; see docs/color-matching-openapi-client.md for the pinned contract "
                + "(module name, spec path, and generator config)."
        )
    }
}
#endif
