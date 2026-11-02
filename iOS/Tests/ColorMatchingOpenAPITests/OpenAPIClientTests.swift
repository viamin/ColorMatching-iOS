import Foundation
import ColorMatchingOpenAPI
import OpenAPIURLSession
import XCTest

/// Exercises the generated OpenAPI client against stubbed responses.
///
/// Target surface and naming are specified in `docs/ios-openapi-generated-client.md`;
/// these tests are the contract the implementation run must satisfy. No live
/// server is contacted — all responses are stubbed via `MockURLProtocol`.
final class OpenAPIClientTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.handler = nil
        super.tearDown()
    }

    func testFetchRecentSheetsDecodesGeneratedTypes() async throws {
        MockURLProtocol.handler = { request in
            (
                Self.httpResponse(request, status: 200),
                Data(
                    #"{"sheets":[{"sheet_id":"sheet_123","manifest_url":"https://example.test/api/v1/test_sheets/sheet_123/manifest","title":null}]}"#
                        .utf8
                )
            )
        }

        let response = try await client().colorMatchingWeb_TestSheetController_recent(.init())

        guard case .ok(let ok) = response else {
            XCTFail("Expected .ok, got \(response)")
            return
        }
        let body = try ok.body.json
        let sheet = try XCTUnwrap(body.sheets.first)
        XCTAssertEqual(sheet.sheetId, "sheet_123")
        XCTAssertEqual(sheet.manifestUrl, "https://example.test/api/v1/test_sheets/sheet_123/manifest")
        XCTAssertNil(sheet.title)
    }

    func testFetchManifestDecodesSchemaVersionEnums() async throws {
        var capturedRequest: URLRequest?
        MockURLProtocol.handler = { request in
            capturedRequest = request
            return (
                Self.httpResponse(request, status: 200),
                Data(
                    #"{"schema_version":"lps-sheet-manifest/v1","sheet_id":"sheet_1","capture_profile":{"scoring_algorithm_version":"lps-distance-v1"}}"#
                        .utf8
                )
            )
        }

        let input = Operations.ColorMatchingWeb_TestSheetController_manifest.Input(path: .init(sheetId: "sheet_1"))
        let response = try await client().colorMatchingWeb_TestSheetController_manifest(input)

        XCTAssertEqual(capturedRequest?.httpMethod, "GET")
        XCTAssertEqual(capturedRequest?.url?.path, "/api/v1/test_sheets/sheet_1/manifest")
        XCTAssertEqual(capturedRequest?.value(forHTTPHeaderField: "Authorization"), "Bearer token")
        XCTAssertEqual(capturedRequest?.value(forHTTPHeaderField: "Accept"), "application/json")

        guard case .ok(let ok) = response else {
            XCTFail("Expected .ok, got \(response)")
            return
        }
        let manifest = try ok.body.json
        XCTAssertEqual(manifest.schemaVersion, .lpsSheetManifestV1)
        XCTAssertEqual(manifest.sheetId, "sheet_1")
        XCTAssertEqual(manifest.captureProfile.scoringAlgorithmVersion, .lpsDistanceV1)
    }

    func testFetchRankedResultsDecodesRankedResultsSchemaVersion() async throws {
        MockURLProtocol.handler = { request in
            (
                Self.httpResponse(request, status: 200),
                Data(#"{"schema_version":"lps-ranked-results/v1","sheet_id":"sheet_1"}"#.utf8)
            )
        }

        let input = Operations.ColorMatchingWeb_TestSheetController_ranked_results.Input(path: .init(sheetId: "sheet_1"))
        let response = try await client().colorMatchingWeb_TestSheetController_ranked_results(input)

        guard case .ok(let ok) = response else {
            XCTFail("Expected .ok, got \(response)")
            return
        }
        let results = try ok.body.json
        XCTAssertEqual(results.schemaVersion, .lpsRankedResultsV1)
        XCTAssertEqual(results.sheetId, "sheet_1")
    }

    func testCreateCaptureSendsNestedMetadataAndQualityAndDecodesCaptureID() async throws {
        var capturedRequest: URLRequest?
        var capturedBody: Data?
        MockURLProtocol.handler = { request in
            capturedRequest = request
            capturedBody = request.httpBodyStream.flatMap(Self.readBody) ?? request.httpBody
            return (Self.httpResponse(request, status: 201), Data(#"{"capture_id":"cap_1"}"#.utf8))
        }

        let metadata = Components.Schemas.CaptureMetadata(
            deviceModel: "iPhone",
            lens: "built_in_wide_angle",
            exposureDurationSeconds: 0.016,
            iso: 100,
            focusLensPosition: 0.42,
            whiteBalanceGains: nil,
            imageWidth: 4032,
            imageHeight: 3024,
            appVersion: "0.1.0",
            timestamp: Date(timeIntervalSince1970: 0)
        )
        let quality = Components.Schemas.CaptureRequest.QualityPayload(
            detectedMarkerCount: 4,
            blurScore: 0.82,
            rejections: []
        )
        let input = Operations.ColorMatchingWeb_CaptureController_create.Input(
            path: .init(sheetId: "sheet_1"),
            body: .json(.init(metadata: metadata, quality: quality))
        )

        let response = try await client().colorMatchingWeb_CaptureController_create(input)

        XCTAssertEqual(capturedRequest?.httpMethod, "POST")
        XCTAssertEqual(capturedRequest?.url?.path, "/api/v1/test_sheets/sheet_1/captures")
        XCTAssertEqual(capturedRequest?.value(forHTTPHeaderField: "Authorization"), "Bearer token")
        XCTAssertEqual(capturedRequest?.value(forHTTPHeaderField: "Content-Type"), "application/json")

        let json = try XCTUnwrap(Self.jsonObject(from: capturedBody) as? [String: Any])
        let payload = try XCTUnwrap(json["metadata"] as? [String: Any])
        XCTAssertEqual(payload["device_model"] as? String, "iPhone")
        XCTAssertEqual(payload["iso"] as? Int, 100)
        XCTAssertNotNil(payload["timestamp"] as? String)
        let qualityPayload = try XCTUnwrap(json["quality"] as? [String: Any])
        XCTAssertEqual(qualityPayload["detected_marker_count"] as? Int, 4)
        XCTAssertEqual(qualityPayload["rejections"] as? [String], [])

        guard case .created(let created) = response else {
            XCTFail("Expected .created, got \(response)")
            return
        }
        XCTAssertEqual(try created.body.json.captureId, "cap_1")
    }

    func testUploadMeasurementsEncodesRgbObjectsAndPairScores() async throws {
        var capturedRequest: URLRequest?
        var capturedBody: Data?
        MockURLProtocol.handler = { request in
            capturedRequest = request
            capturedBody = request.httpBodyStream.flatMap(Self.readBody) ?? request.httpBody
            return (
                Self.httpResponse(request, status: 200),
                Data(#"{"capture_id":"cap_1","measurement_count":1,"pair_score_count":1}"#.utf8)
            )
        }

        let median = Components.Schemas.RgbPayload(value2: .init(r: 0.12, g: 0.10, b: 0.02))
        let measurement = Components.Schemas.MeasurementUploadRequest.MeasurementsPayloadPayload(
            patchId: "patch_1",
            linearRgbMedian: median,
            normalizedLinearRgbMedian: median
        )
        let score = Components.Schemas.PairScoreRequest(
            pairId: "pair_1",
            algorithmVersion: "lps-distance-v1",
            score: nil,
            similarity: 0.965,
            distance: 0.035
        )
        let input = Operations.ColorMatchingWeb_CaptureController_upload_measurements.Input(
            path: .init(captureId: "cap_1"),
            body: .json(.init(measurements: [measurement], pairScores: [score]))
        )

        let response = try await client().colorMatchingWeb_CaptureController_upload_measurements(input)

        XCTAssertEqual(capturedRequest?.httpMethod, "POST")
        XCTAssertEqual(capturedRequest?.url?.path, "/api/v1/captures/cap_1/measurements")

        let json = try XCTUnwrap(Self.jsonObject(from: capturedBody) as? [String: Any])
        let measurementPayload = try XCTUnwrap((json["measurements"] as? [[String: Any]])?.first)
        XCTAssertEqual(measurementPayload["patch_id"] as? String, "patch_1")
        let medianPayload = try XCTUnwrap(measurementPayload["linear_rgb_median"] as? [String: Any])
        XCTAssertEqual(medianPayload["r"] as? Double ?? -1, 0.12, accuracy: 0.0001)
        XCTAssertEqual(medianPayload["g"] as? Double ?? -1, 0.10, accuracy: 0.0001)
        let scorePayload = try XCTUnwrap((json["pair_scores"] as? [[String: Any]])?.first)
        XCTAssertEqual(scorePayload["pair_id"] as? String, "pair_1")
        XCTAssertEqual(scorePayload["algorithm_version"] as? String, "lps-distance-v1")
        XCTAssertEqual(scorePayload["similarity"] as? Double ?? -1, 0.965, accuracy: 0.0001)
        XCTAssertEqual(scorePayload["distance"] as? Double ?? -1, 0.035, accuracy: 0.0001)

        guard case .ok(let ok) = response else {
            XCTFail("Expected .ok with a counted JSON body, got \(response)")
            return
        }
        let counted = try ok.body.json
        XCTAssertEqual(counted.captureId, "cap_1")
        XCTAssertEqual(counted.measurementCount, 1)
        XCTAssertEqual(counted.pairScoreCount, 1)
    }

    func testUploadJudgmentsEncodesPairJudgmentsAndDecodesCount() async throws {
        var capturedBody: Data?
        MockURLProtocol.handler = { request in
            capturedBody = request.httpBodyStream.flatMap(Self.readBody) ?? request.httpBody
            return (
                Self.httpResponse(request, status: 200),
                Data(#"{"capture_id":"cap_1","judgment_count":1}"#.utf8)
            )
        }

        let judgment = Components.Schemas.JudgmentUploadRequest.JudgmentsPayloadPayload(
            pairId: "pair_1",
            judgment: "near_match"
        )
        let input = Operations.ColorMatchingWeb_CaptureController_upload_judgments.Input(
            path: .init(captureId: "cap_1"),
            body: .json(.init(judgments: [judgment]))
        )

        let response = try await client().colorMatchingWeb_CaptureController_upload_judgments(input)

        let json = try XCTUnwrap(Self.jsonObject(from: capturedBody) as? [String: Any])
        let judgmentPayload = try XCTUnwrap((json["judgments"] as? [[String: Any]])?.first)
        XCTAssertEqual(judgmentPayload["pair_id"] as? String, "pair_1")
        XCTAssertEqual(judgmentPayload["judgment"] as? String, "near_match")

        guard case .ok(let ok) = response else {
            XCTFail("Expected .ok with a counted JSON body, got \(response)")
            return
        }
        XCTAssertEqual(try ok.body.json.judgmentCount, 1)
    }

    func testUndocumentedStatusSurfacesAsUndocumentedOutput() async throws {
        MockURLProtocol.handler = { request in
            (Self.httpResponse(request, status: 500), Data())
        }

        let input = Operations.ColorMatchingWeb_TestSheetController_manifest.Input(path: .init(sheetId: "sheet_1"))
        let response = try await client().colorMatchingWeb_TestSheetController_manifest(input)

        guard case .undocumented(statusCode: let statusCode, _) = response else {
            XCTFail("Expected .undocumented, got \(response)")
            return
        }
        XCTAssertEqual(statusCode, 500)
    }

    private func client() -> Client {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        configuration.httpAdditionalHeaders = ["Authorization": "Bearer token"]
        return Client(
            serverURL: URL(string: "https://example.test")!,
            transport: URLSessionTransport(
                configuration: .init(session: URLSession(configuration: configuration))
            )
        )
    }

    private static func httpResponse(_ request: URLRequest, status: Int) -> HTTPURLResponse {
        HTTPURLResponse(
            url: request.url!,
            statusCode: status,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
    }

    private static func jsonObject(from data: Data?) throws -> Any {
        try JSONSerialization.jsonObject(with: XCTUnwrap(data))
    }

    private static func readBody(_ stream: InputStream) -> Data {
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 1024)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            if count > 0 {
                data.append(buffer, count)
            } else {
                break
            }
        }
        return data
    }
}

private final class MockURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        do {
            let (response, data) = try XCTUnwrap(Self.handler)(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
