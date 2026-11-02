import Foundation
import OpenAPIRuntime
import ColorMatchingAPI
import XCTest

final class GeneratedClientTests: XCTestCase {
    private var transport: RecordingTransport!

    override func tearDown() {
        transport = nil
        super.tearDown()
    }

    func testGetTestSheetManifestDecodesPublishedManifest() async throws {
        let client = makeClient(
            status: 200,
            json: #"{"schema_version":"lps-sheet-manifest/v1","sheet_id":"sheet_123","capture_profile":{"scoring_algorithm_version":"lps-distance-v1"}}"#
        )

        let response = try await client.getTestSheetManifest(path: .init(sheetId: "sheet_123"))

        XCTAssertEqual(transport.requestMethod?.uppercased(), "GET")
        XCTAssertEqual(transport.requestPath, "/api/v1/test_sheets/sheet_123/manifest")
        XCTAssertEqual(transport.requestHeaders[.accept], "application/json")
        let manifest = try response.ok.body.json
        XCTAssertEqual(manifest.schemaVersion, .lpsSheetManifestV1)
        XCTAssertEqual(manifest.sheetId, "sheet_123")
        XCTAssertEqual(manifest.captureProfile.scoringAlgorithmVersion, .lpsDistanceV1)
    }

    func testGetTestSheetManifestSurfacesNotFoundResponse() async throws {
        let client = makeClient(status: 404, json: #"{"errors":{"detail":"Sheet not found"}}"#)

        let response = try await client.getTestSheetManifest(path: .init(sheetId: "missing"))

        guard case .notFound = response else {
            XCTFail("Expected a notFound response, got \(response)")
            return
        }
    }

    func testListRecentTestSheetsDecodesNullableTitles() async throws {
        let client = makeClient(
            status: 200,
            json: #"""
            {
              "sheets": [
                {"sheet_id": "sheet_123", "manifest_url": "https://api.example.test/api/v1/test_sheets/sheet_123/manifest", "title": null},
                {"sheet_id": "sheet_456", "manifest_url": "https://api.example.test/api/v1/test_sheets/sheet_456/manifest", "title": "July LPS comparison sheet"}
              ]
            }
            """#
        )

        let response = try await client.listRecentTestSheets()

        XCTAssertEqual(transport.requestMethod?.uppercased(), "GET")
        XCTAssertEqual(transport.requestPath, "/api/v1/test_sheets/recent")
        let payload = try response.ok.body.json
        XCTAssertEqual(payload.sheets.count, 2)
        let first = try XCTUnwrap(payload.sheets.first)
        XCTAssertEqual(first.sheetId, "sheet_123")
        XCTAssertEqual(first.manifestUrl, "https://api.example.test/api/v1/test_sheets/sheet_123/manifest")
        XCTAssertNil(first.title)
        XCTAssertEqual(payload.sheets.last?.title, "July LPS comparison sheet")
    }

    func testCreateCaptureEncodesNestedMetadataAndQuality() async throws {
        let client = makeClient(status: 201, json: #"{"capture_id":"capture_123"}"#)

        let response = try await client.createCapture(
            path: .init(sheetId: "sheet_1"),
            body: .json(
                .init(
                    metadata: .init(
                        deviceModel: "iPhone",
                        lens: "built_in_wide_angle",
                        exposureDurationSeconds: 0.01,
                        iso: 100,
                        focusLensPosition: 0.4,
                        whiteBalanceGains: .init(red: 1.1, green: 1.0, blue: 1.2),
                        imageWidth: 4032,
                        imageHeight: 3024,
                        appVersion: "0.1.0",
                        timestamp: Date(timeIntervalSince1970: 0)
                    ),
                    quality: .init(detectedMarkerCount: 4, blurScore: 0.75, rejections: [])
                )
            )
        )

        XCTAssertEqual(transport.requestMethod?.uppercased(), "POST")
        XCTAssertEqual(transport.requestPath, "/api/v1/test_sheets/sheet_1/captures")
        XCTAssertEqual(transport.requestHeaders[.contentType], "application/json")
        let json = try transport.jsonBody()
        let metadata = try XCTUnwrap(json["metadata"] as? [String: Any])
        XCTAssertEqual(metadata["device_model"] as? String, "iPhone")
        XCTAssertEqual(metadata["lens"] as? String, "built_in_wide_angle")
        XCTAssertEqual(metadata["iso"] as? Int, 100)
        XCTAssertEqual(metadata["image_width"] as? Int, 4032)
        XCTAssertEqual(metadata["app_version"] as? String, "0.1.0")
        XCTAssertNotNil(metadata["timestamp"] as? String)
        let gains = try XCTUnwrap(metadata["white_balance_gains"] as? [String: Any])
        XCTAssertEqual(Set(gains.keys), ["red", "green", "blue"])
        let quality = try XCTUnwrap(json["quality"] as? [String: Any])
        XCTAssertEqual(quality["detected_marker_count"] as? Int, 4)
        XCTAssertEqual(quality["rejections"] as? [String], [])
        let created = try response.created.body.json
        XCTAssertEqual(created.captureId, "capture_123")
    }

    func testUploadMeasurementsEncodesRgbPayloadsAndPairScores() async throws {
        let client = makeClient(
            status: 200,
            json: #"{"capture_id":"cap_1","measurement_count":1,"pair_score_count":1}"#
        )

        let response = try await client.uploadMeasurements(
            path: .init(captureId: "cap_1"),
            body: .json(
                .init(
                    measurements: [
                        .init(
                            patchId: "patch_1",
                            linearRgbMedian: .init(case2: .init(r: 0.12, g: 0.10, b: 0.02)),
                            normalizedLinearRgbMedian: .init(case2: .init(r: 0.15, g: 0.12, b: 0.02))
                        )
                    ],
                    pairScores: [
                        .init(
                            pairId: "pair_1",
                            algorithmVersion: "lps-distance-v1",
                            similarity: 0.965,
                            distance: 0.035
                        )
                    ]
                )
            )
        )

        XCTAssertEqual(transport.requestMethod?.uppercased(), "POST")
        XCTAssertEqual(transport.requestPath, "/api/v1/captures/cap_1/measurements")
        XCTAssertEqual(transport.requestHeaders[.contentType], "application/json")
        let json = try transport.jsonBody()
        let measurements = try XCTUnwrap(json["measurements"] as? [[String: Any]])
        let measurement = try XCTUnwrap(measurements.first)
        XCTAssertEqual(measurement["patch_id"] as? String, "patch_1")
        let median = try XCTUnwrap(measurement["linear_rgb_median"] as? [String: Any])
        XCTAssertEqual(try Self.doubleValue(median["r"]), 0.12, accuracy: 0.0001)
        XCTAssertEqual(try Self.doubleValue(median["g"]), 0.10, accuracy: 0.0001)
        let normalized = try XCTUnwrap(measurement["normalized_linear_rgb_median"] as? [String: Any])
        XCTAssertEqual(try Self.doubleValue(normalized["b"]), 0.02, accuracy: 0.0001)
        let scores = try XCTUnwrap(json["pair_scores"] as? [[String: Any]])
        let score = try XCTUnwrap(scores.first)
        XCTAssertEqual(score["pair_id"] as? String, "pair_1")
        XCTAssertEqual(score["algorithm_version"] as? String, "lps-distance-v1")
        XCTAssertEqual(try Self.doubleValue(score["distance"]), 0.035, accuracy: 0.0001)
        XCTAssertEqual(try Self.doubleValue(score["similarity"]), 0.965, accuracy: 0.0001)
        let accepted = try response.ok.body.json
        XCTAssertEqual(accepted.captureId, "cap_1")
        XCTAssertEqual(accepted.measurementCount, 1)
        XCTAssertEqual(accepted.pairScoreCount, 1)
    }

    func testUploadJudgmentsEncodesPairJudgments() async throws {
        let client = makeClient(status: 200, json: #"{"capture_id":"cap_1","judgment_count":1}"#)

        let response = try await client.uploadJudgments(
            path: .init(captureId: "cap_1"),
            body: .json(.init(judgments: [.init(pairId: "pair_1", judgment: "near_match")]))
        )

        XCTAssertEqual(transport.requestMethod?.uppercased(), "POST")
        XCTAssertEqual(transport.requestPath, "/api/v1/captures/cap_1/judgments")
        XCTAssertEqual(transport.requestHeaders[.contentType], "application/json")
        let json = try transport.jsonBody()
        let judgments = try XCTUnwrap(json["judgments"] as? [[String: Any]])
        let judgment = try XCTUnwrap(judgments.first)
        XCTAssertEqual(judgment["pair_id"] as? String, "pair_1")
        XCTAssertEqual(judgment["judgment"] as? String, "near_match")
        let accepted = try response.ok.body.json
        XCTAssertEqual(accepted.captureId, "cap_1")
        XCTAssertEqual(accepted.judgmentCount, 1)
    }

    func testGetRankedResultsDecodesSchemaVersionEnvelope() async throws {
        let client = makeClient(
            status: 200,
            json: #"{"schema_version":"lps-ranked-results/v1","sheet_id":"sheet_123"}"#
        )

        let response = try await client.getRankedResults(path: .init(sheetId: "sheet_123"))

        XCTAssertEqual(transport.requestMethod?.uppercased(), "GET")
        XCTAssertEqual(transport.requestPath, "/api/v1/test_sheets/sheet_123/ranked_results")
        let results = try response.ok.body.json
        XCTAssertEqual(results.schemaVersion, .lpsRankedResultsV1)
        XCTAssertEqual(results.sheetId, "sheet_123")
    }

    private func makeClient(status: Int, json: String) -> Client {
        transport = RecordingTransport(status: status, json: json)
        return Client(
            serverURL: URL(string: "https://api.example.test")!,
            transport: transport
        )
    }

    private static func doubleValue(_ value: Any?) throws -> Double {
        try XCTUnwrap((value as? NSNumber)?.doubleValue)
    }
}

private final class RecordingTransport: ClientTransport, @unchecked Sendable {
    private let status: Int
    private let json: String

    private(set) var requestMethod: String?
    private(set) var requestPath: String?
    private(set) var requestBody: Data?
    private(set) var requestHeaders: HTTPFields = [:]

    init(status: Int, json: String) {
        self.status = status
        self.json = json
    }

    func send(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String
    ) async throws -> (HTTPResponse, HTTPBody?) {
        requestMethod = request.method.rawValue
        requestPath = request.path
        requestHeaders = request.headerFields
        var data = Data()
        if let body {
            for try await chunk in body {
                data.append(contentsOf: chunk)
            }
        }
        requestBody = data
        let response = HTTPResponse(
            status: HTTPResponse.Status(code: status),
            headerFields: [.init(name: .contentType, value: "application/json")]
        )
        return (response, HTTPBody(json))
    }
}

private extension RecordingTransport {
    func jsonBody() throws -> [String: Any] {
        let data = try XCTUnwrap(requestBody)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }
}
