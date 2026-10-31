import Foundation
import XCTest

/// Exercises the generated OpenAPI client (swift-openapi-generator output in
/// the `ColorMatchingOpenAPI` target) against fully stubbed HTTP responses —
/// no live server is contacted (issue requirement: CI never needs color_matching).
///
/// The tests in the `canImport(ColorMatchingOpenAPI)` branch encode the contract
/// the implementation run must satisfy: the vendored document
/// (`OpenAPISpecContractTests`' fixture) is the generation input, and the
/// generated symbols below are the ones swift-openapi-generator 1.14.x emits
/// for it with `namingStrategy: idiomatic`. See
/// `docs/openapi-generated-client-test-plan.md` for the full prescribed wiring.
#if canImport(ColorMatchingOpenAPI)
import ColorMatchingOpenAPI
import HTTPTypes
import OpenAPIRuntime

final class GeneratedClientContractTests: XCTestCase {

    private static let serverURL = URL(string: "https://example.test")!

    // MARK: - Test-sheet reads

    func testGetTestSheetManifestDecodesVersionedManifest() async throws {
        let stub = StubTransport(stubResponse: Self.jsonResponse(status: 200, json: """
            {"schema_version":"lps-sheet-manifest/v1","sheet_id":"sheet_123","capture_profile":{"scoring_algorithm_version":"lps-distance-v1"}}
            """))
        let client = Client(serverURL: Self.serverURL, transport: stub)

        let output = try await client.getTestSheetManifest(.init(path: .init(sheetId: "sheet_123")))

        let request = try XCTUnwrap(stub.log.requests.first)
        XCTAssertEqual(request.method, "GET")
        XCTAssertEqual(request.path, "/api/v1/test_sheets/sheet_123/manifest")

        guard case .ok(let payload) = output else { return XCTFail("Expected .ok, got: \(output)") }
        guard case .json(let manifest) = payload.body else { return XCTFail("Expected JSON body") }
        XCTAssertEqual(manifest.schemaVersion, .lpsSheetManifestV1)
        XCTAssertEqual(manifest.sheetId, "sheet_123")
        XCTAssertEqual(manifest.captureProfile?.scoringAlgorithmVersion, .lpsDistanceV1)
    }

    func testListRecentTestSheetsDecodesNullableTitle() async throws {
        let stub = StubTransport(stubResponse: Self.jsonResponse(status: 200, json: """
            {"sheets":[
              {"sheet_id":"sheet_123","manifest_url":"https://example.test/api/v1/test_sheets/sheet_123/manifest","title":null},
              {"sheet_id":"sheet_124","manifest_url":"https://example.test/api/v1/test_sheets/sheet_124/manifest","title":"July LPS comparison sheet"}
            ]}
            """))
        let client = Client(serverURL: Self.serverURL, transport: stub)

        let output = try await client.listRecentTestSheets(.init())

        let request = try XCTUnwrap(stub.log.requests.first)
        XCTAssertEqual(request.method, "GET")
        XCTAssertEqual(request.path, "/api/v1/test_sheets/recent")

        guard case .ok(let payload) = output else { return XCTFail("Expected .ok, got: \(output)") }
        guard case .json(let recent) = payload.body else { return XCTFail("Expected JSON body") }
        XCTAssertEqual(recent.sheets.count, 2)
        XCTAssertEqual(recent.sheets.first?.sheetId, "sheet_123")
        XCTAssertEqual(recent.sheets.first?.manifestUrl, "https://example.test/api/v1/test_sheets/sheet_123/manifest")
        XCTAssertNil(recent.sheets.first?.title, "the prose contract allows null titles; the generated type must too")
        XCTAssertEqual(recent.sheets.last?.title, "July LPS comparison sheet")
    }

    func testGetRankedResultsDecodesVersionedResults() async throws {
        let stub = StubTransport(stubResponse: Self.jsonResponse(status: 200, json: """
            {"schema_version":"lps-ranked-results/v1","sheet_id":"sheet_123"}
            """))
        let client = Client(serverURL: Self.serverURL, transport: stub)

        let output = try await client.getRankedResults(.init(path: .init(sheetId: "sheet_123")))

        guard case .ok(let payload) = output else { return XCTFail("Expected .ok, got: \(output)") }
        guard case .json(let ranked) = payload.body else { return XCTFail("Expected JSON body") }
        XCTAssertEqual(ranked.schemaVersion, .lpsRankedResultsV1)
        XCTAssertEqual(ranked.sheetId, "sheet_123")
    }

    // MARK: - Capture session creation

    func testCreateCaptureSendsNestedMetadataAndQualityAndDecodesCaptureID() async throws {
        let stub = StubTransport(stubResponse: Self.jsonResponse(status: 201, json: #"{"capture_id":"capture_123"}"#))
        let client = Client(serverURL: Self.serverURL, transport: stub)

        let output = try await client.createCapture(.init(
            path: .init(sheetId: "sheet_1"),
            body: .json(.init(
                metadata: .init(
                    deviceModel: "iPhone 15 Pro",
                    lens: "built_in_wide_angle",
                    imageWidth: 4032,
                    imageHeight: 3024,
                    appVersion: "0.1.0",
                    timestamp: Date(timeIntervalSince1970: 1_787_006_400)
                ),
                quality: .init(detectedMarkerCount: 4, blurScore: 0.82, rejections: [])
            ))
        ))

        let request = try XCTUnwrap(stub.log.requests.first)
        XCTAssertEqual(request.method, "POST")
        XCTAssertEqual(request.path, "/api/v1/test_sheets/sheet_1/captures")
        XCTAssertEqual(request.contentType, "application/json")

        let body = try Self.jsonObject(request.body)
        let metadata = try XCTUnwrap(body["metadata"] as? [String: Any])
        XCTAssertEqual(metadata["device_model"] as? String, "iPhone 15 Pro")
        XCTAssertEqual(metadata["lens"] as? String, "built_in_wide_angle")
        XCTAssertEqual(metadata["image_width"] as? Int, 4032)
        XCTAssertEqual(metadata["app_version"] as? String, "0.1.0")
        XCTAssertNotNil(metadata["timestamp"] as? String, "timestamp must round-trip as a date-time string")
        let quality = try XCTUnwrap(body["quality"] as? [String: Any])
        XCTAssertEqual(quality["detected_marker_count"] as? Int, 4)
        XCTAssertEqual(quality["rejections"] as? [String], [])

        guard case .created(let payload) = output else { return XCTFail("Expected .created, got: \(output)") }
        guard case .json(let created) = payload.body else { return XCTFail("Expected JSON body") }
        XCTAssertEqual(created.captureId, "capture_123")
    }

    // MARK: - Measurement upload

    func testUploadMeasurementsSendsRgbArraysAndDecodesCounts() async throws {
        let stub = StubTransport(stubResponse: Self.jsonResponse(status: 200, json: """
            {"capture_id":"capture_123","measurement_count":1,"pair_score_count":1}
            """))
        let client = Client(serverURL: Self.serverURL, transport: stub)

        let output = try await client.uploadMeasurements(.init(
            path: .init(captureId: "capture_123"),
            body: .json(.init(
                measurements: [
                    .init(
                        patchId: "patch_1",
                        linearRgbMedian: .case1([0.12, 0.10, 0.02]),
                        normalizedLinearRgbMedian: .case1([0.15, 0.12, 0.02])
                    )
                ],
                pairScores: [
                    .init(pairId: "pair_1", algorithmVersion: "lps-distance-v1", similarity: 0.965)
                ]
            ))
        ))

        let request = try XCTUnwrap(stub.log.requests.first)
        XCTAssertEqual(request.method, "POST")
        XCTAssertEqual(request.path, "/api/v1/captures/capture_123/measurements")

        let body = try Self.jsonObject(request.body)
        XCTAssertNil(body["scoring_algorithm_version"], "the published spec dropped the prose contract's top-level algorithm version")
        let measurement = try XCTUnwrap((body["measurements"] as? [[String: Any]])?.first)
        XCTAssertEqual(measurement["patch_id"] as? String, "patch_1")
        let median = try XCTUnwrap(measurement["linear_rgb_median"] as? [NSNumber])
        XCTAssertEqual(median.map(\.doubleValue), [0.12, 0.10, 0.02])
        XCTAssertNil(measurement["stats"], "the published spec dropped the prose contract's stats object")
        let pairScore = try XCTUnwrap((body["pair_scores"] as? [[String: Any]])?.first)
        XCTAssertEqual(pairScore["pair_id"] as? String, "pair_1")
        XCTAssertEqual(pairScore["algorithm_version"] as? String, "lps-distance-v1")
        XCTAssertEqual((pairScore["similarity"] as? NSNumber)?.doubleValue, 0.965)
        XCTAssertNil(pairScore["score"])

        guard case .ok(let payload) = output else { return XCTFail("Expected .ok, got: \(output)") }
        guard case .json(let accepted) = payload.body else { return XCTFail("Expected JSON body") }
        XCTAssertEqual(accepted.captureId, "capture_123")
        XCTAssertEqual(accepted.measurementCount, 1)
        XCTAssertEqual(accepted.pairScoreCount, 1)
    }

    // MARK: - Judgment upload

    func testUploadJudgmentsSendsPairsAndDecodesCount() async throws {
        let stub = StubTransport(stubResponse: Self.jsonResponse(status: 200, json: """
            {"capture_id":"capture_123","judgment_count":1}
            """))
        let client = Client(serverURL: Self.serverURL, transport: stub)

        let output = try await client.uploadJudgments(.init(
            path: .init(captureId: "capture_123"),
            body: .json(.init(judgments: [.init(pairId: "pair_1", judgment: "near_match")]))
        ))

        let request = try XCTUnwrap(stub.log.requests.first)
        XCTAssertEqual(request.method, "POST")
        XCTAssertEqual(request.path, "/api/v1/captures/capture_123/judgments")
        let body = try Self.jsonObject(request.body)
        let judgment = try XCTUnwrap((body["judgments"] as? [[String: Any]])?.first)
        XCTAssertEqual(judgment["pair_id"] as? String, "pair_1")
        XCTAssertEqual(judgment["judgment"] as? String, "near_match")

        guard case .ok(let payload) = output else { return XCTFail("Expected .ok, got: \(output)") }
        guard case .json(let accepted) = payload.body else { return XCTFail("Expected JSON body") }
        XCTAssertEqual(accepted.captureId, "capture_123")
        XCTAssertEqual(accepted.judgmentCount, 1)
    }

    // MARK: - Drift becomes typed, not a runtime surprise

    func testUnauthorizedResponseSurfacesAsTypedCase() async throws {
        let stub = StubTransport(stubResponse: Self.jsonResponse(status: 401, json: #"{"errors":{"detail":"Unauthorized"}}"#))
        let client = Client(serverURL: Self.serverURL, transport: stub)

        let output = try await client.getTestSheetManifest(.init(path: .init(sheetId: "sheet_123")))

        guard case .unauthorized = output else { return XCTFail("Expected .unauthorized, got: \(output)") }
    }

    func testMeasurementUploadWithStatusOutsideSpecSurfacesAsUndocumented() async throws {
        let stub = StubTransport(stubResponse: (HTTPResponse(status: .init(code: 204)), nil))
        let client = Client(serverURL: Self.serverURL, transport: stub)

        let output = try await client.uploadMeasurements(.init(
            path: .init(captureId: "capture_123"),
            body: .json(.init(measurements: [], pairScores: []))
        ))

        guard case .undocumented(let statusCode, _) = output else {
            return XCTFail("Expected .undocumented, got: \(output)")
        }
        XCTAssertEqual(
            statusCode,
            204,
            "the hand-written client accepted any 2xx (its tests stubbed 204); the generated client must flag off-spec statuses")
    }

    // MARK: - Helpers

    private static func jsonResponse(status: Int, json: String) -> (HTTPResponse, HTTPBody?) {
        var response = HTTPResponse(status: .init(code: status))
        response.headerFields[.contentType] = "application/json"
        return (response, HTTPBody(Data(json.utf8)))
    }

    private static func jsonObject(_ data: Data?) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(data)) as? [String: Any])
    }
}

// MARK: - Recording stub transport

private struct RecordedRequest: Sendable {
    var method: String
    var path: String?
    var contentType: String?
    var body: Data?
}

private final class RequestLog: @unchecked Sendable {
    private(set) var requests: [RecordedRequest] = []
    func append(_ request: RecordedRequest) { requests.append(request) }
}

/// A `ClientTransport` that records the outgoing request and replays a canned
/// response — the same pattern as apple/swift-openapi-generator's
/// `TestClientTransport`, so no live server is ever contacted.
private struct StubTransport: ClientTransport {
    let log = RequestLog()
    let stubResponse: @Sendable () async throws -> (HTTPResponse, HTTPBody?)

    init(stubResponse: @escaping @Sendable () async throws -> (HTTPResponse, HTTPBody?)) {
        self.stubResponse = stubResponse
    }

    func send(_ request: HTTPRequest, body: HTTPBody?, baseURL: URL, operationID: String) async throws -> (
        HTTPResponse, HTTPBody?
    ) {
        var bodyData: Data?
        if let body {
            bodyData = try await Data(collecting: body, upTo: 1 << 20)
        }
        log.append(
            RecordedRequest(
                method: request.method.rawValue,
                path: request.path,
                contentType: request.headerFields[.contentType],
                body: bodyData
            ))
        return try await stubResponse()
    }
}

#else

final class GeneratedClientContractTests: XCTestCase {
    func testGeneratedClientModuleIsWiredIntoThePackage() throws {
        throw XCTSkip(
            "ColorMatchingOpenAPI (swift-openapi-generator target) is not wired into the package yet. " +
            "The generated-client tests in this file activate once the implementation run adds the target; " +
            "see docs/openapi-generated-client-test-plan.md and docs/openapi-contract-deltas.md."
        )
    }
}

#endif
