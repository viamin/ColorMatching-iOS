import Foundation
import HTTPTypes
import OpenAPIRuntime
import XCTest

import ColorMatchingAPI

/// Exercises the generated OpenAPI client (`swift-openapi-generator` +
/// `swift-openapi-runtime`) against locally stubbed HTTP responses.
///
/// No live server is involved: `StubTransport` returns canned JSON payloads
/// and records the outgoing request for wire-format assertions.
///
/// These tests compile only once the `ColorMatchingAPI` target exists —
/// see docs/openapi-generated-client.md for the exact vendored-spec and
/// naming contract they assume:
///
/// - Vendored document: `iOS/ColorMatchingAPI/openapi.json`.
/// - Clean operation IDs: `getTestSheetManifest`, `listRecentSheets`,
///   `getRankedResults`, `createCapture`, `uploadMeasurements`,
///   `uploadJudgments`.
/// - Default (defensive) generator naming: Swift members keep their
///   documented JSON names (`sheet_id`, `capture_id`, ...).
/// - swift-openapi-runtime >= 1.5.0 (transport signature with a separate
///   `body` parameter; HTTP types from swift-http-types).
final class GeneratedClientTests: XCTestCase {
    private var transport: StubTransport!

    override func setUp() {
        super.setUp()
        transport = StubTransport()
    }

    override func tearDown() {
        transport = nil
        super.tearDown()
    }

    func testGetTestSheetManifestDecodesGeneratedManifest() async throws {
        transport.stub = { _ in
            Self.jsonResponse(
                200,
                #"{"schema_version":"lps-sheet-manifest/v1","sheet_id":"sheet_123","capture_profile":{"scoring_algorithm_version":"lps-distance-v1"}}"#
            )
        }

        let output = try await makeClient().getTestSheetManifest(.init(path: .init(sheet_id: "sheet_123")))

        XCTAssertEqual(transport.recordedOperationID, "getTestSheetManifest")
        XCTAssertEqual(transport.recordedRequest?.method, .get)
        XCTAssertEqual(transport.recordedRequest?.path, "/api/v1/test_sheets/sheet_123/manifest")
        guard case let .ok(ok) = output else { return XCTFail("expected ok, got \(output)") }
        guard case let .json(manifest) = ok.body else { return XCTFail("expected a JSON body") }
        XCTAssertEqual(manifest.schema_version.rawValue, "lps-sheet-manifest/v1")
        XCTAssertEqual(manifest.sheet_id, "sheet_123")
        XCTAssertEqual(manifest.capture_profile.scoring_algorithm_version.rawValue, "lps-distance-v1")
    }

    func testListRecentSheetsDecodesNullableTitle() async throws {
        transport.stub = { _ in
            Self.jsonResponse(
                200,
                #"{"sheets":[{"sheet_id":"sheet_123","manifest_url":"https://example.test/api/v1/test_sheets/sheet_123/manifest","title":"July LPS comparison sheet"},{"sheet_id":"sheet_456","manifest_url":"https://example.test/api/v1/test_sheets/sheet_456/manifest","title":null}]}"#
            )
        }

        let output = try await makeClient().listRecentSheets(.init())

        XCTAssertEqual(transport.recordedRequest?.path, "/api/v1/test_sheets/recent")
        guard case let .ok(ok) = output else { return XCTFail("expected ok, got \(output)") }
        guard case let .json(body) = ok.body else { return XCTFail("expected a JSON body") }
        XCTAssertEqual(body.sheets.map(\.sheet_id), ["sheet_123", "sheet_456"])
        XCTAssertEqual(body.sheets.first?.title, "July LPS comparison sheet")
        XCTAssertNil(body.sheets.last?.title, "the published spec marks title as required-but-nullable")
    }

    func testCreateCaptureSendsNestedMetadataAndQuality() async throws {
        transport.stub = { _ in
            Self.jsonResponse(201, #"{"capture_id":"capture_123"}"#)
        }

        let metadata = Components.Schemas.CaptureMetadata(
            device_model: "iPhone 15 Pro",
            lens: "built_in_wide_angle",
            image_width: 4032,
            image_height: 3024,
            app_version: "0.1.0",
            timestamp: Date(timeIntervalSince1970: 1_782_000_000)
        )
        let input = Operations.createCapture.Input(
            path: .init(sheet_id: "sheet_123"),
            body: .json(
                Components.Schemas.CaptureRequest(
                    metadata: metadata,
                    quality: .init(detected_marker_count: 4, blur_score: 0.82, rejections: [])
                )
            )
        )

        let output = try await makeClient().createCapture(input)

        XCTAssertEqual(transport.recordedRequest?.method, .post)
        XCTAssertEqual(transport.recordedRequest?.path, "/api/v1/test_sheets/sheet_123/captures")
        let json = try XCTUnwrap(transport.recordedJSONObject)
        let metadataJSON = try XCTUnwrap(json["metadata"] as? [String: Any])
        XCTAssertEqual(metadataJSON["device_model"] as? String, "iPhone 15 Pro")
        XCTAssertEqual(metadataJSON["app_version"] as? String, "0.1.0")
        let qualityJSON = try XCTUnwrap(json["quality"] as? [String: Any])
        XCTAssertEqual(qualityJSON["detected_marker_count"] as? Int, 4)
        XCTAssertEqual(qualityJSON["rejections"] as? [String], [])

        guard case let .created(created) = output else { return XCTFail("expected created, got \(output)") }
        guard case let .json(capture) = created.body else { return XCTFail("expected a JSON body") }
        XCTAssertEqual(capture.capture_id, "capture_123")
    }

    func testUploadMeasurementsSendsRgbObjectsAndPairScores() async throws {
        transport.stub = { _ in
            Self.jsonResponse(
                200,
                #"{"capture_id":"capture_123","measurement_count":1,"pair_score_count":1}"#
            )
        }

        let input = Operations.uploadMeasurements.Input(
            path: .init(capture_id: "capture_123"),
            body: .json(
                Components.Schemas.MeasurementUploadRequest(
                    measurements: [
                        .init(
                            patch_id: "patch_1",
                            linear_rgb_median: .case2(.init(r: 0.12, g: 0.10, b: 0.02)),
                            normalized_linear_rgb_median: .case2(.init(r: 0.15, g: 0.12, b: 0.02))
                        ),
                    ],
                    pair_scores: [
                        Components.Schemas.PairScoreRequest(
                            pair_id: "pair_1",
                            algorithm_version: "lps-distance-v1",
                            similarity: 0.965
                        ),
                    ]
                )
            )
        )

        let output = try await makeClient().uploadMeasurements(input)

        XCTAssertEqual(transport.recordedRequest?.method, .post)
        XCTAssertEqual(transport.recordedRequest?.path, "/api/v1/captures/capture_123/measurements")
        let json = try XCTUnwrap(transport.recordedJSONObject)
        let measurement = try XCTUnwrap((json["measurements"] as? [[String: Any]])?.first)
        XCTAssertEqual(measurement["patch_id"] as? String, "patch_1")
        let linearMedian = try XCTUnwrap(measurement["linear_rgb_median"] as? [String: Double])
        XCTAssertEqual(linearMedian["r"] ?? 0, 0.12, accuracy: 0.0001)
        XCTAssertEqual(linearMedian["g"] ?? 0, 0.10, accuracy: 0.0001)
        XCTAssertEqual(linearMedian["b"] ?? 0, 0.02, accuracy: 0.0001)
        let pairScore = try XCTUnwrap((json["pair_scores"] as? [[String: Any]])?.first)
        XCTAssertEqual(pairScore["pair_id"] as? String, "pair_1")
        XCTAssertEqual(pairScore["algorithm_version"] as? String, "lps-distance-v1")
        XCTAssertEqual(pairScore["similarity"] as? Double ?? 0, 0.965, accuracy: 0.0001)
        XCTAssertNil(
            json["scoring_algorithm_version"],
            "the published spec moved the scoring version into each pair score"
        )

        guard case let .ok(ok) = output else { return XCTFail("expected ok, got \(output)") }
        guard case let .json(counts) = ok.body else { return XCTFail("expected a JSON body") }
        XCTAssertEqual(counts.capture_id, "capture_123")
        XCTAssertEqual(counts.measurement_count, 1)
        XCTAssertEqual(counts.pair_score_count, 1)
    }

    func testUploadJudgmentsSendsPairJudgments() async throws {
        transport.stub = { _ in
            Self.jsonResponse(200, #"{"capture_id":"capture_123","judgment_count":1}"#)
        }

        let input = Operations.uploadJudgments.Input(
            path: .init(capture_id: "capture_123"),
            body: .json(
                Components.Schemas.JudgmentUploadRequest(
                    judgments: [.init(pair_id: "pair_1", judgment: "near_match")]
                )
            )
        )

        let output = try await makeClient().uploadJudgments(input)

        XCTAssertEqual(transport.recordedRequest?.method, .post)
        XCTAssertEqual(transport.recordedRequest?.path, "/api/v1/captures/capture_123/judgments")
        let json = try XCTUnwrap(transport.recordedJSONObject)
        XCTAssertEqual((json["judgments"] as? [[String: Any]])?.first?["judgment"] as? String, "near_match")

        guard case let .ok(ok) = output else { return XCTFail("expected ok, got \(output)") }
        guard case let .json(counts) = ok.body else { return XCTFail("expected a JSON body") }
        XCTAssertEqual(counts.capture_id, "capture_123")
        XCTAssertEqual(counts.judgment_count, 1)
    }

    func testGetRankedResultsDecodesVersionedSchema() async throws {
        transport.stub = { _ in
            Self.jsonResponse(200, #"{"schema_version":"lps-ranked-results/v1","sheet_id":"sheet_123"}"#)
        }

        let output = try await makeClient().getRankedResults(.init(path: .init(sheet_id: "sheet_123")))

        XCTAssertEqual(transport.recordedOperationID, "getRankedResults")
        XCTAssertEqual(transport.recordedRequest?.method, .get)
        XCTAssertEqual(transport.recordedRequest?.path, "/api/v1/test_sheets/sheet_123/ranked_results")
        guard case let .ok(ok) = output else { return XCTFail("expected ok, got \(output)") }
        guard case let .json(results) = ok.body else { return XCTFail("expected a JSON body") }
        XCTAssertEqual(results.schema_version.rawValue, "lps-ranked-results/v1")
        XCTAssertEqual(results.sheet_id, "sheet_123")
    }

    func testManifestNotFoundSurfacesTypedNotFoundOutput() async throws {
        transport.stub = { _ in
            Self.jsonResponse(404, #"{"errors":{"detail":"Sheet not found"}}"#)
        }

        let output = try await makeClient().getTestSheetManifest(.init(path: .init(sheet_id: "missing")))

        guard case .notFound = output else { return XCTFail("expected a typed notFound output, got \(output)") }
    }

    func testBearerMiddlewareAppliesAuthorizationHeader() async throws {
        transport.stub = { _ in
            Self.jsonResponse(200, #"{"sheets":[]}"#)
        }

        _ = try await makeClient(token: "token-123").listRecentSheets(.init())

        XCTAssertEqual(
            transport.recordedRequest?.headerFields[.authorization],
            "Bearer token-123",
            "bearer-token middleware must authorize generated-client requests"
        )
    }
}

private extension GeneratedClientTests {
    func makeClient(token: String? = nil) -> ColorMatchingAPI.Client {
        var middlewares: [any ClientMiddleware] = []
        if let token { middlewares.append(BearerTokenMiddleware(token: token)) }
        return ColorMatchingAPI.Client(
            serverURL: URL(string: "https://example.test")!,
            transport: transport,
            middlewares: middlewares
        )
    }

    static func jsonResponse(_ statusCode: Int, _ payload: String) -> (HTTPResponse, HTTPBody) {
        var fields = HTTPFields()
        fields[.contentType] = "application/json"
        return (HTTPResponse(status: .init(code: statusCode), headerFields: fields), HTTPBody(payload))
    }
}

private enum StubError: Error {
    case noStubConfigured
}

/// A `ClientTransport` that records the outgoing request and returns a
/// canned response; no network access happens in tests.
private final class StubTransport: ClientTransport, @unchecked Sendable {
    var stub: ((HTTPRequest) throws -> (HTTPResponse, HTTPBody))?

    private(set) var recordedRequest: HTTPRequest?
    private(set) var recordedBody: Data?
    private(set) var recordedBaseURL: URL?
    private(set) var recordedOperationID: String?

    var recordedJSONObject: Any? {
        guard let recordedBody else { return nil }
        return try? JSONSerialization.jsonObject(with: recordedBody)
    }

    func send(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String
    ) async throws -> (HTTPResponse, HTTPBody?) {
        recordedRequest = request
        recordedBaseURL = baseURL
        recordedOperationID = operationID
        if let body {
            recordedBody = try await Data(collecting: body, upTo: 1 << 20)
        }
        guard let stub else { throw StubError.noStubConfigured }
        return try stub(request)
    }
}

/// Adds the bearer token required by the `bearerAuth` security scheme.
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
