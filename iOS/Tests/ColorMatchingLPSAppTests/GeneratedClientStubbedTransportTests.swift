import XCTest
import OpenAPIRuntime
import ColorMatchingAPI

final class GeneratedClientStubbedTransportTests: XCTestCase {
    private var serverURL: URL { URL(string: "https://example.test")! }

    func testGetTestSheetManifestDecodesStubbedManifest() async throws {
        var recordedMethod: HTTPRequest.Method?
        var recordedPath: String?
        var recordedOperationID: String?

        let response = try await Client(serverURL: serverURL, transport: StubTransport { request, operationID in
            recordedMethod = request.method
            recordedPath = request.path
            recordedOperationID = operationID
            return Self.jsonResponse(.ok, OpenAPIFixtures.manifest)
        }).getTestSheetManifest(path: .init(sheet_id: "sheet_1"))

        XCTAssertEqual(recordedOperationID, "getTestSheetManifest")
        XCTAssertEqual(recordedMethod, .get)
        XCTAssertEqual(recordedPath, "/api/v1/test_sheets/sheet_1/manifest")

        guard case .ok(let ok) = response else { return XCTFail("expected 200 for manifest") }
        guard case .json(let manifest) = ok.body else { return XCTFail("expected JSON body for manifest") }
        XCTAssertEqual(manifest.schema_version, "lps-sheet-manifest/v1")
        XCTAssertEqual(manifest.sheet_id, "sheet_1")
        XCTAssertEqual(manifest.capture_profile?.scoring_algorithm_version, "lps-distance-v1")
        XCTAssertEqual(manifest.patches?.count, 2)
        XCTAssertEqual(manifest.patches?.first?.pair_side, "first")
        XCTAssertEqual(manifest.pairs?.first?.source_colors?.count, 2)
    }

    func testListRecentSheetsDecodesNullAndPresentTitles() async throws {
        var recordedPath: String?
        var recordedOperationID: String?

        let response = try await Client(serverURL: serverURL, transport: StubTransport { request, operationID in
            recordedPath = request.path
            recordedOperationID = operationID
            return Self.jsonResponse(.ok, OpenAPIFixtures.recentSheets)
        }).listRecentTestSheets()

        XCTAssertEqual(recordedOperationID, "listRecentTestSheets")
        XCTAssertEqual(recordedPath, "/api/v1/test_sheets/recent")

        guard case .ok(let ok) = response else { return XCTFail("expected 200 for recent sheets") }
        guard case .json(let payload) = ok.body else { return XCTFail("expected JSON body for recent sheets") }
        XCTAssertEqual(payload.sheets.count, 2)
        XCTAssertNil(payload.sheets.first?.title)
        XCTAssertEqual(payload.sheets.last?.title, "July LPS comparison sheet")
    }

    func testCreateCapturePostsAndDecodesIntegerStringCaptureID() async throws {
        var recordedMethod: HTTPRequest.Method?
        var recordedPath: String?
        var recordedOperationID: String?

        let metadata = Types.Schemas.CaptureMetadata(
            device_model: "iPhone",
            lens: "built_in_wide_angle",
            image_width: 4032,
            image_height: 3024,
            app_version: "0.1.0",
            timestamp: Date(timeIntervalSince1970: 1_784_980_800)
        )

        let response = try await Client(serverURL: serverURL, transport: StubTransport { request, operationID in
            recordedMethod = request.method
            recordedPath = request.path
            recordedOperationID = operationID
            return Self.jsonResponse(.created, OpenAPIFixtures.captureCreated)
        }).createCapture(path: .init(sheet_id: "sheet_1"), body: .json(.init(metadata: metadata)))

        XCTAssertEqual(recordedOperationID, "createCapture")
        XCTAssertEqual(recordedMethod, .post)
        XCTAssertEqual(recordedPath, "/api/v1/test_sheets/sheet_1/captures")

        guard case .created(let created) = response else { return XCTFail("expected 201 for capture creation") }
        guard case .json(let payload) = created.body else { return XCTFail("expected JSON body for capture creation") }
        XCTAssertEqual(payload.capture_id, "42")
    }

    func testUploadMeasurementsDecodesCountsResponse() async throws {
        var recordedMethod: HTTPRequest.Method?
        var recordedPath: String?
        var recordedOperationID: String?

        let response = try await Client(serverURL: serverURL, transport: StubTransport { request, operationID in
            recordedMethod = request.method
            recordedPath = request.path
            recordedOperationID = operationID
            return Self.jsonResponse(.ok, OpenAPIFixtures.measurementUploadResponse)
        }).uploadMeasurements(path: .init(capture_id: "42"))

        XCTAssertEqual(recordedOperationID, "uploadMeasurements")
        XCTAssertEqual(recordedMethod, .post)
        XCTAssertEqual(recordedPath, "/api/v1/captures/42/measurements")

        guard case .ok(let ok) = response else { return XCTFail("expected 200 for measurement upload") }
        guard case .json(let payload) = ok.body else { return XCTFail("expected JSON body for measurement upload") }
        XCTAssertEqual(payload.capture_id, "42")
        XCTAssertEqual(payload.measurement_count, 2)
        XCTAssertEqual(payload.pair_score_count, 1)
    }

    func testUploadJudgmentsDecodesCountResponse() async throws {
        var recordedMethod: HTTPRequest.Method?
        var recordedPath: String?
        var recordedOperationID: String?

        let response = try await Client(serverURL: serverURL, transport: StubTransport { request, operationID in
            recordedMethod = request.method
            recordedPath = request.path
            recordedOperationID = operationID
            return Self.jsonResponse(.ok, OpenAPIFixtures.judgmentUploadResponse)
        }).uploadJudgments(path: .init(capture_id: "42"))

        XCTAssertEqual(recordedOperationID, "uploadJudgments")
        XCTAssertEqual(recordedMethod, .post)
        XCTAssertEqual(recordedPath, "/api/v1/captures/42/judgments")

        guard case .ok(let ok) = response else { return XCTFail("expected 200 for judgment upload") }
        guard case .json(let payload) = ok.body else { return XCTFail("expected JSON body for judgment upload") }
        XCTAssertEqual(payload.capture_id, "42")
        XCTAssertEqual(payload.judgment_count, 1)
    }

    func testGetRankedResultsDecodesStubbedResults() async throws {
        var recordedPath: String?
        var recordedOperationID: String?

        let response = try await Client(serverURL: serverURL, transport: StubTransport { request, operationID in
            recordedPath = request.path
            recordedOperationID = operationID
            return Self.jsonResponse(.ok, OpenAPIFixtures.rankedResults)
        }).getRankedResults(path: .init(sheet_id: "sheet_1"))

        XCTAssertEqual(recordedOperationID, "getRankedResults")
        XCTAssertEqual(recordedPath, "/api/v1/test_sheets/sheet_1/ranked_results")

        guard case .ok(let ok) = response else { return XCTFail("expected 200 for ranked results") }
        guard case .json(let payload) = ok.body else { return XCTFail("expected JSON body for ranked results") }
        XCTAssertEqual(payload.schema_version, "lps-ranked-results/v1")
        XCTAssertEqual(payload.sheet_id, "sheet_1")
        XCTAssertEqual(payload.results?.first?.rank, 1)
        XCTAssertEqual(payload.results?.first?.pair_id, "pair_1")
        XCTAssertEqual(payload.results?.first?.current_judgment, "near_match")
        XCTAssertEqual(payload.results?.first?.source_colors?.color_a_hex, "#FF0000")
        XCTAssertEqual(payload.results?.first?.score?.average ?? 0, 0.04, accuracy: 0.0001)
    }

    func testUnauthorizedResponseIsTypedByGeneratedClient() async throws {
        let response = try await Client(serverURL: serverURL, transport: StubTransport { _, _ in
            Self.jsonResponse(.unauthorized, OpenAPIFixtures.errorResponse)
        }).getTestSheetManifest(path: .init(sheet_id: "sheet_1"))

        guard case .unauthorized = response else { return XCTFail("expected .unauthorized for status 401") }
    }

    func testNotFoundResponseIsTypedByGeneratedClient() async throws {
        let response = try await Client(serverURL: serverURL, transport: StubTransport { _, _ in
            Self.jsonResponse(.notFound, OpenAPIFixtures.errorResponse)
        }).getRankedResults(path: .init(sheet_id: "missing"))

        guard case .notFound = response else { return XCTFail("expected .notFound for status 404") }
    }

    func testBearerConfigurationAddsAuthorizationHeader() async throws {
        var authorizationHeader: String?

        let client = Client(
            serverURL: serverURL,
            transport: StubTransport { request, _ in
                authorizationHeader = request.headerFields.first { $0.name.lowercased() == "authorization" }?.value
                return Self.jsonResponse(.ok, OpenAPIFixtures.recentSheets)
            },
            configuration: .init(auth: .bearer("token"))
        )

        _ = try await client.listRecentTestSheets()

        XCTAssertEqual(authorizationHeader, "Bearer token")
    }
}

private extension GeneratedClientStubbedTransportTests {
    static func jsonResponse(_ status: HTTPResponseStatus, _ fixture: String) -> (HTTPResponse, URL?) {
        let response = HTTPResponse(
            status: status,
            headerFields: [.init(name: "content-type", value: "application/json")],
            body: HTTPBody(Data(fixture.utf8))
        )
        return (response, nil)
    }
}

private struct StubTransport: SendableTransport {
    let handler: (HTTPRequest, String) -> (HTTPResponse, URL?)

    func send(_ request: HTTPRequest, baseURL: URL, operationID: String) async throws -> (HTTPResponse, URL?) {
        handler(request, operationID)
    }
}
