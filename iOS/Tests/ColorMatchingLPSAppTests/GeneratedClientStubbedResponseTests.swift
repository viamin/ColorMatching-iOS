import Foundation
import OpenAPIRuntime
import ColorMatchingLPSAPI
import XCTest

final class GeneratedClientStubbedResponseTests: XCTestCase {
    func testGeneratedManifestTypeDecodesServerManifestPayload() throws {
        let manifest = try JSONDecoder().decode(
            Components.Schemas.TestSheetManifest.self,
            from: Data(StubbedResponses.manifestJSON.utf8)
        )

        XCTAssertEqual(manifest.schemaVersion, "lps-sheet-manifest/v1")
        XCTAssertEqual(manifest.sheetId, "sheet_123")
        XCTAssertEqual(manifest.captureProfile?.scoringAlgorithmVersion, "lps-distance-v1")
    }

    func testGeneratedCaptureCreatedResponseDecodesCaptureID() throws {
        let response = try JSONDecoder().decode(
            Components.Schemas.CaptureCreatedResponse.self,
            from: Data(#"{"capture_id": "101"}"#.utf8)
        )

        XCTAssertEqual(response.captureId, "101")
    }

    func testGeneratedMeasurementUploadResponseDecodesCounts() throws {
        let response = try JSONDecoder().decode(
            Components.Schemas.MeasurementUploadResponse.self,
            from: Data(StubbedResponses.measurementUploadResponseJSON.utf8)
        )

        XCTAssertEqual(response.captureId, "101")
        XCTAssertEqual(response.measurementCount, 2)
        XCTAssertEqual(response.pairScoreCount, 1)
    }

    func testGeneratedJudgmentUploadResponseDecodesCount() throws {
        let response = try JSONDecoder().decode(
            Components.Schemas.JudgmentUploadResponse.self,
            from: Data(StubbedResponses.judgmentUploadResponseJSON.utf8)
        )

        XCTAssertEqual(response.captureId, "101")
        XCTAssertEqual(response.judgmentCount, 1)
    }

    func testGeneratedRankedResultsTypeDecodesVersionedSchema() throws {
        let results = try JSONDecoder().decode(
            Components.Schemas.RankedResults.self,
            from: Data(StubbedResponses.rankedResultsJSON.utf8)
        )

        XCTAssertEqual(results.schemaVersion, "lps-ranked-results/v1")
        XCTAssertEqual(results.sheetId, "sheet_123")
    }

    func testGeneratedCaptureMetadataPreservesSnakeCaseWireKeysOnRoundtrip() throws {
        let metadataJSON = """
        {
          "device_model": "iPhone 15 Pro",
          "lens": "built_in_wide_angle",
          "exposure_duration_seconds": 0.016,
          "iso": 100,
          "focus_lens_position": 0.42,
          "white_balance_gains": {"red": 1.2, "green": 1.0, "blue": 1.4},
          "image_width": 4032,
          "image_height": 3024,
          "app_version": "0.1.0",
          "timestamp": "2026-07-25T12:00:00Z"
        }
        """
        let metadata = try JSONDecoder().decode(
            Components.Schemas.CaptureMetadata.self,
            from: Data(metadataJSON.utf8)
        )
        let encoded = try JSONEncoder().encode(metadata)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])

        XCTAssertEqual(json["device_model"] as? String, "iPhone 15 Pro")
        XCTAssertEqual(json["exposure_duration_seconds"] as? Double, 0.016)
        XCTAssertEqual(json["image_width"] as? Int, 4032)
        XCTAssertEqual(json["app_version"] as? String, "0.1.0")
    }

    func testGeneratedJudgmentUploadRequestPreservesSnakeCaseWireKeysOnRoundtrip() throws {
        let requestJSON = """
        {"judgments": [{"pair_id": "pair_1", "judgment": "near_match"}]}
        """
        let request = try JSONDecoder().decode(
            Components.Schemas.JudgmentUploadRequest.self,
            from: Data(requestJSON.utf8)
        )
        let encoded = try JSONEncoder().encode(request)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])

        let judgment = try XCTUnwrap((json["judgments"] as? [[String: Any]])?.first)
        XCTAssertEqual(judgment["pair_id"] as? String, "pair_1")
        XCTAssertEqual(judgment["judgment"] as? String, "near_match")
    }

    func testGeneratedClientFetchesManifestThroughStubbedTransport() async throws {
        let transport = StubClientTransport { request in
            XCTAssertEqual(request.path, "/api/v1/test_sheets/sheet_123/manifest")
            return (
                HTTPResponse(status: 200, headerFields: [:]),
                HTTPBody(Data(StubbedResponses.manifestJSON.utf8))
            )
        }
        let client = ColorMatchingLPSAPI.Client(
            serverURL: URL(string: "https://example.test")!,
            transport: transport
        )

        let response = try await client.manifest(path: .init(sheet_id: "sheet_123"))

        guard case .ok(let ok) = response else {
            return XCTFail("Expected a 200 response from the stubbed manifest operation, got \(response)")
        }
        let manifest = ok.body.json
        XCTAssertEqual(manifest.schemaVersion, "lps-sheet-manifest/v1")
        XCTAssertEqual(manifest.sheetId, "sheet_123")
    }
}

private struct StubClientTransport: ClientTransport {
    var handler: (HTTPRequest) throws -> (HTTPResponse, HTTPBody?)

    func send(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String
    ) async throws -> (HTTPResponse, HTTPBody?) {
        try handler(request)
    }
}
