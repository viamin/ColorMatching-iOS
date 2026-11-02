#if canImport(OpenAPIGeneratedClient)
import Foundation
import OpenAPIGeneratedClient
import OpenAPIRuntime
import XCTest

final class GeneratedClientTests: XCTestCase {
    func testManifestOperationDecodesPublishedManifestFields() async throws {
        let client = Self.stubbedClient(status: 200, json: GeneratedClientFixtures.manifest)

        let output = try await client.getTestSheetManifest(.init(path: .init(sheet_id: "sheet_1")))

        guard case let .ok(ok) = output else { return XCTFail("Expected .ok, got \(output).") }
        guard case let .json(manifest) = ok.body else { return XCTFail("Expected a JSON body.") }
        XCTAssertEqual(manifest.schema_version.rawValue, "lps-sheet-manifest/v1")
        XCTAssertEqual(manifest.sheet_id, "sheet_1")
        XCTAssertEqual(manifest.capture_profile.scoring_algorithm_version.rawValue, "lps-distance-v1")
    }

    func testManifestOperationSurfacesTypedNotFoundResponse() async throws {
        let client = Self.stubbedClient(status: 404, json: #"{"errors":{"detail":"Sheet not found"}}"#)

        let output = try await client.getTestSheetManifest(.init(path: .init(sheet_id: "missing")))

        guard case .not_found = output else { return XCTFail("Expected .not_found, got \(output).") }
    }

    func testRecentSheetsOperationDecodesNullableTitle() async throws {
        let client = Self.stubbedClient(status: 200, json: GeneratedClientFixtures.recentSheets)

        let output = try await client.getRecentTestSheets()

        guard case let .ok(ok) = output else { return XCTFail("Expected .ok, got \(output).") }
        guard case let .json(recent) = ok.body else { return XCTFail("Expected a JSON body.") }
        XCTAssertEqual(recent.sheets.first?.sheet_id, "sheet_1")
        XCTAssertEqual(recent.sheets.first?.manifest_url, "https://example.test/api/v1/test_sheets/sheet_1/manifest")
        XCTAssertNil(recent.sheets.first?.title)
    }

    func testCreateCaptureOperationDecodesCreatedResponse() async throws {
        let client = Self.stubbedClient(status: 201, json: #"{"capture_id":"41"}"#)

        let output = try await client.createCapture(.init(
            path: .init(sheet_id: "sheet_1"),
            body: .init(.json(GeneratedClientFixtures.captureRequest))
        ))

        guard case let .created(created) = output else { return XCTFail("Expected .created, got \(output).") }
        guard case let .json(response) = created.body else { return XCTFail("Expected a JSON body.") }
        XCTAssertEqual(response.capture_id, "41")
    }

    func testUploadMeasurementsOperationDecodesCounts() async throws {
        let client = Self.stubbedClient(status: 200, json: #"{"capture_id":"41","measurement_count":1,"pair_score_count":1}"#)

        let output = try await client.uploadCaptureMeasurements(.init(
            path: .init(capture_id: "41"),
            body: .init(.json(GeneratedClientFixtures.measurementUploadRequest))
        ))

        guard case let .ok(ok) = output else { return XCTFail("Expected .ok, got \(output).") }
        guard case let .json(response) = ok.body else { return XCTFail("Expected a JSON body.") }
        XCTAssertEqual(response.capture_id, "41")
        XCTAssertEqual(response.measurement_count, 1)
        XCTAssertEqual(response.pair_score_count, 1)
    }

    func testUploadJudgmentsOperationDecodesCounts() async throws {
        let client = Self.stubbedClient(status: 200, json: #"{"capture_id":"41","judgment_count":1}"#)

        let output = try await client.uploadCaptureJudgments(.init(
            path: .init(capture_id: "41"),
            body: .init(.json(GeneratedClientFixtures.judgmentUploadRequest))
        ))

        guard case let .ok(ok) = output else { return XCTFail("Expected .ok, got \(output).") }
        guard case let .json(response) = ok.body else { return XCTFail("Expected a JSON body.") }
        XCTAssertEqual(response.capture_id, "41")
        XCTAssertEqual(response.judgment_count, 1)
    }

    func testRankedResultsOperationDecodesSchemaVersion() async throws {
        let client = Self.stubbedClient(status: 200, json: GeneratedClientFixtures.rankedResults)

        let output = try await client.getRankedResults(.init(path: .init(sheet_id: "sheet_1")))

        guard case let .ok(ok) = output else { return XCTFail("Expected .ok, got \(output).") }
        guard case let .json(ranked) = ok.body else { return XCTFail("Expected a JSON body.") }
        XCTAssertEqual(ranked.schema_version.rawValue, "lps-ranked-results/v1")
        XCTAssertEqual(ranked.sheet_id, "sheet_1")
    }

    private static func stubbedClient(status: Int, json: String) -> Client {
        Client(
            serverURL: URL(string: "https://example.test")!,
            transport: GeneratedClientStubTransport(status: status, json: json)
        )
    }
}

private struct GeneratedClientStubTransport: ClientTransport {
    var status: Int
    var json: String

    func send(
        _ request: HTTPRequest,
        baseURL: URL,
        operationIDs: [String]
    ) async throws -> (HTTPResponse, Int) {
        let response = HTTPResponse(
            statusCode: status,
            headerFields: [.init(name: "content-type", value: "application/json")],
            body: Data(json.utf8)
        )
        return (response, 0)
    }
}

private enum GeneratedClientFixtures {
    static let manifest = """
    {
      "schema_version": "lps-sheet-manifest/v1",
      "sheet_id": "sheet_1",
      "capture_profile": {"scoring_algorithm_version": "lps-distance-v1"}
    }
    """

    static let recentSheets = """
    {
      "sheets": [
        {
          "sheet_id": "sheet_1",
          "manifest_url": "https://example.test/api/v1/test_sheets/sheet_1/manifest",
          "title": null
        }
      ]
    }
    """

    static let rankedResults = """
    {
      "schema_version": "lps-ranked-results/v1",
      "sheet_id": "sheet_1"
    }
    """

    static let captureRequest = Components.Schemas.CaptureRequest(
        app_version: nil,
        blur_score: nil,
        detected_marker_count: nil,
        device_model: nil,
        exposure_duration: nil,
        focus_lens_position: nil,
        image_height: nil,
        image_width: nil,
        iso: nil,
        lens: nil,
        metadata: Components.Schemas.CaptureMetadata(
            app_version: "0.1.0",
            device_model: "iPhone",
            exposure_duration_seconds: 0.016,
            focus_lens_position: 0.42,
            image_height: 3024,
            image_width: 4032,
            iso: nil,
            lens: "built_in_wide_angle",
            timestamp: "2026-07-25T12:00:00Z",
            white_balance_gains: nil
        ),
        quality: Components.Schemas.CaptureRequest.qualityPayload(
            detected_marker_count: 4,
            blur_score: 0.75,
            rejections: []
        ),
        rejection_reasons: nil,
        timestamp: nil,
        white_balance_gains: nil
    )

    static let measurementUploadRequest = Components.Schemas.MeasurementUploadRequest(
        measurements: [
            Components.Schemas.MeasurementUploadRequest.measurementsPayload(
                linear_rgb_median: .case2(.init(r: 0.12, g: 0.10, b: 0.02)),
                normalized_linear_rgb_median: .case2(.init(r: 0.15, g: 0.12, b: 0.02)),
                patch_id: "pair_1#first"
            )
        ],
        pair_scores: [
            Components.Schemas.PairScoreRequest(
                algorithm_version: "lps-distance-v1",
                distance: 0.035,
                pair_id: "pair_1",
                score: nil,
                similarity: nil
            )
        ]
    )

    static let judgmentUploadRequest = Components.Schemas.JudgmentUploadRequest(
        judgments: [
            Components.Schemas.JudgmentUploadRequest.judgmentsPayload(
                judgment: "near_match",
                pair_id: "pair_1"
            )
        ]
    )
}
#endif
