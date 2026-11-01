import Foundation
import OpenAPIRuntime
import GeneratedAPIClient
import XCTest

/// Stubbed-response tests for the generated OpenAPI client target
/// (`GeneratedAPIClient`, generated from iOS/OpenAPI/color-matching-openapi.json).
///
/// These tests compile and run once iOS/Package.swift declares the
/// `GeneratedClientTests` test target depending on `GeneratedAPIClient`
/// (asserted by OpenAPIPackageWiringTests). No live server is required: every
/// response is stubbed at the ClientTransport level.
///
/// Generated method names follow swift-openapi-generator's idiomatic mangling
/// of the published operationIds (for example
/// "ColorMatchingWeb.TestSheetController.manifest" becomes
/// colorMatchingWebTestSheetControllerManifest). If regeneration produces a
/// different spelling, rename the call sites here — the wire-level assertions
/// (paths, payloads, decoded response fields) are the contract and must not
/// change.
final class GeneratedClientStubbedResponseTests: XCTestCase {
    func testFetchRecentSheetsDecodesStubbedResponse() async throws {
        let client = makeClient { request, _ in
            XCTAssertEqual(request.method, .get)
            XCTAssertEqual(request.path, "/api/v1/test_sheets/recent")
            return Self.jsonResponse(.ok, Self.recentSheetsJSON)
        }

        let output = try await client.colorMatchingWebTestSheetControllerRecent()

        guard case .ok(let response) = output, case .json(let body) = response.body else {
            return XCTFail("Expected .ok with a JSON body for GET /api/v1/test_sheets/recent.")
        }
        XCTAssertEqual(body.sheets.count, 2)
        XCTAssertEqual(body.sheets.first?.sheetId, "sheet_1")
        XCTAssertEqual(
            body.sheets.first?.manifestUrl,
            "https://example.test/api/v1/test_sheets/sheet_1/manifest"
        )
        XCTAssertEqual(body.sheets.first?.title, "July LPS comparison sheet")
        XCTAssertEqual(body.sheets.last?.title, nil, "A sheet without a display name decodes with a nil title.")
    }

    func testFetchManifestDecodesCompatibilityVersions() async throws {
        let client = makeClient { request, _ in
            XCTAssertEqual(request.method, .get)
            XCTAssertEqual(request.path, "/api/v1/test_sheets/sheet_1/manifest")
            return Self.jsonResponse(.ok, Self.manifestJSON)
        }

        let output = try await client.colorMatchingWebTestSheetControllerManifest(
            .init(path: .init(sheetId: "sheet_1"))
        )

        guard case .ok(let response) = output, case .json(let body) = response.body else {
            return XCTFail("Expected .ok with a JSON body for GET /test_sheets/{sheet_id}/manifest.")
        }
        XCTAssertEqual(body.sheetId, "sheet_1")
        XCTAssertEqual(body.schemaVersion.rawValue, "lps-sheet-manifest/v1")
        XCTAssertEqual(body.captureProfile.scoringAlgorithmVersion.rawValue, "lps-distance-v1")
    }

    func testCreateCaptureSendsMetadataAndQualityAndDecodesCaptureID() async throws {
        var capturedMethod: HTTPRequest.Method?
        var capturedPath: String?
        var capturedBody: Data?
        let client = makeClient { request, body in
            capturedMethod = request.method
            capturedPath = request.path
            if let body {
                capturedBody = try await Data(collecting: body, upTo: 1_048_576)
            }
            return Self.jsonResponse(.created, #"{"capture_id":"cap_1"}"#)
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
        let output = try await client.colorMatchingWebCaptureControllerCreate(
            .init(
                path: .init(sheetId: "sheet_1"),
                body: .json(
                    .init(
                        metadata: metadata,
                        quality: .init(detectedMarkerCount: 4, blurScore: 0.82, rejections: nil)
                    )
                )
            )
        )

        XCTAssertEqual(capturedMethod, .post)
        XCTAssertEqual(capturedPath, "/api/v1/test_sheets/sheet_1/captures")
        let json = try Self.jsonObject(from: capturedBody)
        let metadataPayload = try XCTUnwrap(json["metadata"] as? [String: Any])
        XCTAssertEqual(metadataPayload["device_model"] as? String, "iPhone")
        XCTAssertEqual(metadataPayload["app_version"] as? String, "0.1.0")
        let qualityPayload = try XCTUnwrap(json["quality"] as? [String: Any])
        XCTAssertEqual(qualityPayload["detected_marker_count"] as? Int, 4)
        XCTAssertEqual(qualityPayload["blur_score"] as? Double, 0.82, accuracy: 0.0001)

        guard case .created(let response) = output, case .json(let body) = response.body else {
            return XCTFail("Expected .created with a JSON body for POST /test_sheets/{sheet_id}/captures.")
        }
        XCTAssertEqual(body.captureId, "cap_1")
    }

    func testUploadMeasurementsSendsPayloadAndDecodesAcceptedCounts() async throws {
        var capturedMethod: HTTPRequest.Method?
        var capturedPath: String?
        var capturedBody: Data?
        let client = makeClient { request, body in
            capturedMethod = request.method
            capturedPath = request.path
            if let body {
                capturedBody = try await Data(collecting: body, upTo: 1_048_576)
            }
            return Self.jsonResponse(
                .ok,
                #"{"capture_id":"cap_1","measurement_count":1,"pair_score_count":1}"#
            )
        }

        let rgbMedian = Components.Schemas.RgbPayload.case2(.init(r: 0.12, g: 0.10, b: 0.02))
        let output = try await client.colorMatchingWebCaptureControllerUploadMeasurements(
            .init(
                path: .init(captureId: "cap_1"),
                body: .json(
                    .init(
                        measurements: [
                            .init(
                                patchId: "patch_1",
                                linearRgbMedian: rgbMedian,
                                normalizedLinearRgbMedian: rgbMedian
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
                )
            )
        )

        XCTAssertEqual(capturedMethod, .post)
        XCTAssertEqual(capturedPath, "/api/v1/captures/cap_1/measurements")
        let json = try Self.jsonObject(from: capturedBody)
        let measurement = try XCTUnwrap((json["measurements"] as? [[String: Any]])?.first)
        XCTAssertEqual(measurement["patch_id"] as? String, "patch_1")
        XCTAssertEqual(measurement["linear_rgb_median"] as? [String: Double], ["r": 0.12, "g": 0.10, "b": 0.02])
        let pairScore = try XCTUnwrap((json["pair_scores"] as? [[String: Any]])?.first)
        XCTAssertEqual(pairScore["pair_id"] as? String, "pair_1")
        XCTAssertEqual(pairScore["algorithm_version"] as? String, "lps-distance-v1")
        XCTAssertEqual(pairScore["distance"] as? Double, 0.035, accuracy: 0.000001)

        guard case .ok(let response) = output, case .json(let body) = response.body else {
            return XCTFail("Expected .ok with a JSON body for POST /captures/{capture_id}/measurements.")
        }
        XCTAssertEqual(body.captureId, "cap_1")
        XCTAssertEqual(body.measurementCount, 1)
        XCTAssertEqual(body.pairScoreCount, 1)
    }

    func testUploadJudgmentsSendsPayloadAndDecodesAcceptedCount() async throws {
        var capturedMethod: HTTPRequest.Method?
        var capturedPath: String?
        var capturedBody: Data?
        let client = makeClient { request, body in
            capturedMethod = request.method
            capturedPath = request.path
            if let body {
                capturedBody = try await Data(collecting: body, upTo: 1_048_576)
            }
            return Self.jsonResponse(.ok, #"{"capture_id":"cap_1","judgment_count":1}"#)
        }

        let output = try await client.colorMatchingWebCaptureControllerUploadJudgments(
            .init(
                path: .init(captureId: "cap_1"),
                body: .json(.init(judgments: [.init(pairId: "pair_1", judgment: "near_match")]))
            )
        )

        XCTAssertEqual(capturedMethod, .post)
        XCTAssertEqual(capturedPath, "/api/v1/captures/cap_1/judgments")
        let json = try Self.jsonObject(from: capturedBody)
        let judgment = try XCTUnwrap((json["judgments"] as? [[String: Any]])?.first)
        XCTAssertEqual(judgment["pair_id"] as? String, "pair_1")
        XCTAssertEqual(judgment["judgment"] as? String, "near_match")

        guard case .ok(let response) = output, case .json(let body) = response.body else {
            return XCTFail("Expected .ok with a JSON body for POST /captures/{capture_id}/judgments.")
        }
        XCTAssertEqual(body.captureId, "cap_1")
        XCTAssertEqual(body.judgmentCount, 1)
    }

    func testFetchRankedResultsDecodesCompatibilityVersion() async throws {
        let client = makeClient { request, _ in
            XCTAssertEqual(request.method, .get)
            XCTAssertEqual(request.path, "/api/v1/test_sheets/sheet_1/ranked_results")
            return Self.jsonResponse(
                .ok,
                #"{"schema_version":"lps-ranked-results/v1","sheet_id":"sheet_1"}"#
            )
        }

        let output = try await client.colorMatchingWebTestSheetControllerRankedResults(
            .init(path: .init(sheetId: "sheet_1"))
        )

        guard case .ok(let response) = output, case .json(let body) = response.body else {
            return XCTFail("Expected .ok with a JSON body for GET /test_sheets/{sheet_id}/ranked_results.")
        }
        XCTAssertEqual(body.sheetId, "sheet_1")
        XCTAssertEqual(body.schemaVersion.rawValue, "lps-ranked-results/v1")
    }

    func testManifestNotFoundSurfacesAsDocumentedNotFoundCase() async throws {
        let client = makeClient { _, _ in
            Self.jsonResponse(.notFound, #"{"errors":{"detail":"Sheet not found"}}"#)
        }

        let output = try await client.colorMatchingWebTestSheetControllerManifest(
            .init(path: .init(sheetId: "missing_sheet"))
        )

        guard case .notFound = output else {
            return XCTFail("Expected the documented .notFound output for a 404 manifest response.")
        }
    }

    private func makeClient(
        respond: @escaping (HTTPRequest, HTTPBody?) async throws -> (HTTPResponse, HTTPBody?)
    ) -> GeneratedAPIClient.Client {
        GeneratedAPIClient.Client(
            serverURL: URL(string: "https://example.test")!,
            transport: StubTransport(respond: respond)
        )
    }

    private static func jsonResponse(_ status: HTTPResponse.Status, _ json: String) -> (HTTPResponse, HTTPBody?) {
        (HTTPResponse(status: status, headerFields: [.contentType: "application/json"]), HTTPBody(json))
    }

    private static func jsonObject(from data: Data?) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(data)) as? [String: Any])
    }

    private static let recentSheetsJSON = #"""
    {
      "sheets": [
        {
          "sheet_id": "sheet_1",
          "manifest_url": "https://example.test/api/v1/test_sheets/sheet_1/manifest",
          "title": "July LPS comparison sheet"
        },
        {
          "sheet_id": "sheet_2",
          "manifest_url": "https://example.test/api/v1/test_sheets/sheet_2/manifest",
          "title": null
        }
      ]
    }
    """#

    private static let manifestJSON = #"""
    {
      "schema_version": "lps-sheet-manifest/v1",
      "sheet_id": "sheet_1",
      "capture_profile": {
        "scoring_algorithm_version": "lps-distance-v1"
      }
    }
    """#
}

private struct StubTransport: ClientTransport {
    let respond: (HTTPRequest, HTTPBody?) async throws -> (HTTPResponse, HTTPBody?)

    func send(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String
    ) async throws -> (HTTPResponse, HTTPBody?) {
        try await respond(request, body)
    }
}
