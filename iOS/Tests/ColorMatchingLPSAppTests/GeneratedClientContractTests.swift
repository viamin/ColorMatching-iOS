#if canImport(ColorMatchingOpenAPI)
import ColorMatchingOpenAPI
import Foundation
import HTTPTypes
import OpenAPIRuntime
import XCTest

final class GeneratedClientContractTests: XCTestCase {
    func testGetRankedResultsSendsPublishedPathAndDecodesResponse() async throws {
        let transport = StubTransport { request, _, operationID in
            XCTAssertEqual(request.method, .get)
            XCTAssertEqual(request.path, "/api/v1/test_sheets/sheet_1/ranked_results")
            XCTAssertEqual(operationID, "getRankedResults")
            return Self.okJSON(#"{"schema_version":"lps-ranked-results/v1","sheet_id":"sheet_1"}"#)
        }
        let client = ColorMatchingOpenAPI.Client(serverURL: Self.serverURL, transport: transport)

        let response = try await client.getRankedResults(.init(path: .init(sheet_id: "sheet_1")))

        guard case .ok(let ok) = response else {
            return XCTFail("expected 200 ok for ranked results, got: \(response)")
        }
        let body = try await ok.body.json
        XCTAssertEqual(body.sheet_id, "sheet_1")
        XCTAssertEqual(body.schema_version.rawValue, "lps-ranked-results/v1")
    }

    func testListRecentSheetsDecodesPublishedResponse() async throws {
        let transport = StubTransport { request, _, operationID in
            XCTAssertEqual(request.method, .get)
            XCTAssertEqual(request.path, "/api/v1/test_sheets/recent")
            XCTAssertEqual(operationID, "listRecentSheets")
            return Self.okJSON(#"{"sheets":[{"sheet_id":"sheet_1","manifest_url":"https://example.test/m","title":null},{"sheet_id":"sheet_2","manifest_url":"https://example.test/m2","title":"July LPS comparison sheet"}]}"#)
        }
        let client = ColorMatchingOpenAPI.Client(serverURL: Self.serverURL, transport: transport)

        let response = try await client.listRecentSheets(.init())

        guard case .ok(let ok) = response else {
            return XCTFail("expected 200 ok for recent sheets, got: \(response)")
        }
        let body = try await ok.body.json
        XCTAssertEqual(body.sheets.map(\.sheet_id), ["sheet_1", "sheet_2"])
        XCTAssertEqual(body.sheets.map(\.title), [nil, "July LPS comparison sheet"])
    }

    func testUploadJudgmentsDecodesCountedResponse() async throws {
        let transport = StubTransport { request, body, operationID in
            XCTAssertEqual(request.method, .post)
            XCTAssertEqual(request.path, "/api/v1/captures/cap_1/judgments")
            XCTAssertEqual(operationID, "uploadJudgments")
            XCTAssertEqual(request.headerFields[.contentType], "application/json")
            let data = try await Data(collecting: XCTUnwrap(body), upTo: 1_048_576)
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
            let judgment = try XCTUnwrap((json["judgments"] as? [[String: Any]])?.first)
            XCTAssertEqual(judgment["pair_id"] as? String, "pair_1")
            XCTAssertEqual(judgment["judgment"] as? String, "near_match")
            return Self.okJSON(#"{"capture_id":"cap_1","judgment_count":1}"#)
        }
        let client = ColorMatchingOpenAPI.Client(serverURL: Self.serverURL, transport: transport)

        let response = try await client.uploadJudgments(
            .init(path: .init(capture_id: "cap_1"), body: .json(.init(judgments: [.init(pair_id: "pair_1", judgment: "near_match")])))
        )

        guard case .ok(let ok) = response else {
            return XCTFail("expected 200 ok for judgment upload, got: \(response)")
        }
        let counted = try await ok.body.json
        XCTAssertEqual(counted.capture_id, "cap_1")
        XCTAssertEqual(counted.judgment_count, 1)
    }

    func testGeneratedManifestTypeDecodesMinimalPublishedPayload() throws {
        let manifest = try Self.decode(
            Components.Schemas.TestSheetManifest.self,
            from: #"{"schema_version":"lps-sheet-manifest/v1","sheet_id":"sheet_1","capture_profile":{"scoring_algorithm_version":"lps-distance-v1"}}"#
        )

        XCTAssertEqual(manifest.sheet_id, "sheet_1")
        XCTAssertEqual(manifest.schema_version.rawValue, "lps-sheet-manifest/v1")
        XCTAssertEqual(manifest.capture_profile.scoring_algorithm_version.rawValue, "lps-distance-v1")
    }

    func testGeneratedRankedResultsTypeDecodesPublishedPayload() throws {
        let results = try Self.decode(
            Components.Schemas.RankedResults.self,
            from: #"{"schema_version":"lps-ranked-results/v1","sheet_id":"sheet_1"}"#
        )

        XCTAssertEqual(results.sheet_id, "sheet_1")
        XCTAssertEqual(results.schema_version.rawValue, "lps-ranked-results/v1")
    }

    func testGeneratedUploadResponseTypesDecodePublishedPayloads() throws {
        let measurements = try Self.decode(
            Components.Schemas.MeasurementUploadResponse.self,
            from: #"{"capture_id":"cap_1","measurement_count":2,"pair_score_count":1}"#
        )
        XCTAssertEqual(measurements.capture_id, "cap_1")
        XCTAssertEqual(measurements.measurement_count, 2)
        XCTAssertEqual(measurements.pair_score_count, 1)

        let judgments = try Self.decode(
            Components.Schemas.JudgmentUploadResponse.self,
            from: #"{"capture_id":"cap_1","judgment_count":1}"#
        )
        XCTAssertEqual(judgments.capture_id, "cap_1")
        XCTAssertEqual(judgments.judgment_count, 1)

        let capture = try Self.decode(
            Components.Schemas.CaptureCreatedResponse.self,
            from: #"{"capture_id":"cap_1"}"#
        )
        XCTAssertEqual(capture.capture_id, "cap_1")
    }

    private static let serverURL = URL(string: "https://example.test")!

    private static func decode<T: Decodable>(_ type: T.Type, from json: String) throws -> T {
        try JSONDecoder().decode(type, from: Data(json.utf8))
    }

    private static func okJSON(_ payload: String) -> (HTTPResponse, HTTPBody?) {
        var response = HTTPResponse(status: .ok)
        response.headerFields[.contentType] = "application/json"
        return (response, HTTPBody(Data(payload.utf8)))
    }
}

private struct StubTransport: ClientTransport {
    var respond: (HTTPRequest, HTTPBody?, String) async throws -> (HTTPResponse, HTTPBody?)

    func send(_ request: HTTPTypes.HTTPRequest, body: HTTPBody?, baseURL: URL, operationID: String) async throws -> (HTTPResponse, HTTPBody?) {
        try await respond(request, body, operationID)
    }
}
#else
import XCTest

final class GeneratedClientContractTests: XCTestCase {
    func testGeneratedOpenAPIClientModuleIsWiredIntoPackage() {
        XCTFail(
            "ColorMatchingOpenAPI (the client generated by swift-openapi-generator from the vendored spec) is not wired into the package yet; see docs/color-matching-openapi-delta.md"
        )
    }
}
#endif
