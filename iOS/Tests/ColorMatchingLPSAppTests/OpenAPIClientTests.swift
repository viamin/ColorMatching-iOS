#if canImport(ColorMatchingOpenAPI)
import Foundation
import OpenAPIRuntime
import ColorMatchingOpenAPI
import XCTest

final class OpenAPIClientTests: XCTestCase {
    private let serverURL = URL(string: "https://example.test")!

    func testGetManifestDecodesSheetManifest() async throws {
        let (client, transport) = makeClient(stub: { _ in Self.jsonResponse(.ok, Self.manifestJSON) })

        let response = try await client.getTestSheetManifest(.init(path: .init(sheetId: "sheet_1")))

        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.operationID, "getTestSheetManifest")
        XCTAssertEqual(request.method, "GET")
        XCTAssertEqual(request.path, "/api/v1/test_sheets/sheet_1/manifest")
        guard case .ok(let success) = response else {
            XCTFail("Expected 200 manifest response, got: \(response)")
            return
        }
        guard case .json(let manifest) = success.body else {
            XCTFail("Expected JSON manifest body.")
            return
        }
        XCTAssertEqual(manifest.schemaVersion, "lps-sheet-manifest/v1")
        XCTAssertEqual(manifest.sheetVersion, "lps-letter-grid-v1")
        XCTAssertEqual(manifest.sheetId, "sheet_1")
        XCTAssertEqual(manifest.page.units, "mm")
        XCTAssertEqual(manifest.page.width, 215.9, accuracy: 0.001)
        XCTAssertEqual(manifest.registrationMarkers.count, 1)
        XCTAssertEqual(manifest.registrationMarkers.first?.role, "top_left")
        XCTAssertEqual(manifest.patches.first?.id, "patch_1")
        XCTAssertEqual(manifest.patches.first?.role, "pair_color")
        XCTAssertEqual(manifest.patches.first?.pairId, "pair_1")
        XCTAssertEqual(manifest.patches.first?.pairSide, "first")
        XCTAssertEqual(manifest.patches.first?.sourceColor, "#FF0000")
        XCTAssertEqual(manifest.patches.first?.safeInsetMm ?? 0, 1.5, accuracy: 0.001)
        XCTAssertEqual(manifest.pairs.first?.id, "pair_1")
        XCTAssertEqual(manifest.pairs.first?.firstPatchId, "patch_1")
        XCTAssertEqual(manifest.pairs.first?.secondPatchId, "patch_2")
        XCTAssertEqual(manifest.pairs.first?.sourceColors, ["#FF0000", "#00FF00"])
    }

    func testGetRecentSheetsDecodesOptionalTitles() async throws {
        let payload = """
        {
          "sheets": [
            {"sheet_id": "sheet_1", "manifest_url": "https://example.test/api/v1/test_sheets/sheet_1/manifest", "title": null},
            {"sheet_id": "sheet_2", "manifest_url": "https://example.test/api/v1/test_sheets/sheet_2/manifest", "title": "July LPS comparison sheet"}
          ]
        }
        """
        let (client, transport) = makeClient(stub: { _ in Self.jsonResponse(.ok, payload) })

        let response = try await client.getRecentTestSheets()

        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.operationID, "getRecentTestSheets")
        XCTAssertEqual(request.method, "GET")
        XCTAssertEqual(request.path, "/api/v1/test_sheets/recent")
        guard case .ok(let success) = response else {
            XCTFail("Expected 200 recent sheets response, got: \(response)")
            return
        }
        guard case .json(let body) = success.body else {
            XCTFail("Expected JSON recent sheets body.")
            return
        }
        XCTAssertEqual(body.sheets.count, 2)
        XCTAssertEqual(body.sheets.first?.sheetId, "sheet_1")
        XCTAssertNil(body.sheets.first?.title)
        XCTAssertEqual(body.sheets.last?.title, "July LPS comparison sheet")
        XCTAssertEqual(
            body.sheets.first?.manifestUrl,
            "https://example.test/api/v1/test_sheets/sheet_1/manifest"
        )
    }

    func testCreateCaptureEncodesMetadataAndQualityAndDecodesCaptureID() async throws {
        let payload = Components.Schemas.CreateCaptureRequest(
            metadata: .init(
                deviceModel: "iPhone",
                lens: "built_in_wide_angle",
                exposureDurationSeconds: 0.016,
                iso: 100,
                focusLensPosition: 0.42,
                whiteBalanceGains: .init(red: 1.2, green: 1.0, blue: 1.4),
                imageWidth: 4032,
                imageHeight: 3024,
                appVersion: "0.1.0",
                timestamp: Date(timeIntervalSince1970: 1_784_980_800)
            ),
            quality: .init(detectedMarkerCount: 4, blurScore: 0.82, rejections: [])
        )
        let (client, transport) = makeClient(stub: { _ in Self.jsonResponse(.created, #"{"capture_id":"cap_1"}"#) })

        let response = try await client.createCapture(
            .init(path: .init(sheetId: "sheet_1"), body: .json(payload))
        )

        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.operationID, "createCapture")
        XCTAssertEqual(request.method, "POST")
        XCTAssertEqual(request.path, "/api/v1/test_sheets/sheet_1/captures")
        XCTAssertEqual(request.contentType, "application/json")
        let json = try Self.jsonObject(from: request.body)
        let root = try XCTUnwrap(json as? [String: Any])
        let metadata = try XCTUnwrap(root["metadata"] as? [String: Any])
        XCTAssertEqual(metadata["device_model"] as? String, "iPhone")
        XCTAssertEqual(metadata["lens"] as? String, "built_in_wide_angle")
        XCTAssertEqual(metadata["app_version"] as? String, "0.1.0")
        XCTAssertEqual((metadata["white_balance_gains"] as? [String: Any])?["red"] as? Double ?? 0, 1.2, accuracy: 0.001)
        XCTAssertEqual((metadata["timestamp"] as? String)?.hasPrefix("2026-07-25"), true)
        let quality = try XCTUnwrap(root["quality"] as? [String: Any])
        XCTAssertEqual(quality["detected_marker_count"] as? Int, 4)
        XCTAssertEqual(quality["rejections"] as? [String], [])
        guard case .created(let success) = response else {
            XCTFail("Expected 201 capture session response, got: \(response)")
            return
        }
        guard case .json(let session) = success.body else {
            XCTFail("Expected JSON capture session body.")
            return
        }
        XCTAssertEqual(session.captureId, "cap_1")
    }

    func testUploadMeasurementsEncodesScoresWithAlgorithmVersion() async throws {
        let payload = Components.Schemas.MeasurementUploadRequest(
            scoringAlgorithmVersion: "lps-distance-v1",
            measurements: [
                .init(
                    patchId: "patch_1",
                    linearRgbMedian: .init(r: 0.12, g: 0.10, b: 0.02),
                    normalizedLinearRgbMedian: .init(r: 0.15, g: 0.12, b: 0.02),
                    stats: .init(
                        sampleCount: 900,
                        clippingFraction: 0,
                        mean: .init(r: 0.12, g: 0.10, b: 0.02),
                        standardDeviation: .init(r: 0.01, g: 0.01, b: 0.004)
                    )
                )
            ],
            pairScores: [
                .init(
                    pairId: "pair_1",
                    distance: 0.035,
                    similarity: 0.965,
                    algorithmVersion: "lps-distance-v1"
                )
            ]
        )
        let (client, transport) = makeClient(stub: { _ in Self.noContentResponse() })

        let response = try await client.uploadMeasurements(
            .init(path: .init(captureId: "cap_1"), body: .json(payload))
        )

        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.operationID, "uploadMeasurements")
        XCTAssertEqual(request.method, "POST")
        XCTAssertEqual(request.path, "/api/v1/captures/cap_1/measurements")
        let root = try XCTUnwrap(Self.jsonObject(from: request.body) as? [String: Any])
        XCTAssertEqual(root["scoring_algorithm_version"] as? String, "lps-distance-v1")
        let measurement = try XCTUnwrap((root["measurements"] as? [[String: Any]])?.first)
        XCTAssertEqual(measurement["patch_id"] as? String, "patch_1")
        let median = try XCTUnwrap(measurement["linear_rgb_median"] as? [String: Any])
        XCTAssertEqual(median["r"] as? Double ?? 0, 0.12, accuracy: 0.0001)
        XCTAssertEqual(median["g"] as? Double ?? 0, 0.10, accuracy: 0.0001)
        XCTAssertEqual(median["b"] as? Double ?? 0, 0.02, accuracy: 0.0001)
        let stats = try XCTUnwrap(measurement["stats"] as? [String: Any])
        XCTAssertEqual(stats["sample_count"] as? Int, 900)
        XCTAssertEqual(Set(stats.keys), ["sample_count", "clipping_fraction", "mean", "standard_deviation"])
        let score = try XCTUnwrap((root["pair_scores"] as? [[String: Any]])?.first)
        XCTAssertEqual(score["pair_id"] as? String, "pair_1")
        XCTAssertEqual(score["algorithm_version"] as? String, "lps-distance-v1")
        guard case .noContent = response else {
            XCTFail("Expected 204 measurement upload response, got: \(response)")
            return
        }
    }

    func testUploadJudgmentsEncodesPairJudgments() async throws {
        let payload = Components.Schemas.JudgmentUploadRequest(
            judgments: [.init(pairId: "pair_1", judgment: "near_match")]
        )
        let (client, transport) = makeClient(stub: { _ in Self.noContentResponse() })

        let response = try await client.uploadJudgments(
            .init(path: .init(captureId: "cap_1"), body: .json(payload))
        )

        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.operationID, "uploadJudgments")
        XCTAssertEqual(request.method, "POST")
        XCTAssertEqual(request.path, "/api/v1/captures/cap_1/judgments")
        let root = try XCTUnwrap(Self.jsonObject(from: request.body) as? [String: Any])
        let judgment = try XCTUnwrap((root["judgments"] as? [[String: Any]])?.first)
        XCTAssertEqual(judgment["pair_id"] as? String, "pair_1")
        XCTAssertEqual(judgment["judgment"] as? String, "near_match")
        guard case .noContent = response else {
            XCTFail("Expected 204 judgment upload response, got: \(response)")
            return
        }
    }

    func testGetRankedResultsDecodesRankedPairs() async throws {
        let payload = """
        {
          "sheet_id": "sheet_1",
          "scoring_algorithm_version": "lps-distance-v1",
          "pairs": [
            {
              "pair_id": "pair_1",
              "source_colors": ["#FF0000", "#00FF00"],
              "distance": 0.035,
              "similarity": 0.965,
              "judgment": "near_match"
            }
          ]
        }
        """
        let (client, transport) = makeClient(stub: { _ in Self.jsonResponse(.ok, payload) })

        let response = try await client.getRankedResults(.init(path: .init(sheetId: "sheet_1")))

        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.operationID, "getRankedResults")
        XCTAssertEqual(request.method, "GET")
        XCTAssertEqual(request.path, "/api/v1/test_sheets/sheet_1/ranked_results")
        guard case .ok(let success) = response else {
            XCTFail("Expected 200 ranked results response, got: \(response)")
            return
        }
        guard case .json(let results) = success.body else {
            XCTFail("Expected JSON ranked results body.")
            return
        }
        XCTAssertEqual(results.sheetId, "sheet_1")
        XCTAssertEqual(results.scoringAlgorithmVersion, "lps-distance-v1")
        let pair = try XCTUnwrap(results.pairs.first)
        XCTAssertEqual(pair.pairId, "pair_1")
        XCTAssertEqual(pair.sourceColors, ["#FF0000", "#00FF00"])
        XCTAssertEqual(pair.distance, 0.035, accuracy: 0.0001)
        XCTAssertEqual(pair.similarity, 0.965, accuracy: 0.0001)
        XCTAssertEqual(pair.judgment, "near_match")
    }

    private func makeClient(
        stub: @escaping (RecordedRequest) -> (HTTPResponse, HTTPBody?)
    ) -> (Client, StubTransport) {
        let transport = StubTransport(stub: stub)
        return (Client(serverURL: serverURL, transport: transport), transport)
    }

    private static let manifestJSON = """
    {
      "schema_version": "lps-sheet-manifest/v1",
      "sheet_version": "lps-letter-grid-v1",
      "sheet_id": "sheet_1",
      "manifest_url": "https://example.test/api/v1/test_sheets/sheet_1/manifest",
      "created_at": "2026-07-25T12:00:00Z",
      "page": {"units": "mm", "width": 215.9, "height": 279.4},
      "registration_markers": [
        {"role": "top_left", "shape": "solid_square", "rect": {"x": 12, "y": 12, "width": 8, "height": 8}}
      ],
      "printer_profile": {
        "id": "printer_profile_1",
        "name": "Research printer",
        "paper": "paper name",
        "ink": "ink set",
        "settings": {}
      },
      "capture_profile": {
        "expected_illuminant": "low_pressure_sodium",
        "preferred_camera": "built_in_wide_angle_rear",
        "scoring_algorithm_version": "lps-distance-v1"
      },
      "patches": [
        {
          "id": "patch_1",
          "role": "pair_color",
          "pair_id": "pair_1",
          "pair_side": "first",
          "reference_role": null,
          "source_color": "#FF0000",
          "safe_inset_mm": 1.5,
          "rect": {"x": 16, "y": 38, "width": 16, "height": 10}
        }
      ],
      "pairs": [
        {
          "id": "pair_1",
          "first_patch_id": "patch_1",
          "second_patch_id": "patch_2",
          "source_colors": ["#FF0000", "#00FF00"],
          "grid_row": 0,
          "grid_col": 1
        }
      ]
    }
    """

    private static func jsonResponse(
        _ status: HTTPResponse.Status,
        _ payload: String
    ) -> (HTTPResponse, HTTPBody?) {
        var response = HTTPResponse(status: status)
        response.headerFields[.contentType] = "application/json"
        return (response, HTTPBody(Data(payload.utf8)))
    }

    private static func noContentResponse() -> (HTTPResponse, HTTPBody?) {
        (HTTPResponse(status: .noContent), nil)
    }

    private static func jsonObject(from data: Data?) throws -> Any {
        try JSONSerialization.jsonObject(with: XCTUnwrap(data))
    }
}

private struct RecordedRequest {
    let operationID: String
    let method: String
    let path: String?
    let contentType: String?
    let body: Data?
}

private final class StubTransport: ClientTransport, @unchecked Sendable {
    private let stub: (RecordedRequest) -> (HTTPResponse, HTTPBody?)
    private(set) var requests: [RecordedRequest] = []

    init(stub: @escaping (RecordedRequest) -> (HTTPResponse, HTTPBody?)) {
        self.stub = stub
    }

    func send(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String
    ) async throws -> (HTTPResponse, HTTPBody?) {
        var collected: Data?
        if let body {
            collected = try await Data(collecting: body, upTo: 10 * 1024 * 1024)
        }
        let recorded = RecordedRequest(
            operationID: operationID,
            method: String(describing: request.method),
            path: request.path,
            contentType: request.headerFields[.contentType],
            body: collected
        )
        requests.append(recorded)
        return stub(recorded)
    }
}
#else
import XCTest

final class OpenAPIClientTests: XCTestCase {
    func testGetManifestDecodesSheetManifest() async throws {
        XCTFail(redPhaseMessage)
    }

    func testGetRecentSheetsDecodesOptionalTitles() async throws {
        XCTFail(redPhaseMessage)
    }

    func testCreateCaptureEncodesMetadataAndQualityAndDecodesCaptureID() async throws {
        XCTFail(redPhaseMessage)
    }

    func testUploadMeasurementsEncodesScoresWithAlgorithmVersion() async throws {
        XCTFail(redPhaseMessage)
    }

    func testUploadJudgmentsEncodesPairJudgments() async throws {
        XCTFail(redPhaseMessage)
    }

    func testGetRankedResultsDecodesRankedPairs() async throws {
        XCTFail(redPhaseMessage)
    }

    private var redPhaseMessage: String {
        "Generated OpenAPI client target 'ColorMatchingOpenAPI' is not wired into the Swift package yet; see docs/openapi-generated-client-plan.md."
    }
}
#endif
