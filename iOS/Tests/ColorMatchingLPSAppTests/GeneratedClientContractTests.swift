import ColorMatchingOpenAPI
import OpenAPIRuntime
import XCTest

final class GeneratedClientContractTests: XCTestCase {
    private func makeClient(
        status: HTTPResponse.Status = .ok,
        json: String? = nil
    ) -> (ColorMatchingOpenAPI.Client, RecordingTransport) {
        let transport = RecordingTransport(status: status, body: json.map(SpecFixtures.data))
        let client = ColorMatchingOpenAPI.Client(serverURL: SpecFixtures.baseURL, transport: transport)
        return (client, transport)
    }

    func testManifestOperationUsesSpecifiedRouteAndDecodesFullManifest() async throws {
        let (client, transport) = makeClient(json: SpecFixtures.manifestJSON)

        let response = try await client.colorMatchingWeb_TestSheetController_manifest(
            .init(path: .init(sheetId: "sheet_123"))
        )

        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.method, "GET")
        XCTAssertEqual(request.path, "/api/v1/test_sheets/sheet_123/manifest")
        XCTAssertEqual(request.operationID, "ColorMatchingWeb.TestSheetController.manifest")
        guard case .ok(let ok) = response else {
            return XCTFail("Expected .ok response for manifest")
        }
        XCTAssertEqual(ok.statusCode, 200)
        assertFullManifestDecoded(ok.body.json)
    }

    func testRecentSheetsOperationUsesSpecifiedRouteAndDecodesNullableTitle() async throws {
        let (client, transport) = makeClient(json: SpecFixtures.recentSheetsJSON)

        let response = try await client.colorMatchingWeb_TestSheetController_recent(.init())

        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.method, "GET")
        XCTAssertEqual(request.path, "/api/v1/test_sheets/recent")
        XCTAssertEqual(request.operationID, "ColorMatchingWeb.TestSheetController.recent")
        guard case .ok(let ok) = response else {
            return XCTFail("Expected .ok response for recent sheets")
        }
        let sheet = try XCTUnwrap(ok.body.json.sheets.first)
        XCTAssertEqual(sheet.sheetId, "sheet_123")
        XCTAssertEqual(sheet.manifestUrl, "https://example.test/api/v1/test_sheets/sheet_123/manifest")
        XCTAssertNil(sheet.title)
    }

    func testRankedResultsOperationUsesSpecifiedRouteAndDecodesResultRows() async throws {
        let (client, transport) = makeClient(json: SpecFixtures.rankedResultsJSON)

        let response = try await client.colorMatchingWeb_TestSheetController_ranked_results(
            .init(path: .init(sheetId: "sheet_123"))
        )

        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.method, "GET")
        XCTAssertEqual(request.path, "/api/v1/test_sheets/sheet_123/ranked_results")
        XCTAssertEqual(request.operationID, "ColorMatchingWeb.TestSheetController.ranked_results")
        guard case .ok(let ok) = response else {
            return XCTFail("Expected .ok response for ranked results")
        }
        let ranked = ok.body.json
        XCTAssertEqual(ranked.schemaVersion.rawValue, "lps-ranked-results/v1")
        XCTAssertEqual(ranked.sheetId, "sheet_123")
        XCTAssertEqual(ranked.captureCount, 2)
        XCTAssertEqual(ranked.scoringAlgorithmVersions, ["lps-distance-v1"])
        let row = try XCTUnwrap(ranked.results.first)
        XCTAssertEqual(row.rank, 1)
        XCTAssertEqual(row.pairId, "pair_1")
        XCTAssertEqual(row.scoringAlgorithmVersion, "lps-distance-v1")
        XCTAssertEqual(row.sourceColors.colorAHex, "#FF0000")
        XCTAssertEqual(row.score.average, 0.965, accuracy: 0.0001)
        XCTAssertEqual(row.score.sampleCount, 4)
        XCTAssertEqual(row.currentJudgment, "near_match")
    }

    func testCreateCaptureOperationSendsNestedMetadataAndQualityAndDecodesCreatedResponse() async throws {
        let (client, transport) = makeClient(status: .created, json: SpecFixtures.captureCreatedJSON)

        let metadata = Components.Schemas.CaptureMetadata(
            appVersion: "0.1.0",
            deviceModel: "iPhone 15 Pro",
            exposureDurationSeconds: 0.016,
            focusLensPosition: 0.42,
            imageHeight: 3024,
            imageWidth: 4032,
            iso: 100,
            lens: "built_in_wide_angle",
            timestamp: Date(timeIntervalSince1970: 0),
            whiteBalanceGains: nil
        )
        let quality = Components.Schemas.CaptureRequest.qualityPayload(
            blurScore: 0.75,
            detectedMarkerCount: 4,
            rejections: []
        )
        let response = try await client.colorMatchingWeb_CaptureController_create(
            .init(
                path: .init(sheetId: "sheet_123"),
                body: .json(Components.Schemas.CaptureRequest(metadata: metadata, quality: quality))
            )
        )

        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.method, "POST")
        XCTAssertEqual(request.path, "/api/v1/test_sheets/sheet_123/captures")
        XCTAssertEqual(request.contentType, "application/json")
        XCTAssertEqual(request.operationID, "ColorMatchingWeb.CaptureController.create")
        let json = try XCTUnwrap(StubbedHTTP.jsonObject(from: request.body) as? [String: Any])
        let metadataJSON = try XCTUnwrap(json["metadata"] as? [String: Any])
        XCTAssertEqual(metadataJSON["device_model"] as? String, "iPhone 15 Pro")
        XCTAssertEqual(metadataJSON["lens"] as? String, "built_in_wide_angle")
        XCTAssertEqual(metadataJSON["timestamp"] as? String, "1970-01-01T00:00:00Z")
        XCTAssertEqual(metadataJSON["iso"] as? Int, 100)
        let qualityJSON = try XCTUnwrap(json["quality"] as? [String: Any])
        XCTAssertEqual(qualityJSON["detected_marker_count"] as? Int, 4)
        XCTAssertEqual(qualityJSON["rejections"] as? [String], [])
        guard case .created(let created) = response else {
            return XCTFail("Expected .created response for capture creation")
        }
        XCTAssertEqual(created.statusCode, 201)
        XCTAssertEqual(created.body.json.captureId, "12")
    }

    func testUploadMeasurementsOperationUsesSpecifiedRouteAndDecodesCountResponseBody() async throws {
        let (client, transport) = makeClient(json: SpecFixtures.measurementUploadJSON)

        let response = try await client.colorMatchingWeb_CaptureController_upload_measurements(
            .init(path: .init(captureId: "12"), body: .json(.init(measurements: [], pairScores: [])))
        )

        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.method, "POST")
        XCTAssertEqual(request.path, "/api/v1/captures/12/measurements")
        XCTAssertEqual(request.contentType, "application/json")
        XCTAssertEqual(request.operationID, "ColorMatchingWeb.CaptureController.upload_measurements")
        guard case .ok(let ok) = response else {
            return XCTFail("Expected .ok response for measurement upload")
        }
        XCTAssertEqual(ok.statusCode, 200)
        XCTAssertEqual(ok.body.json.captureId, "12")
        XCTAssertEqual(ok.body.json.measurementCount, 1)
        XCTAssertEqual(ok.body.json.pairScoreCount, 1)
    }

    func testUploadJudgmentsOperationUsesSpecifiedRouteAndDecodesCountResponseBody() async throws {
        let (client, transport) = makeClient(json: SpecFixtures.judgmentUploadJSON)

        let response = try await client.colorMatchingWeb_CaptureController_upload_judgments(
            .init(
                path: .init(captureId: "12"),
                body: .json(
                    .init(judgments: [.init(judgment: "near_match", pairId: "pair_1")])
                )
            )
        )

        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.method, "POST")
        XCTAssertEqual(request.path, "/api/v1/captures/12/judgments")
        XCTAssertEqual(request.contentType, "application/json")
        XCTAssertEqual(request.operationID, "ColorMatchingWeb.CaptureController.upload_judgments")
        let json = try XCTUnwrap(StubbedHTTP.jsonObject(from: request.body) as? [String: Any])
        let judgments = try XCTUnwrap(json["judgments"] as? [[String: Any]])
        XCTAssertEqual(judgments.first?["pair_id"] as? String, "pair_1")
        XCTAssertEqual(judgments.first?["judgment"] as? String, "near_match")
        guard case .ok(let ok) = response else {
            return XCTFail("Expected .ok response for judgment upload")
        }
        XCTAssertEqual(ok.statusCode, 200)
        XCTAssertEqual(ok.body.json.captureId, "12")
        XCTAssertEqual(ok.body.json.judgmentCount, 1)
    }

    func testManifestOperationSurfacesNotFoundResponseAsTypedCase() async throws {
        let (client, transport) = makeClient(status: .notFound, json: SpecFixtures.sheetNotFoundJSON)

        let response = try await client.colorMatchingWeb_TestSheetController_manifest(
            .init(path: .init(sheetId: "missing"))
        )

        XCTAssertEqual(transport.requests.first?.path, "/api/v1/test_sheets/missing/manifest")
        guard case .notFound(let notFound) = response else {
            return XCTFail("Expected .notFound response for unknown sheet")
        }
        XCTAssertEqual(notFound.statusCode, 404)
    }

    func testRecentSheetsOperationSurfacesUnauthorizedResponseAsTypedCase() async throws {
        let (client, _) = makeClient(status: .unauthorized, json: SpecFixtures.sheetNotFoundJSON)

        let response = try await client.colorMatchingWeb_TestSheetController_recent(.init())

        guard case .unauthorized(let unauthorized) = response else {
            return XCTFail("Expected .unauthorized response for missing token")
        }
        XCTAssertEqual(unauthorized.statusCode, 401)
    }

    func testUploadMeasurementsOperationSurfacesUndocumentedStatusAsDriftSignal() async throws {
        let (client, _) = makeClient(status: .noContent)

        let response = try await client.colorMatchingWeb_CaptureController_upload_measurements(
            .init(path: .init(captureId: "12"), body: .json(.init(measurements: [], pairScores: [])))
        )

        guard case .undocumented(let statusCode, _) = response else {
            return XCTFail("Expected .undocumented response for status the spec does not declare")
        }
        XCTAssertEqual(statusCode, 204)
    }
}
