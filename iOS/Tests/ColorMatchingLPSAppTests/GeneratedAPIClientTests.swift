import Foundation
import XCTest

#if canImport(GeneratedAPIClient) && canImport(OpenAPIRuntime)
import GeneratedAPIClient
import OpenAPIRuntime

final class GeneratedAPIClientTests: XCTestCase {
    private var transport: StubTransport!

    override func tearDown() {
        transport = nil
        super.tearDown()
    }

    private func makeClient(middlewares: [any ClientMiddleware] = []) -> Client {
        Client(
            serverURL: URL(string: "https://color-matching.example.test")!,
            transport: transport,
            middlewares: middlewares
        )
    }

    func testGetTestSheetManifestDecodesSpecEnvelopeAndIgnoresUndocumentedFields() async throws {
        transport = StubTransport { _ in
            StubbedResponse(
                status: .ok,
                json: Data(
                    #"{"schema_version":"lps-sheet-manifest/v1","sheet_id":"AB12-CD34","capture_profile":{"scoring_algorithm_version":"lps-distance-v1"},"patches":[{"id":"pair_1#first"}],"pairs":[{"id":"pair_1"}]}"#.utf8
                )
            )
        }

        let response = try await makeClient().getTestSheetManifest(.init(path: .init(sheetId: "AB12-CD34")))

        let request = try recordedRequest()
        XCTAssertEqual(request.method, "GET")
        XCTAssertEqual(request.path, "/api/v1/test_sheets/AB12-CD34/manifest")
        XCTAssertEqual(request.operationID, "getTestSheetManifest")
        XCTAssertEqual(request.accept, "application/json")

        guard case .ok(let ok) = response else {
            XCTFail("Expected .ok, got \(response)")
            return
        }
        guard let body = ok.body, case .json(let manifest) = body else {
            XCTFail("Expected JSON body in .ok response")
            return
        }
        XCTAssertEqual(manifest.schemaVersion, .lpsSheetManifestV1)
        XCTAssertEqual(manifest.sheetId, "AB12-CD34")
        XCTAssertEqual(manifest.captureProfile.scoringAlgorithmVersion, .lpsDistanceV1)
    }

    func testGetTestSheetManifestSurfacesNotFoundAsTypedResponse() async throws {
        transport = StubTransport { _ in
            StubbedResponse(
                status: .notFound,
                json: Data(#"{"errors":{"detail":"Sheet not found"}}"#.utf8)
            )
        }

        let response = try await makeClient().getTestSheetManifest(.init(path: .init(sheetId: "UNKNOWN-1")))

        guard case .notFound = response else {
            XCTFail("Expected .notFound, got \(response)")
            return
        }
        XCTAssertEqual(try recordedRequest().path, "/api/v1/test_sheets/UNKNOWN-1/manifest")
    }

    func testListRecentTestSheetsDecodesSheetsAndOptionalTitle() async throws {
        transport = StubTransport { _ in
            StubbedResponse(
                status: .ok,
                json: Data(
                    #"{"sheets":[{"sheet_id":"AB12-CD34","manifest_url":"/api/v1/test_sheets/AB12-CD34/manifest","title":null},{"sheet_id":"EF56-GH78","manifest_url":"/api/v1/test_sheets/EF56-GH78/manifest","title":"July LPS comparison sheet"}]}"#.utf8
                )
            )
        }

        let response = try await makeClient().listRecentTestSheets(.init())

        let request = try recordedRequest()
        XCTAssertEqual(request.method, "GET")
        XCTAssertEqual(request.path, "/api/v1/test_sheets/recent")
        XCTAssertEqual(request.operationID, "listRecentTestSheets")

        guard case .ok(let ok) = response else {
            XCTFail("Expected .ok, got \(response)")
            return
        }
        guard let body = ok.body, case .json(let payload) = body else {
            XCTFail("Expected JSON body in .ok response")
            return
        }
        XCTAssertEqual(payload.sheets.count, 2)
        XCTAssertEqual(payload.sheets.first?.sheetId, "AB12-CD34")
        XCTAssertNil(payload.sheets.first?.title)
        XCTAssertEqual(payload.sheets.last?.title, "July LPS comparison sheet")
        XCTAssertEqual(
            payload.sheets.last?.manifestUrl,
            "/api/v1/test_sheets/EF56-GH78/manifest"
        )
    }

    func testCreateCaptureEncodesNestedMetadataAndQuality() async throws {
        transport = StubTransport { _ in
            StubbedResponse(
                status: .created,
                json: Data(#"{"capture_id":"4101"}"#.utf8)
            )
        }

        let metadata = Components.Schemas.CaptureMetadata(
            deviceModel: "iPhone16,2",
            lens: "built_in_wide_angle",
            exposureDurationSeconds: 0.016,
            iso: 100,
            focusLensPosition: 0.42,
            whiteBalanceGains: try .init(unvalidatedValue: ["red": 1.2, "green": 1.0, "blue": 1.4]),
            imageWidth: 4032,
            imageHeight: 3024,
            appVersion: "0.1.0",
            timestamp: Date(timeIntervalSince1970: 1_784_000_000)
        )
        let requestBody = Components.Schemas.CaptureRequest(
            metadata: metadata,
            quality: .init(detectedMarkerCount: 4, blurScore: 0.82, rejections: [])
        )

        let response = try await makeClient().createCapture(
            .init(path: .init(sheetId: "AB12-CD34"), body: .json(requestBody))
        )

        let request = try recordedRequest()
        XCTAssertEqual(request.method, "POST")
        XCTAssertEqual(request.path, "/api/v1/test_sheets/AB12-CD34/captures")
        XCTAssertEqual(request.operationID, "createCapture")
        XCTAssertEqual(request.contentType, "application/json")

        let json = try jsonObject(from: request.bodyData)
        let metadataPayload = try XCTUnwrap(json["metadata"] as? [String: Any])
        XCTAssertEqual(metadataPayload["device_model"] as? String, "iPhone16,2")
        XCTAssertEqual(metadataPayload["image_width"] as? Int, 4032)
        XCTAssertEqual(metadataPayload["iso"] as? Int, 100)
        let gains = try XCTUnwrap(metadataPayload["white_balance_gains"] as? [String: Any])
        XCTAssertEqual(gains["red"] as? Double, 1.2)
        let timestamp = try XCTUnwrap(metadataPayload["timestamp"] as? String)
        XCTAssertTrue(timestamp.contains("T"), "timestamp should be ISO 8601, got \(timestamp)")
        let qualityPayload = try XCTUnwrap(json["quality"] as? [String: Any])
        XCTAssertEqual(qualityPayload["detected_marker_count"] as? Int, 4)
        XCTAssertEqual(qualityPayload["blur_score"] as? Double, 0.82)
        XCTAssertEqual(qualityPayload["rejections"] as? [String], [])

        guard case .created(let created) = response else {
            XCTFail("Expected .created, got \(response)")
            return
        }
        guard let body = created.body, case .json(let payload) = body else {
            XCTFail("Expected JSON body in .created response")
            return
        }
        XCTAssertEqual(payload.captureId, "4101")
    }

    func testUploadMeasurementsEncodesRgbObjectsAndPairScores() async throws {
        transport = StubTransport { _ in
            StubbedResponse(
                status: .ok,
                json: Data(#"{"capture_id":"4101","measurement_count":1,"pair_score_count":1}"#.utf8)
            )
        }

        let rgb = Components.Schemas.RgbPayload(value2: .init(r: 0.12, g: 0.10, b: 0.02))
        let requestBody = Components.Schemas.MeasurementUploadRequest(
            measurements: [
                .init(
                    patchId: "pair_1#first",
                    linearRgbMedian: rgb,
                    normalizedLinearRgbMedian: rgb
                )
            ],
            pairScores: [
                .init(
                    pairId: "pair_1",
                    algorithmVersion: "lps-distance-v1",
                    score: nil,
                    similarity: 0.965,
                    distance: 0.035
                )
            ]
        )

        let response = try await makeClient().uploadMeasurements(
            .init(path: .init(captureId: "4101"), body: .json(requestBody))
        )

        let request = try recordedRequest()
        XCTAssertEqual(request.method, "POST")
        XCTAssertEqual(request.path, "/api/v1/captures/4101/measurements")
        XCTAssertEqual(request.operationID, "uploadMeasurements")

        let json = try jsonObject(from: request.bodyData)
        XCTAssertEqual(Set(json.keys), ["measurements", "pair_scores"])
        XCTAssertNil(json["scoring_algorithm_version"])
        let measurement = try XCTUnwrap((json["measurements"] as? [[String: Any]])?.first)
        XCTAssertEqual(measurement["patch_id"] as? String, "pair_1#first")
        XCTAssertNil(measurement["stats"])
        let median = try XCTUnwrap(measurement["linear_rgb_median"] as? [String: Any])
        XCTAssertEqual(median["r"] as? Double, 0.12)
        XCTAssertEqual(median["g"] as? Double, 0.10)
        XCTAssertEqual(median["b"] as? Double, 0.02)
        let pairScore = try XCTUnwrap((json["pair_scores"] as? [[String: Any]])?.first)
        XCTAssertEqual(pairScore["pair_id"] as? String, "pair_1")
        XCTAssertEqual(pairScore["algorithm_version"] as? String, "lps-distance-v1")
        XCTAssertEqual(pairScore["similarity"] as? Double, 0.965)
        XCTAssertEqual(pairScore["distance"] as? Double, 0.035)
        XCTAssertNil(pairScore["score"])

        guard case .ok(let ok) = response else {
            XCTFail("Expected .ok, got \(response)")
            return
        }
        guard let body = ok.body, case .json(let payload) = body else {
            XCTFail("Expected JSON body in .ok response")
            return
        }
        XCTAssertEqual(payload.captureId, "4101")
        XCTAssertEqual(payload.measurementCount, 1)
        XCTAssertEqual(payload.pairScoreCount, 1)
    }

    func testUploadJudgmentsEncodesJudgmentRows() async throws {
        transport = StubTransport { _ in
            StubbedResponse(
                status: .ok,
                json: Data(#"{"capture_id":"4101","judgment_count":1}"#.utf8)
            )
        }

        let requestBody = Components.Schemas.JudgmentUploadRequest(
            judgments: [.init(pairId: "pair_1", judgment: "near_match")]
        )

        let response = try await makeClient().uploadJudgments(
            .init(path: .init(captureId: "4101"), body: .json(requestBody))
        )

        let request = try recordedRequest()
        XCTAssertEqual(request.method, "POST")
        XCTAssertEqual(request.path, "/api/v1/captures/4101/judgments")
        XCTAssertEqual(request.operationID, "uploadJudgments")

        let json = try jsonObject(from: request.bodyData)
        let judgment = try XCTUnwrap((json["judgments"] as? [[String: Any]])?.first)
        XCTAssertEqual(judgment["pair_id"] as? String, "pair_1")
        XCTAssertEqual(judgment["judgment"] as? String, "near_match")

        guard case .ok(let ok) = response else {
            XCTFail("Expected .ok, got \(response)")
            return
        }
        guard let body = ok.body, case .json(let payload) = body else {
            XCTFail("Expected JSON body in .ok response")
            return
        }
        XCTAssertEqual(payload.captureId, "4101")
        XCTAssertEqual(payload.judgmentCount, 1)
    }

    func testGetRankedResultsDecodesSchemaVersionEnvelope() async throws {
        transport = StubTransport { _ in
            StubbedResponse(
                status: .ok,
                json: Data(#"{"schema_version":"lps-ranked-results/v1","sheet_id":"AB12-CD34"}"#.utf8)
            )
        }

        let response = try await makeClient().getRankedResults(.init(path: .init(sheetId: "AB12-CD34")))

        let request = try recordedRequest()
        XCTAssertEqual(request.method, "GET")
        XCTAssertEqual(request.path, "/api/v1/test_sheets/AB12-CD34/ranked_results")
        XCTAssertEqual(request.operationID, "getRankedResults")

        guard case .ok(let ok) = response else {
            XCTFail("Expected .ok, got \(response)")
            return
        }
        guard let body = ok.body, case .json(let payload) = body else {
            XCTFail("Expected JSON body in .ok response")
            return
        }
        XCTAssertEqual(payload.schemaVersion, .lpsRankedResultsV1)
        XCTAssertEqual(payload.sheetId, "AB12-CD34")
    }

    func testBearerAuthMiddlewareInjectsAuthorizationHeader() async throws {
        transport = StubTransport { _ in
            StubbedResponse(
                status: .ok,
                json: Data(#"{"sheets":[]}"#.utf8)
            )
        }

        let authorized = makeClient(
            middlewares: [GeneratedAPIClient.BearerAuthMiddleware(token: "secret-token")]
        )
        _ = try await authorized.listRecentTestSheets(.init())
        XCTAssertEqual(try recordedRequest().authorization, "Bearer secret-token")

        transport = StubTransport { _ in
            StubbedResponse(status: .ok, json: Data(#"{"sheets":[]}"#.utf8))
        }
        _ = try await makeClient().listRecentTestSheets(.init())
        XCTAssertNil(try recordedRequest().authorization)
    }

    private func recordedRequest() throws -> RecordedRequest {
        try XCTUnwrap(transport.requests.first)
    }

    private func jsonObject(from data: Data?) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(data)) as? [String: Any])
    }
}

private struct StubbedResponse {
    var status: HTTPResponse.Status
    var json: Data?
}

private struct RecordedRequest {
    let method: String
    let path: String
    let operationID: String
    let authorization: String?
    let accept: String?
    let contentType: String?
    let bodyData: Data?
}

private final class StubTransport: ClientTransport, @unchecked Sendable {
    private let lock = NSLock()
    private var recordedRequests: [RecordedRequest] = []
    private let respond: @Sendable (RecordedRequest) throws -> StubbedResponse

    init(respond: @escaping @Sendable (RecordedRequest) throws -> StubbedResponse) {
        self.respond = respond
    }

    var requests: [RecordedRequest] {
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
        var bodyData: Data?
        if let body {
            bodyData = try await Data(collecting: body, upTo: 1_048_576)
        }
        let record = RecordedRequest(
            method: request.method.rawValue,
            path: request.path ?? "",
            operationID: operationID,
            authorization: request.headerFields[.authorization],
            accept: request.headerFields[.accept],
            contentType: request.headerFields[.contentType],
            bodyData: bodyData
        )
        lock.lock()
        recordedRequests.append(record)
        lock.unlock()

        let stub = try respond(record)
        var headerFields = HTTPFields()
        var responseBody: HTTPBody?
        if let json = stub.json {
            headerFields[.contentType] = "application/json"
            responseBody = HTTPBody(json)
        }
        return (HTTPResponse(status: stub.status, headerFields: headerFields), responseBody)
    }
}

#else

final class GeneratedAPIClientSentinelTests: XCTestCase {
    func testGeneratedOpenAIClientTargetIsWiredIntoPackage() {
        XCTFail(
            "GeneratedAPIClient target (swift-openapi-generator + vendored openapi.json) is not wired into iOS/Package.swift yet, so generated-client tests are compiled out. See docs/openapi-generated-client.md for the expected wiring and generated identifiers."
        )
    }
}

#endif
