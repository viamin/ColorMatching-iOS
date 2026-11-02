import Foundation
import XCTest

#if canImport(ColorMatchingOpenAPI) && canImport(OpenAPIRuntime)
import ColorMatchingOpenAPI
import OpenAPIRuntime

final class GeneratedOpenAPIClientTests: XCTestCase {
    private let recorder = RecordedRequests()

    func testManifestOperationDecodesPublishedManifestAndSendsAuthorizedRequest() async throws {
        let client = makeClient(
            statusCode: 200,
            responseBodyJSON: """
            {
              "schema_version": "lps-sheet-manifest/v1",
              "sheet_id": "sheet_1",
              "capture_profile": {"scoring_algorithm_version": "lps-distance-v1"}
            }
            """
        )

        let output = try await client.colorMatchingWeb_TestSheetController_manifest(
            .init(path: .init(sheetId: "sheet_1"))
        )

        guard case .ok(let ok) = output else {
            return XCTFail("Expected a 200 response from the manifest operation, got: \(output)")
        }
        guard case .json(let manifest) = ok.body else {
            return XCTFail("Expected a JSON body from the manifest operation.")
        }
        XCTAssertEqual(manifest.schemaVersion.rawValue, "lps-sheet-manifest/v1")
        XCTAssertEqual(manifest.sheetId, "sheet_1")
        XCTAssertEqual(manifest.captureProfile.scoringAlgorithmVersion.rawValue, "lps-distance-v1")

        let request = try XCTUnwrap(recorder.all.first)
        XCTAssertEqual(request.operationID, "ColorMatchingWeb.TestSheetController.manifest")
        XCTAssertEqual(request.method, "GET")
        XCTAssertEqual(request.path, "/api/v1/test_sheets/sheet_1/manifest")
        XCTAssertEqual(request.authorization, "Bearer test-token")
    }

    func testManifestOperationSurfacesNotFoundResponses() async throws {
        let client = makeClient(
            statusCode: 404,
            responseBodyJSON: #"{"errors": {"detail": "Sheet not found"}}"#
        )

        let output = try await client.colorMatchingWeb_TestSheetController_manifest(
            .init(path: .init(sheetId: "missing"))
        )

        guard case .notFound = output else {
            return XCTFail("Expected a 404 response from the manifest operation, got: \(output)")
        }
    }

    func testRecentSheetsOperationDecodesSheetsIncludingUntitledSheets() async throws {
        let client = makeClient(
            statusCode: 200,
            responseBodyJSON: """
            {
              "sheets": [
                {
                  "sheet_id": "sheet_1",
                  "manifest_url": "https://color-matching.example.test/api/v1/test_sheets/sheet_1/manifest",
                  "title": "July LPS comparison sheet"
                },
                {
                  "sheet_id": "sheet_2",
                  "manifest_url": "https://color-matching.example.test/api/v1/test_sheets/sheet_2/manifest",
                  "title": null
                }
              ]
            }
            """
        )

        let output = try await client.colorMatchingWeb_TestSheetController_recent(.init())

        guard case .ok(let ok) = output else {
            return XCTFail("Expected a 200 response from the recent sheets operation, got: \(output)")
        }
        guard case .json(let payload) = ok.body else {
            return XCTFail("Expected a JSON body from the recent sheets operation.")
        }
        XCTAssertEqual(payload.sheets.count, 2)
        XCTAssertEqual(payload.sheets.first?.sheetId, "sheet_1")
        XCTAssertEqual(
            payload.sheets.first?.manifestUrl,
            "https://color-matching.example.test/api/v1/test_sheets/sheet_1/manifest"
        )
        XCTAssertEqual(payload.sheets.first?.title, "July LPS comparison sheet")
        XCTAssertNil(payload.sheets.last?.title)

        let request = try XCTUnwrap(recorder.all.first)
        XCTAssertEqual(request.operationID, "ColorMatchingWeb.TestSheetController.recent")
        XCTAssertEqual(request.method, "GET")
        XCTAssertEqual(request.path, "/api/v1/test_sheets/recent")
        XCTAssertEqual(request.authorization, "Bearer test-token")
    }

    func testCreateCaptureOperationSendsProseContractBodyAndDecodesCaptureID() async throws {
        let client = makeClient(
            statusCode: 201,
            responseBodyJSON: #"{"capture_id": "42"}"#
        )
        let requestBody = try Self.decodeGeneratedBody(
            Components.Schemas.CaptureRequest.self,
            from: Self.captureRequestBodyJSON
        )

        let output = try await client.colorMatchingWeb_CaptureController_create(
            .init(path: .init(sheetId: "sheet_1"), body: .json(requestBody))
        )

        guard case .created(let created) = output else {
            return XCTFail("Expected a 201 response from the capture creation operation, got: \(output)")
        }
        guard case .json(let payload) = created.body else {
            return XCTFail("Expected a JSON body from the capture creation operation.")
        }
        XCTAssertEqual(payload.captureId, "42")

        let request = try XCTUnwrap(recorder.all.first)
        XCTAssertEqual(request.method, "POST")
        XCTAssertEqual(request.path, "/api/v1/test_sheets/sheet_1/captures")
        XCTAssertEqual(request.authorization, "Bearer test-token")
        let json = try Self.jsonObject(from: request.bodyData)
        let metadata = try XCTUnwrap(json["metadata"] as? [String: Any])
        XCTAssertEqual(metadata["device_model"] as? String, "iPhone 16")
        XCTAssertEqual(metadata["lens"] as? String, "built_in_wide_angle")
        XCTAssertEqual(metadata["exposure_duration_seconds"] as? Double, 0.016)
        XCTAssertEqual(metadata["iso"] as? Int, 100)
        XCTAssertEqual(metadata["image_width"] as? Int, 4032)
        XCTAssertEqual(metadata["app_version"] as? String, "0.1.0")
        XCTAssertNotNil(metadata["timestamp"] as? String)
        let quality = try XCTUnwrap(json["quality"] as? [String: Any])
        XCTAssertEqual(quality["detected_marker_count"] as? Int, 4)
        XCTAssertEqual(quality["blur_score"] as? Double, 0.82)
        XCTAssertEqual(quality["rejections"] as? [String], [])
    }

    func testCreateCaptureOperationSurfacesUnauthorizedResponses() async throws {
        let client = makeClient(
            statusCode: 401,
            responseBodyJSON: #"{"errors": {"detail": "Unauthorized"}}"#
        )
        let requestBody = try Self.decodeGeneratedBody(
            Components.Schemas.CaptureRequest.self,
            from: Self.captureRequestBodyJSON
        )

        let output = try await client.colorMatchingWeb_CaptureController_create(
            .init(path: .init(sheetId: "sheet_1"), body: .json(requestBody))
        )

        guard case .unauthorized = output else {
            return XCTFail("Expected a 401 response from the capture creation operation, got: \(output)")
        }
    }

    func testUploadMeasurementsOperationSendsMeasurementsAndPairScores() async throws {
        let client = makeClient(
            statusCode: 200,
            responseBodyJSON: #"{"capture_id": "42", "measurement_count": 1, "pair_score_count": 1}"#
        )
        let requestBody = try Self.decodeGeneratedBody(
            Components.Schemas.MeasurementUploadRequest.self,
            from: Self.measurementUploadBodyJSON
        )

        let output = try await client.colorMatchingWeb_CaptureController_uploadMeasurements(
            .init(path: .init(captureId: "42"), body: .json(requestBody))
        )

        guard case .ok(let ok) = output else {
            return XCTFail("Expected a 200 response from the measurement upload operation, got: \(output)")
        }
        guard case .json(let payload) = ok.body else {
            return XCTFail("Expected a JSON body from the measurement upload operation.")
        }
        XCTAssertEqual(payload.captureId, "42")
        XCTAssertEqual(payload.measurementCount, 1)
        XCTAssertEqual(payload.pairScoreCount, 1)

        let request = try XCTUnwrap(recorder.all.first)
        XCTAssertEqual(request.method, "POST")
        XCTAssertEqual(request.path, "/api/v1/captures/42/measurements")
        XCTAssertEqual(request.authorization, "Bearer test-token")
        let json = try Self.jsonObject(from: request.bodyData)
        let measurements = try XCTUnwrap(json["measurements"] as? [[String: Any]])
        XCTAssertEqual(measurements.count, 1)
        XCTAssertEqual(measurements.first?["patch_id"] as? String, "patch_1")
        let median = try XCTUnwrap(measurements.first?["linear_rgb_median"] as? [String: Any])
        XCTAssertEqual(median["r"] as? Double, 0.12)
        XCTAssertEqual(median["g"] as? Double, 0.1)
        XCTAssertEqual(median["b"] as? Double, 0.02)
        let normalized = try XCTUnwrap(measurements.first?["normalized_linear_rgb_median"] as? [String: Any])
        XCTAssertEqual(normalized["r"] as? Double, 0.15)
        let pairScores = try XCTUnwrap(json["pair_scores"] as? [[String: Any]])
        XCTAssertEqual(pairScores.first?["pair_id"] as? String, "pair_1")
        XCTAssertEqual(pairScores.first?["algorithm_version"] as? String, "lps-distance-v1")
        XCTAssertEqual(pairScores.first?["distance"] as? Double, 0.035)
    }

    func testUploadJudgmentsOperationSendsPairJudgments() async throws {
        let client = makeClient(
            statusCode: 200,
            responseBodyJSON: #"{"capture_id": "42", "judgment_count": 1}"#
        )
        let requestBody = try Self.decodeGeneratedBody(
            Components.Schemas.JudgmentUploadRequest.self,
            from: Self.judgmentUploadBodyJSON
        )

        let output = try await client.colorMatchingWeb_CaptureController_uploadJudgments(
            .init(path: .init(captureId: "42"), body: .json(requestBody))
        )

        guard case .ok(let ok) = output else {
            return XCTFail("Expected a 200 response from the judgment upload operation, got: \(output)")
        }
        guard case .json(let payload) = ok.body else {
            return XCTFail("Expected a JSON body from the judgment upload operation.")
        }
        XCTAssertEqual(payload.captureId, "42")
        XCTAssertEqual(payload.judgmentCount, 1)

        let request = try XCTUnwrap(recorder.all.first)
        XCTAssertEqual(request.method, "POST")
        XCTAssertEqual(request.path, "/api/v1/captures/42/judgments")
        XCTAssertEqual(request.authorization, "Bearer test-token")
        let json = try Self.jsonObject(from: request.bodyData)
        let judgments = try XCTUnwrap(json["judgments"] as? [[String: Any]])
        XCTAssertEqual(judgments.count, 1)
        XCTAssertEqual(judgments.first?["pair_id"] as? String, "pair_1")
        XCTAssertEqual(judgments.first?["judgment"] as? String, "near_match")
    }

    func testRankedResultsOperationDecodesPublishedRankedResults() async throws {
        let client = makeClient(
            statusCode: 200,
            responseBodyJSON: #"{"schema_version": "lps-ranked-results/v1", "sheet_id": "sheet_1"}"#
        )

        let output = try await client.colorMatchingWeb_TestSheetController_rankedResults(
            .init(path: .init(sheetId: "sheet_1"))
        )

        guard case .ok(let ok) = output else {
            return XCTFail("Expected a 200 response from the ranked results operation, got: \(output)")
        }
        guard case .json(let payload) = ok.body else {
            return XCTFail("Expected a JSON body from the ranked results operation.")
        }
        XCTAssertEqual(payload.schemaVersion.rawValue, "lps-ranked-results/v1")
        XCTAssertEqual(payload.sheetId, "sheet_1")

        let request = try XCTUnwrap(recorder.all.first)
        XCTAssertEqual(request.method, "GET")
        XCTAssertEqual(request.path, "/api/v1/test_sheets/sheet_1/ranked_results")
        XCTAssertEqual(request.authorization, "Bearer test-token")
    }

    private func makeClient(statusCode: Int, responseBodyJSON: String?) -> ColorMatchingOpenAPI.Client {
        ColorMatchingOpenAPI.Client(
            serverURL: Self.serverURL,
            transport: StubTransport(
                recorder: recorder,
                statusCode: statusCode,
                responseBodyJSON: responseBodyJSON
            ),
            middlewares: [BearerTokenMiddleware(token: Self.token)]
        )
    }

    private static func decodeGeneratedBody<Payload: Decodable>(
        _ type: Payload.Type,
        from json: String
    ) throws -> Payload {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Payload.self, from: Data(json.utf8))
    }

    private static func jsonObject(from data: Data?) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(data)) as? [String: Any])
    }

    private static let serverURL = URL(string: "https://color-matching.example.test")!
    private static let token = "test-token"

    private static let captureRequestBodyJSON = """
    {
      "metadata": {
        "device_model": "iPhone 16",
        "lens": "built_in_wide_angle",
        "exposure_duration_seconds": 0.016,
        "iso": 100,
        "focus_lens_position": 0.42,
        "white_balance_gains": {"red": 1.2, "green": 1.0, "blue": 1.4},
        "image_width": 4032,
        "image_height": 3024,
        "app_version": "0.1.0",
        "timestamp": "2026-07-25T12:00:00Z"
      },
      "quality": {
        "detected_marker_count": 4,
        "blur_score": 0.82,
        "rejections": []
      }
    }
    """

    private static let measurementUploadBodyJSON = """
    {
      "measurements": [
        {
          "patch_id": "patch_1",
          "linear_rgb_median": {"r": 0.12, "g": 0.1, "b": 0.02},
          "normalized_linear_rgb_median": {"r": 0.15, "g": 0.12, "b": 0.02}
        }
      ],
      "pair_scores": [
        {
          "pair_id": "pair_1",
          "algorithm_version": "lps-distance-v1",
          "distance": 0.035,
          "similarity": 0.965
        }
      ]
    }
    """

    private static let judgmentUploadBodyJSON = """
    {
      "judgments": [
        {"pair_id": "pair_1", "judgment": "near_match"}
      ]
    }
    """
}

private struct RecordedRequest: Sendable {
    let operationID: String
    let method: String
    let path: String
    let authorization: String?
    let bodyData: Data?
}

private final class RecordedRequests: @unchecked Sendable {
    private let lock = NSLock()
    private var requests: [RecordedRequest] = []

    func append(_ request: RecordedRequest) {
        lock.lock()
        defer { lock.unlock() }
        requests.append(request)
    }

    var all: [RecordedRequest] {
        lock.lock()
        defer { lock.unlock() }
        return requests
    }
}

private struct StubTransport: ClientTransport {
    private static let maximumBodyBytes = 16 * 1024 * 1024

    let recorder: RecordedRequests
    let statusCode: Int
    let responseBodyJSON: String?

    func send(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String
    ) async throws -> (HTTPResponse, HTTPBody?) {
        let bodyData: Data?
        if let body {
            bodyData = try await Data(collecting: body, upTo: Self.maximumBodyBytes)
        } else {
            bodyData = nil
        }
        recorder.append(
            RecordedRequest(
                operationID: operationID,
                method: request.method.rawValue,
                path: request.path,
                authorization: request.headerFields[.authorization],
                bodyData: bodyData
            )
        )
        let response = HTTPResponse(status: .init(code: statusCode))
        guard let bodyData else {
            return (response, nil)
        }
        var jsonResponse = response
        jsonResponse.headerFields[HTTPField.Name("content-type")!] = "application/json"
        return (jsonResponse, HTTPBody(bodyData))
    }
}

private struct BearerTokenMiddleware: ClientMiddleware {
    let token: String

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
#else
final class GeneratedOpenAPIClientTests: XCTestCase {
    func testGeneratedOpenAPIClientModuleIsWiredIntoPackage() throws {
        XCTFail(
            "The generated OpenAPI client module \"ColorMatchingOpenAPI\" is not wired into the package, "
                + "so the stubbed-response client tests are compiled out. Add swift-openapi-generator and "
                + "swift-openapi-runtime (plus swift-openapi-urlsession-runtime for the app), vendor the "
                + "spec published at GET /api/v1/openapi.json as Sources/ColorMatchingOpenAPI/openapi.json, "
                + "and generate types + client with public access and the idiomatic naming strategy. "
                + "See docs/openapi-generated-client.md."
        )
    }
}
#endif
