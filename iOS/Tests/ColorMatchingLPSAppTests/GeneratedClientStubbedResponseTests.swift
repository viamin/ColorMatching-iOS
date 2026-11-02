import Foundation
import XCTest

#if canImport(OpenAPIGeneratedClient) && canImport(OpenAPIRuntime)
import OpenAPIGeneratedClient
import OpenAPIRuntime

/// Exercises the swift-openapi-generator client generated from the vendored
/// spec (`iOS/Sources/OpenAPIGeneratedClient/openapi.json`) against locally
/// stubbed HTTP responses. No live server is contacted.
///
/// Method and type names follow the generator's `SafeNameGenerator` rules for
/// the upstream operationIds (`Module.action` with dots) — see the naming table
/// in `docs/openapi-client-generation.md`.
final class GeneratedClientStubbedResponseTests: XCTestCase {
    private struct RecordedRequest {
        var operationID: String
        var method: String
        var path: String
        var contentType: String?
        var body: Data?
    }

    /// Records outgoing requests and replays queued canned responses.
    private actor StubTransport: ClientTransport {
        private var recorded: [RecordedRequest] = []
        private var queued: [(HTTPResponse, HTTPBody?)] = []

        func enqueue(_ response: HTTPResponse, body: HTTPBody? = nil) {
            queued.append((response, body))
        }

        func recordedRequests() -> [RecordedRequest] {
            recorded
        }

        func send(
            _ request: HTTPRequest,
            body: HTTPBody?,
            baseURL: URL,
            operationID: String
        ) async throws -> (HTTPResponse, HTTPBody?) {
            let bodyData: Data
            if let body {
                bodyData = try await Data(collecting: body, upTo: 1 << 20)
            } else {
                bodyData = Data()
            }
            recorded.append(
                RecordedRequest(
                    operationID: operationID,
                    method: request.method.rawValue,
                    path: request.path,
                    contentType: request.headerFields[.contentType],
                    body: bodyData
                )
            )
            guard !queued.isEmpty else {
                throw StubError.noQueuedResponse
            }
            return queued.removeFirst()
        }
    }

    private enum StubError: Error {
        case noQueuedResponse
    }

    private func makeClient(_ transport: StubTransport) -> OpenAPIGeneratedClient.Client {
        Client(serverURL: URL(string: "https://example.test")!, transport: transport)
    }

    private func recordedBodyJSON(_ request: RecordedRequest?) throws -> [String: Any] {
        let data = try XCTUnwrap(request?.body)
        let object = try? JSONSerialization.jsonObject(with: data)
        return try XCTUnwrap(object as? [String: Any])
    }

    // MARK: Test-sheet manifest

    func testFetchManifestBuildsGetRequestAndDecodesVersionedManifest() async throws {
        let transport = StubTransport()
        await transport.enqueue(
            HTTPResponse(status: .ok, headerFields: [.contentType: "application/json"]),
            body: HTTPBody(
                #"""
                {
                  "schema_version": "lps-sheet-manifest/v1",
                  "sheet_id": "sheet_1",
                  "capture_profile": {"scoring_algorithm_version": "lps-distance-v1"}
                }
                """#
            )
        )
        let client = makeClient(transport)

        let response = try await client.colorMatchingWeb_TestSheetController_manifest(
            .init(path: .init(sheetId: "sheet_1"))
        )

        guard case .ok(let ok) = response else {
            return XCTFail("Expected 200 for manifest, got \(response)")
        }
        let manifest = try ok.body.json
        XCTAssertEqual(manifest.schemaVersion, .lpsSheetManifestV1)
        XCTAssertEqual(manifest.sheetId, "sheet_1")
        XCTAssertEqual(manifest.captureProfile.scoringAlgorithmVersion, .lpsDistanceV1)

        let recorded = await transport.recordedRequests()
        XCTAssertEqual(recorded.count, 1)
        XCTAssertEqual(recorded.first?.operationID, "ColorMatchingWeb.TestSheetController.manifest")
        XCTAssertEqual(recorded.first?.method, "GET")
        XCTAssertEqual(recorded.first?.path, "/api/v1/test_sheets/sheet_1/manifest")
    }

    func testFetchManifestSurfacesNotFoundResponse() async throws {
        let transport = StubTransport()
        await transport.enqueue(
            HTTPResponse(status: .notFound, headerFields: [.contentType: "application/json"]),
            body: HTTPBody(#"{"errors": {"detail": "Sheet not found"}}"#)
        )
        let client = makeClient(transport)

        let response = try await client.colorMatchingWeb_TestSheetController_manifest(
            .init(path: .init(sheetId: "missing"))
        )

        guard case .notFound = response else {
            return XCTFail("Expected 404 for missing sheet, got \(response)")
        }
    }

    // MARK: Recent sheets

    func testFetchRecentSheetsDecodesTitlesIncludingNull() async throws {
        let transport = StubTransport()
        await transport.enqueue(
            HTTPResponse(status: .ok, headerFields: [.contentType: "application/json"]),
            body: HTTPBody(
                #"""
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
            )
        )
        let client = makeClient(transport)

        let response = try await client.colorMatchingWeb_TestSheetController_recent(.init())

        guard case .ok(let ok) = response else {
            return XCTFail("Expected 200 for recent sheets, got \(response)")
        }
        let sheets = try ok.body.json.sheets
        XCTAssertEqual(sheets.count, 2)
        XCTAssertEqual(sheets.first?.sheetId, "sheet_1")
        XCTAssertEqual(sheets.first?.title, "July LPS comparison sheet")
        XCTAssertEqual(sheets.last?.title, nil, "title must decode as nil when the server sends null")

        let recorded = await transport.recordedRequests()
        XCTAssertEqual(recorded.first?.method, "GET")
        XCTAssertEqual(recorded.first?.path, "/api/v1/test_sheets/recent")
    }

    // MARK: Capture session creation

    func testCreateCaptureEncodesNestedMetadataAndQualityAndDecodesCaptureID() async throws {
        let transport = StubTransport()
        await transport.enqueue(
            HTTPResponse(status: .created, headerFields: [.contentType: "application/json"]),
            body: HTTPBody(#"{"capture_id": "cap_1"}"#)
        )
        let client = makeClient(transport)

        let response = try await client.colorMatchingWeb_CaptureController_create(
            .init(
                path: .init(sheetId: "sheet_1"),
                body: .json(
                    .init(
                        metadata: .init(
                            deviceModel: "iPhone",
                            lens: "built_in_wide_angle",
                            imageWidth: 4032,
                            imageHeight: 3024,
                            appVersion: "0.1.0",
                            timestamp: Date(timeIntervalSince1970: 0)
                        ),
                        quality: .init(detectedMarkerCount: 4, blurScore: 0.75, rejections: [])
                    )
                )
            )
        )

        guard case .created(let created) = response else {
            return XCTFail("Expected 201 for capture creation, got \(response)")
        }
        XCTAssertEqual(try created.body.json.captureId, "cap_1")

        let recorded = await transport.recordedRequests()
        XCTAssertEqual(recorded.first?.operationID, "ColorMatchingWeb.CaptureController.create")
        XCTAssertEqual(recorded.first?.method, "POST")
        XCTAssertEqual(recorded.first?.path, "/api/v1/test_sheets/sheet_1/captures")
        XCTAssertEqual(recorded.first?.contentType, "application/json")

        let json = try recordedBodyJSON(recorded.first)
        let metadata = try XCTUnwrap(json["metadata"] as? [String: Any])
        XCTAssertEqual(metadata["device_model"] as? String, "iPhone")
        XCTAssertEqual(metadata["image_width"] as? Int, 4032)
        let quality = try XCTUnwrap(json["quality"] as? [String: Any])
        XCTAssertEqual(quality["detected_marker_count"] as? Int, 4)
        XCTAssertEqual(quality["rejections"] as? [String], [])
    }

    // MARK: Measurement upload

    func testUploadMeasurementsEncodesRgbObjectsAndDecodesCounts() async throws {
        let transport = StubTransport()
        await transport.enqueue(
            HTTPResponse(status: .ok, headerFields: [.contentType: "application/json"]),
            body: HTTPBody(#"{"capture_id": "cap_1", "measurement_count": 1, "pair_score_count": 1}"#)
        )
        let client = makeClient(transport)

        let response = try await client.colorMatchingWeb_CaptureController_upload_measurements(
            .init(
                path: .init(captureId: "cap_1"),
                body: .json(
                    .init(
                        measurements: [
                            .init(
                                patchId: "patch_1",
                                linearRgbMedian: .case2(.init(r: 0.12, g: 0.10, b: 0.02)),
                                normalizedLinearRgbMedian: .case2(.init(r: 0.15, g: 0.12, b: 0.02))
                            )
                        ],
                        pairScores: [
                            .init(pairId: "pair_1", algorithmVersion: "lps-distance-v1", distance: 0.035)
                        ]
                    )
                )
            )
        )

        guard case .ok(let ok) = response else {
            return XCTFail("Expected 200 for measurement upload, got \(response)")
        }
        let body = try ok.body.json
        XCTAssertEqual(body.captureId, "cap_1")
        XCTAssertEqual(body.measurementCount, 1)
        XCTAssertEqual(body.pairScoreCount, 1)

        let recorded = await transport.recordedRequests()
        XCTAssertEqual(recorded.first?.operationID, "ColorMatchingWeb.CaptureController.upload_measurements")
        XCTAssertEqual(recorded.first?.method, "POST")
        XCTAssertEqual(recorded.first?.path, "/api/v1/captures/cap_1/measurements")

        let json = try recordedBodyJSON(recorded.first)
        let measurement = try XCTUnwrap((json["measurements"] as? [[String: Any]])?.first)
        XCTAssertEqual(measurement["patch_id"] as? String, "patch_1")
        XCTAssertEqual((measurement["linear_rgb_median"] as? [String: Any])?["r"] as? Double, 0.12)
        XCTAssertEqual((measurement["linear_rgb_median"] as? [String: Any])?["b"] as? Double, 0.02)
        let pairScore = try XCTUnwrap((json["pair_scores"] as? [[String: Any]])?.first)
        XCTAssertEqual(pairScore["pair_id"] as? String, "pair_1")
        XCTAssertEqual(pairScore["distance"] as? Double, 0.035)
    }

    // MARK: Judgment upload

    func testUploadJudgmentsEncodesPayloadAndDecodesCount() async throws {
        let transport = StubTransport()
        await transport.enqueue(
            HTTPResponse(status: .ok, headerFields: [.contentType: "application/json"]),
            body: HTTPBody(#"{"capture_id": "cap_1", "judgment_count": 1}"#)
        )
        let client = makeClient(transport)

        let response = try await client.colorMatchingWeb_CaptureController_upload_judgments(
            .init(
                path: .init(captureId: "cap_1"),
                body: .json(
                    .init(judgments: [.init(pairId: "pair_1", judgment: "near_match")])
                )
            )
        )

        guard case .ok(let ok) = response else {
            return XCTFail("Expected 200 for judgment upload, got \(response)")
        }
        XCTAssertEqual(try ok.body.json.judgmentCount, 1)

        let recorded = await transport.recordedRequests()
        XCTAssertEqual(recorded.first?.method, "POST")
        XCTAssertEqual(recorded.first?.path, "/api/v1/captures/cap_1/judgments")

        let json = try recordedBodyJSON(recorded.first)
        let judgment = try XCTUnwrap((json["judgments"] as? [[String: Any]])?.first)
        XCTAssertEqual(judgment["pair_id"] as? String, "pair_1")
        XCTAssertEqual(judgment["judgment"] as? String, "near_match")
    }

    // MARK: Ranked results

    func testFetchRankedResultsBuildsGetRequestAndDecodesVersionedPayload() async throws {
        let transport = StubTransport()
        await transport.enqueue(
            HTTPResponse(status: .ok, headerFields: [.contentType: "application/json"]),
            body: HTTPBody(
                #"""
                {"schema_version": "lps-ranked-results/v1", "sheet_id": "sheet_1"}
                """#
            )
        )
        let client = makeClient(transport)

        let response = try await client.colorMatchingWeb_TestSheetController_ranked_results(
            .init(path: .init(sheetId: "sheet_1"))
        )

        guard case .ok(let ok) = response else {
            return XCTFail("Expected 200 for ranked results, got \(response)")
        }
        let ranked = try ok.body.json
        XCTAssertEqual(ranked.schemaVersion, .lpsRankedResultsV1)
        XCTAssertEqual(ranked.sheetId, "sheet_1")

        let recorded = await transport.recordedRequests()
        XCTAssertEqual(recorded.first?.operationID, "ColorMatchingWeb.TestSheetController.ranked_results")
        XCTAssertEqual(recorded.first?.method, "GET")
        XCTAssertEqual(recorded.first?.path, "/api/v1/test_sheets/sheet_1/ranked_results")
    }
}

#else

/// Red-phase marker: the generated client does not exist in the package yet.
///
/// To turn this green, vendor the spec at
/// `iOS/Sources/OpenAPIGeneratedClient/openapi.json`, add the
/// `OpenAPIGeneratedClient` target (swift-openapi-generator plugin +
/// swift-openapi-runtime), and declare it as a dependency of
/// `ColorMatchingLPSAppTests` — see `docs/openapi-client-generation.md`.
final class GeneratedClientAvailabilityTests: XCTestCase {
    func testGeneratedOpenAPIClientModuleIsWiredIntoPackage() {
        XCTFail(
            """
            OpenAPIGeneratedClient/OpenAPIRuntime are not importable from the test \
            target: the generated OpenAPI client has not been wired into the package \
            yet (docs/openapi-client-generation.md).
            """
        )
    }
}

#endif
