import ColorMatchingLPSAppCore
import ColorMatchingOpenAPI
import XCTest

final class GeneratedClientTests: XCTestCase {
    func testGetManifestDecodesDocumentedFieldsAndIgnoresUndocumentedOnes() async throws {
        let (client, transport) = makeGeneratedClient(
            stub: .json(status: .ok, body: GeneratedClientFixtures.fullManifestJSON)
        )

        let response = try await client.getManifest(.init(path: .init(sheetID: "sheet_123")))

        let manifest = try response.ok.body.json
        XCTAssertEqual(manifest.sheetId, "sheet_123")
        XCTAssertEqual(manifest.schemaVersion, .lpsSheetManifestV1)
        XCTAssertEqual(manifest.captureProfile.scoringAlgorithmVersion, .lpsDistanceV1)
        XCTAssertEqual(transport.recorded.count, 1)
    }

    func testGetManifestSendsExpectedRequestMethodPathAndOperationID() async throws {
        let (client, transport) = makeGeneratedClient(
            stub: .json(status: .ok, body: GeneratedClientFixtures.fullManifestJSON)
        )

        _ = try await client.getManifest(.init(path: .init(sheetID: "sheet_123")))

        let recorded = try XCTUnwrap(transport.recorded.first)
        XCTAssertEqual(recorded.method, "GET")
        XCTAssertEqual(recorded.path, "/api/v1/test_sheets/sheet_123/manifest")
        XCTAssertEqual(recorded.operationID, "ColorMatchingWeb.TestSheetController.manifest")
        XCTAssertNil(recorded.authorization)
        XCTAssertNil(recorded.body)
        XCTAssertTrue(recorded.accept?.contains("application/json") == true)
        XCTAssertNil(recorded.contentType)
    }

    func testListRecentSheetsDecodesSheetsIncludingNullableTitle() async throws {
        let (client, transport) = makeGeneratedClient(
            stub: .json(status: .ok, body: GeneratedClientFixtures.recentSheetsJSON)
        )

        let response = try await client.listRecentSheets(.init())

        let payload = try response.ok.body.json
        XCTAssertEqual(payload.sheets.count, 2)
        let first = try XCTUnwrap(payload.sheets.first)
        XCTAssertEqual(first.sheetId, "sheet_123")
        XCTAssertEqual(first.manifestUrl, "https://example.test/api/v1/test_sheets/sheet_123/manifest")
        XCTAssertEqual(first.title, "July LPS comparison sheet")
        XCTAssertNil(payload.sheets.last?.title)
        let recorded = try XCTUnwrap(transport.recorded.first)
        XCTAssertEqual(recorded.path, "/api/v1/test_sheets/recent")
        XCTAssertEqual(recorded.method, "GET")
        XCTAssertEqual(recorded.operationID, "ColorMatchingWeb.TestSheetController.recent")
    }

    func testGetRankedResultsDecodesSchemaVersionAndSheetID() async throws {
        let (client, transport) = makeGeneratedClient(
            stub: .json(status: .ok, body: GeneratedClientFixtures.rankedResultsJSON)
        )

        let response = try await client.getRankedResults(.init(path: .init(sheetID: "sheet_123")))

        let payload = try response.ok.body.json
        XCTAssertEqual(payload.schemaVersion, .lpsRankedResultsV1)
        XCTAssertEqual(payload.sheetId, "sheet_123")
        let recorded = try XCTUnwrap(transport.recorded.first)
        XCTAssertEqual(recorded.method, "GET")
        XCTAssertEqual(recorded.path, "/api/v1/test_sheets/sheet_123/ranked_results")
        XCTAssertEqual(recorded.operationID, "ColorMatchingWeb.TestSheetController.ranked_results")
    }

    func testUndocumentedResponseStatusSurfacesAsUndocumentedCase() async throws {
        let (client, _) = makeGeneratedClient(stub: .empty(status: .internalServerError))

        let response = try await client.getManifest(.init(path: .init(sheetID: "sheet_123")))

        switch response {
        case .undocumented(let statusCode, _):
            XCTAssertEqual(statusCode, 500)
        default:
            XCTFail("Expected an undocumented response, got \(response)")
        }
    }

    func testBearerTokenMiddlewareAddsAuthorizationHeader() async throws {
        let (client, transport) = makeGeneratedClient(
            stub: .json(status: .ok, body: GeneratedClientFixtures.recentSheetsJSON),
            middlewares: [BearerTokenMiddleware(token: "unit-test-token")]
        )

        _ = try await client.listRecentSheets(.init())

        let recorded = try XCTUnwrap(transport.recorded.first)
        XCTAssertEqual(recorded.authorization, "Bearer unit-test-token")
    }
}
