#if canImport(ColorMatchingOpenAPI)
import Foundation
import XCTest
import OpenAPIRuntime
import ColorMatchingOpenAPI

final class GeneratedClientStubbedResponseTests: XCTestCase {
    func testGetTestSheetManifestDecodesStubbedResponse() async throws {
        let transport = StubTransport { request, _, operationID in
            XCTAssertEqual(operationID, "getTestSheetManifest")
            XCTAssertEqual(request.method, .get)
            XCTAssertEqual(request.path, "/api/v1/test_sheets/sheet_1/manifest")
            return Self.jsonResponse(200, StubFixtures.manifestJSON)
        }
        let client = ColorMatchingOpenAPI.Client(
            serverURL: URL(string: "https://example.test")!,
            transport: transport
        )

        let response = try await client.getTestSheetManifest(.init(path: .init(sheet_id: "sheet_1")))

        guard case .ok(let ok) = response else { return XCTFail("expected 200 ok for manifest") }
        guard case .json(let manifest) = ok.body else { return XCTFail("expected json manifest body") }
        XCTAssertEqual(manifest.schemaVersion.rawValue, "lps-sheet-manifest/v1")
        XCTAssertEqual(manifest.sheetId, "sheet_1")
        XCTAssertEqual(manifest.sheetVersion, "lps-letter-grid-v1")
        XCTAssertEqual(manifest.captureProfile.scoringAlgorithmVersion.rawValue, "lps-distance-v1")
    }

    func testGetRecentSheetsDecodesNullableTitles() async throws {
        let transport = StubTransport { request, _, operationID in
            XCTAssertEqual(operationID, "getRecentSheets")
            XCTAssertEqual(request.method, .get)
            XCTAssertEqual(request.path, "/api/v1/test_sheets/recent")
            return Self.jsonResponse(200, StubFixtures.recentSheetsJSON)
        }
        let client = ColorMatchingOpenAPI.Client(
            serverURL: URL(string: "https://example.test")!,
            transport: transport
        )

        let response = try await client.getRecentSheets(.init())

        guard case .ok(let ok) = response else { return XCTFail("expected 200 ok for recent sheets") }
        guard case .json(let payload) = ok.body else { return XCTFail("expected json recent-sheets body") }
        XCTAssertEqual(payload.sheets.count, 2)
        XCTAssertEqual(payload.sheets.first?.sheetId, "sheet_1")
        XCTAssertNil(payload.sheets.first?.title)
        XCTAssertEqual(payload.sheets.last?.title, "July LPS sheet")
    }

    func testCreateCaptureEncodesNestedMetadataAndDecodesCaptureID() async throws {
        let transport = StubTransport { request, body, operationID in
            XCTAssertEqual(operationID, "createCapture")
            XCTAssertEqual(request.method, .post)
            XCTAssertEqual(request.path, "/api/v1/test_sheets/sheet_1/captures")
            let data = try Data(collecting: XCTUnwrap(body), upTo: 1_048_576)
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
            let metadata = try XCTUnwrap(json["metadata"] as? [String: Any])
            XCTAssertEqual(metadata["device_model"] as? String, "iPhone 15")
            XCTAssertEqual(metadata["image_width"] as? Int, 4032)
            let quality = try XCTUnwrap(json["quality"] as? [String: Any])
            XCTAssertEqual(quality["detected_marker_count"] as? Int, 4)
            XCTAssertEqual(quality["rejections"] as? [String], [])
            return Self.jsonResponse(201, #"{"capture_id":"cap_1"}"#)
        }
        let client = ColorMatchingOpenAPI.Client(
            serverURL: URL(string: "https://example.test")!,
            transport: transport
        )

        let requestBody = Components.Schemas.CaptureRequest(
            metadata: .init(
                deviceModel: "iPhone 15",
                lens: "built_in_wide_angle_rear",
                imageWidth: 4032,
                imageHeight: 3024,
                appVersion: "0.1.0",
                timestamp: Date(timeIntervalSince1970: 1_784_980_800)
            ),
            quality: .init(detectedMarkerCount: 4, blurScore: 0.75, rejections: [])
        )
        let response = try await client.createCapture(
            .init(path: .init(sheet_id: "sheet_1"), body: .json(requestBody))
        )

        guard case .created(let created) = response else { return XCTFail("expected 201 created for capture") }
        guard case .json(let payload) = created.body else { return XCTFail("expected json capture body") }
        XCTAssertEqual(payload.captureId, "cap_1")
    }

    func testUploadMeasurementsEncodesPayloadAndDecodesCounts() async throws {
        let transport = StubTransport { request, body, operationID in
            XCTAssertEqual(operationID, "uploadMeasurements")
            XCTAssertEqual(request.method, .post)
            XCTAssertEqual(request.path, "/api/v1/captures/cap_1/measurements")
            let data = try Data(collecting: XCTUnwrap(body), upTo: 1_048_576)
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
            let measurement = try XCTUnwrap((json["measurements"] as? [[String: Any]])?.first)
            XCTAssertEqual(measurement["patch_id"] as? String, "patch_1")
            let median = try XCTUnwrap(measurement["linear_rgb_median"] as? [String: Any])
            XCTAssertEqual(median["r"] as? Double ?? -1, 0.12, accuracy: 0.0001)
            XCTAssertEqual(median["g"] as? Double ?? -1, 0.1, accuracy: 0.0001)
            XCTAssertEqual(median["b"] as? Double ?? -1, 0.02, accuracy: 0.0001)
            let normalized = try XCTUnwrap(measurement["normalized_linear_rgb_median"] as? [String: Any])
            XCTAssertEqual(normalized["r"] as? Double ?? -1, 0.15, accuracy: 0.0001)
            let score = try XCTUnwrap((json["pair_scores"] as? [[String: Any]])?.first)
            XCTAssertEqual(score["pair_id"] as? String, "pair_1")
            XCTAssertEqual(score["algorithm_version"] as? String, "lps-distance-v1")
            return Self.jsonResponse(
                200,
                #"{"capture_id":"cap_1","measurement_count":1,"pair_score_count":1}"#
            )
        }
        let client = ColorMatchingOpenAPI.Client(
            serverURL: URL(string: "https://example.test")!,
            transport: transport
        )

        let requestBody = Components.Schemas.MeasurementUploadRequest(
            measurements: [
                .init(
                    patchId: "patch_1",
                    linearRgbMedian: .case2(.init(r: 0.12, g: 0.1, b: 0.02)),
                    normalizedLinearRgbMedian: .case2(.init(r: 0.15, g: 0.12, b: 0.02))
                )
            ],
            pairScores: [
                .init(pairId: "pair_1", algorithmVersion: "lps-distance-v1", similarity: 0.965)
            ]
        )
        let response = try await client.uploadMeasurements(
            .init(path: .init(capture_id: "cap_1"), body: .json(requestBody))
        )

        guard case .ok(let ok) = response else { return XCTFail("expected 200 ok for measurements") }
        guard case .json(let payload) = ok.body else { return XCTFail("expected json measurement response") }
        XCTAssertEqual(payload.captureId, "cap_1")
        XCTAssertEqual(payload.measurementCount, 1)
        XCTAssertEqual(payload.pairScoreCount, 1)
    }

    func testUploadJudgmentsEncodesPayloadAndDecodesCount() async throws {
        let transport = StubTransport { request, body, operationID in
            XCTAssertEqual(operationID, "uploadJudgments")
            XCTAssertEqual(request.method, .post)
            XCTAssertEqual(request.path, "/api/v1/captures/cap_1/judgments")
            let data = try Data(collecting: XCTUnwrap(body), upTo: 1_048_576)
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
            let judgment = try XCTUnwrap((json["judgments"] as? [[String: Any]])?.first)
            XCTAssertEqual(judgment["pair_id"] as? String, "pair_1")
            XCTAssertEqual(judgment["judgment"] as? String, "near_match")
            return Self.jsonResponse(200, #"{"capture_id":"cap_1","judgment_count":1}"#)
        }
        let client = ColorMatchingOpenAPI.Client(
            serverURL: URL(string: "https://example.test")!,
            transport: transport
        )

        let requestBody = Components.Schemas.JudgmentUploadRequest(
            judgments: [.init(pairId: "pair_1", judgment: "near_match")]
        )
        let response = try await client.uploadJudgments(
            .init(path: .init(capture_id: "cap_1"), body: .json(requestBody))
        )

        guard case .ok(let ok) = response else { return XCTFail("expected 200 ok for judgments") }
        guard case .json(let payload) = ok.body else { return XCTFail("expected json judgment response") }
        XCTAssertEqual(payload.captureId, "cap_1")
        XCTAssertEqual(payload.judgmentCount, 1)
    }

    func testGetRankedResultsDecodesStubbedResponse() async throws {
        let transport = StubTransport { request, _, operationID in
            XCTAssertEqual(operationID, "getRankedResults")
            XCTAssertEqual(request.method, .get)
            XCTAssertEqual(request.path, "/api/v1/test_sheets/sheet_1/ranked_results")
            return Self.jsonResponse(
                200,
                #"{"schema_version":"lps-ranked-results/v1","sheet_id":"sheet_1"}"#
            )
        }
        let client = ColorMatchingOpenAPI.Client(
            serverURL: URL(string: "https://example.test")!,
            transport: transport
        )

        let response = try await client.getRankedResults(.init(path: .init(sheet_id: "sheet_1")))

        guard case .ok(let ok) = response else { return XCTFail("expected 200 ok for ranked results") }
        guard case .json(let payload) = ok.body else { return XCTFail("expected json ranked-results body") }
        XCTAssertEqual(payload.schemaVersion.rawValue, "lps-ranked-results/v1")
        XCTAssertEqual(payload.sheetId, "sheet_1")
    }

    private static func jsonResponse(_ statusCode: Int, _ payload: String) -> (HTTPResponse, HTTPBody?) {
        let response = HTTPResponse(status: .init(code: statusCode))
        response.headerFields[.contentContentType] = "application/json"
        return (response, HTTPBody(Data(payload.utf8)))
    }
}

private struct StubTransport: ClientTransport {
    let respond: @Sendable (HTTPRequest, HTTPBody?, String) async throws -> (HTTPResponse, HTTPBody?)

    func send(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String
    ) async throws -> (HTTPResponse, HTTPBody?) {
        try await respond(request, body, operationID)
    }
}

private enum StubFixtures {
    static let manifestJSON = #"{"schema_version":"lps-sheet-manifest/v1","sheet_version":"lps-letter-grid-v1","sheet_id":"sheet_1","manifest_url":"https://example.test/api/v1/test_sheets/sheet_1/manifest","page":{"units":"mm","width":215.9,"height":279.4},"registration_markers":[{"role":"top_left","shape":"solid_square","rect":{"x":12,"y":12,"width":8,"height":8}}],"patches":[{"id":"patch_1","role":"pair_color","pair_id":"pair_1","pair_side":"first","reference_role":null,"source_color":"#FF0000","safe_inset_mm":1.5,"rect":{"x":16,"y":38,"width":16,"height":10}}],"pairs":[{"id":"pair_1","first_patch_id":"patch_1","second_patch_id":"patch_2","source_colors":["#FF0000","#00FF00"],"grid_row":0,"grid_col":1}]}"#

    static let recentSheetsJSON = #"{"sheets":[{"sheet_id":"sheet_1","manifest_url":"https://example.test/api/v1/test_sheets/sheet_1/manifest","title":null},{"sheet_id":"sheet_2","manifest_url":"https://example.test/api/v1/test_sheets/sheet_2/manifest","title":"July LPS sheet"}]}"#
}
#endif
