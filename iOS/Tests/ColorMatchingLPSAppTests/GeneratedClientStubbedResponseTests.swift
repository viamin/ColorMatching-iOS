import Foundation
import XCTest

// Gated on the generated client target introduced by issue #5: these tests
// activate once `ColorMatchingOpenAPI` exists. Conventions they rely on
// (module name, operationIds, normalized schemas) are pinned in
// docs/openapi-generated-client.md.
#if canImport(ColorMatchingOpenAPI) && canImport(OpenAPIRuntime)
    import ColorMatchingOpenAPI
    import OpenAPIRuntime

    final class GeneratedClientStubbedResponseTests: XCTestCase {
        private func makeClient(
            middlewares: [any ClientMiddleware] = [],
            respond: @escaping @Sendable (HTTPRequest) -> (HTTPResponse, HTTPBody?)
        ) -> (ColorMatchingOpenAPI.Client, RequestLog) {
            let log = RequestLog()
            let client = ColorMatchingOpenAPI.Client(
                serverURL: URL(string: "https://example.test")!,
                transport: StubTransport(log: log, respond: respond),
                middlewares: middlewares
            )
            return (client, log)
        }

        private static func ok(_ json: String) -> (HTTPResponse, HTTPBody?) {
            (HTTPResponse(status: .ok), HTTPBody(Data(json.utf8)))
        }

        private static func created(_ json: String) -> (HTTPResponse, HTTPBody?) {
            (HTTPResponse(status: .created), HTTPBody(Data(json.utf8)))
        }

        private func recordedBody(_ log: RequestLog) throws -> Any {
            let request = try XCTUnwrap(log.requests.first, "The generated client must send exactly one request.")
            return try JSONSerialization.jsonObject(with: XCTUnwrap(request.body, "The request must carry a JSON body."))
        }

        func testFetchSheetManifestDecodesManifestAndSendsGET() async throws {
            let (client, log) = makeClient { _ in
                Self.ok(Self.manifestJSON)
            }

            let response = try await client.fetchSheetManifest(.init(path: .init(sheetId: "sheet_1")))

            guard case .ok(let ok) = response else {
                XCTFail("Expected a 200 response, got \(response).")
                return
            }
            let manifest = try ok.body.json
            XCTAssertEqual(manifest.schemaVersion.rawValue, "lps-sheet-manifest/v1")
            XCTAssertEqual(manifest.sheetId, "sheet_1")
            XCTAssertEqual(manifest.sheetVersion, "lps-letter-grid-v1")
            XCTAssertEqual(manifest.manifestUrl, "https://example.test/api/v1/test_sheets/sheet_1/manifest")
            XCTAssertEqual(manifest.captureProfile.scoringAlgorithmVersion.rawValue, "lps-distance-v1")
            XCTAssertEqual(manifest.captureProfile.expectedIlluminant, "low_pressure_sodium")
            XCTAssertEqual(manifest.page.units, "mm")
            XCTAssertEqual(manifest.page.width, 215.9)
            XCTAssertEqual(manifest.registrationMarkers.first?.role, "top_left")
            XCTAssertEqual(manifest.printerProfile.printerMakeModel, "Research printer")
            XCTAssertEqual(manifest.printerProfile.paperType, "paper name")
            XCTAssertEqual(manifest.patches.first?.id, "pair_1#first")
            XCTAssertEqual(manifest.patches.first?.pairId, "pair_1")
            XCTAssertEqual(manifest.patches.first?.pairSide, "first")
            XCTAssertEqual(manifest.patches.first?.sourceColor, "#FF0000")
            XCTAssertEqual(manifest.patches.first?.safeInsetMm, 1.5)
            XCTAssertEqual(manifest.patches.first?.rect.width, 16)
            XCTAssertEqual(manifest.pairs.first?.id, "pair_1")
            XCTAssertEqual(manifest.pairs.first?.firstPatchId, "pair_1#first")
            XCTAssertEqual(manifest.pairs.first?.gridCol, 1)

            let request = try XCTUnwrap(log.requests.first)
            XCTAssertEqual(request.operationID, "fetchSheetManifest")
            XCTAssertEqual(request.method, "GET")
            XCTAssertEqual(request.path, "/api/v1/test_sheets/sheet_1/manifest")
            XCTAssertNotNil(request.createdAt)
        }

        func testListRecentSheetsDecodesNullableTitle() async throws {
            let (client, log) = makeClient { _ in
                Self.ok(
                    #"""
                    {"sheets": [
                      {"sheet_id": "sheet_1", "manifest_url": "https://example.test/api/v1/test_sheets/sheet_1/manifest", "title": null},
                      {"sheet_id": "sheet_2", "manifest_url": "https://example.test/api/v1/test_sheets/sheet_2/manifest", "title": "July sheet"}
                    ]}
                    """#
                )
            }

            let response = try await client.listRecentSheets()

            guard case .ok(let ok) = response else {
                XCTFail("Expected a 200 response, got \(response).")
                return
            }
            let sheets = try ok.body.json.sheets
            XCTAssertEqual(sheets.count, 2)
            XCTAssertEqual(sheets.first?.sheetId, "sheet_1")
            XCTAssertEqual(sheets.first?.title, nil)
            XCTAssertEqual(sheets.last?.title, "July sheet")

            let request = try XCTUnwrap(log.requests.first)
            XCTAssertEqual(request.operationID, "listRecentSheets")
            XCTAssertEqual(request.method, "GET")
            XCTAssertEqual(request.path, "/api/v1/test_sheets/recent")
        }

        func testCreateCapturePostsNestedMetadataAndQualityAndDecodes201() async throws {
            let (client, log) = makeClient { _ in
                Self.created(#"{"capture_id": "cap_1"}"#)
            }

            let metadata = Components.Schemas.CaptureMetadata(
                deviceModel: "iPhone",
                lens: "wide",
                exposureDurationSeconds: 0.01,
                iso: 100,
                focusLensPosition: 0.4,
                whiteBalanceGains: .init(red: 1.1, green: 1.0, blue: 1.2),
                imageWidth: 4032,
                imageHeight: 3024,
                appVersion: "0.1.0",
                timestamp: Date(timeIntervalSince1970: 1_784_980_800)
            )
            let quality = Components.Schemas.CaptureRequest.QualityPayload(
                detectedMarkerCount: 4,
                blurScore: 0.75,
                rejections: []
            )

            let response = try await client.createCapture(
                .init(
                    path: .init(sheetId: "sheet_1"),
                    body: .json(Components.Schemas.CaptureRequest(metadata: metadata, quality: quality))
                )
            )

            guard case .created(let createdResponse) = response else {
                XCTFail("Expected a 201 response, got \(response).")
                return
            }
            XCTAssertEqual(try createdResponse.body.json.captureId, "cap_1")

            let request = try XCTUnwrap(log.requests.first)
            XCTAssertEqual(request.operationID, "createCapture")
            XCTAssertEqual(request.method, "POST")
            XCTAssertEqual(request.path, "/api/v1/test_sheets/sheet_1/captures")
            XCTAssertTrue(
                request.contentType?.hasPrefix("application/json") == true,
                "The generated client must send application/json, got \(request.contentType ?? "none")."
            )

            let json = try XCTUnwrap(recordedBody(log) as? [String: Any])
            let metadataPayload = try XCTUnwrap(json["metadata"] as? [String: Any])
            XCTAssertEqual(metadataPayload["device_model"] as? String, "iPhone")
            XCTAssertEqual(metadataPayload["iso"] as? Int, 100)
            XCTAssertEqual(metadataPayload["image_width"] as? Int, 4032)
            XCTAssertNotNil(metadataPayload["timestamp"])
            let gains = try XCTUnwrap(metadataPayload["white_balance_gains"] as? [String: Any])
            XCTAssertEqual(gains["red"] as? Double, 1.1)
            let qualityPayload = try XCTUnwrap(json["quality"] as? [String: Any])
            XCTAssertEqual(qualityPayload["detected_marker_count"] as? Int, 4)
            XCTAssertEqual(qualityPayload["blur_score"] as? Double, 0.75)
            XCTAssertEqual(qualityPayload["rejections"] as? [String], [])
        }

        func testUploadMeasurementsPostsSnakeCasePayloadAndDecodesCounts() async throws {
            let (client, log) = makeClient { _ in
                Self.ok(#"{"capture_id": "cap_1", "measurement_count": 1, "pair_score_count": 1}"#)
            }

            let rgb = Components.Schemas.RgbPayload(value2: .init(r: 0.12, g: 0.1, b: 0.02))
            let stats = Components.Schemas.MeasurementUploadRequest.MeasurementsPayload.StatsPayload(
                sampleCount: 900,
                clippingFraction: 0,
                mean: rgb,
                standardDeviation: rgb
            )
            let measurement = Components.Schemas.MeasurementUploadRequest.MeasurementsPayload(
                patchId: "pair_1#first",
                linearRgbMedian: rgb,
                normalizedLinearRgbMedian: rgb,
                stats: stats
            )
            let upload = Components.Schemas.MeasurementUploadRequest(
                scoringAlgorithmVersion: "lps-distance-v1",
                measurements: [measurement],
                pairScores: [
                    Components.Schemas.PairScoreRequest(
                        pairId: "pair_1",
                        algorithmVersion: "lps-distance-v1",
                        score: nil,
                        similarity: 0.965,
                        distance: 0.035
                    )
                ]
            )

            let response = try await client.uploadMeasurements(
                .init(path: .init(captureId: "cap_1"), body: .json(upload))
            )

            guard case .ok(let ok) = response else {
                XCTFail("Expected a 200 response, got \(response).")
                return
            }
            let body = try ok.body.json
            XCTAssertEqual(body.captureId, "cap_1")
            XCTAssertEqual(body.measurementCount, 1)
            XCTAssertEqual(body.pairScoreCount, 1)

            let request = try XCTUnwrap(log.requests.first)
            XCTAssertEqual(request.operationID, "uploadMeasurements")
            XCTAssertEqual(request.method, "POST")
            XCTAssertEqual(request.path, "/api/v1/captures/cap_1/measurements")

            let json = try XCTUnwrap(recordedBody(log) as? [String: Any])
            XCTAssertEqual(json["scoring_algorithm_version"] as? String, "lps-distance-v1")
            let measurements = try XCTUnwrap(json["measurements"] as? [[String: Any]])
            let measurementPayload = try XCTUnwrap(measurements.first)
            XCTAssertEqual(measurementPayload["patch_id"] as? String, "pair_1#first")
            let median = try XCTUnwrap(measurementPayload["linear_rgb_median"] as? [String: Any])
            XCTAssertEqual(median["r"] as? Double, 0.12)
            XCTAssertEqual(median["b"] as? Double, 0.02)
            let statsPayload = try XCTUnwrap(measurementPayload["stats"] as? [String: Any])
            XCTAssertEqual(statsPayload["sample_count"] as? Int, 900)
            let pairScores = try XCTUnwrap(json["pair_scores"] as? [[String: Any]])
            XCTAssertEqual(pairScores.first?["pair_id"] as? String, "pair_1")
            XCTAssertEqual(pairScores.first?["distance"] as? Double, 0.035)
        }

        func testUploadJudgmentsPostsJudgmentsAndDecodesCount() async throws {
            let (client, log) = makeClient { _ in
                Self.ok(#"{"capture_id": "cap_1", "judgment_count": 1}"#)
            }

            let response = try await client.uploadJudgments(
                .init(
                    path: .init(captureId: "cap_1"),
                    body: .json(
                        .init(judgments: [.init(pairId: "pair_1", judgment: "near_match")])
                    )
                )
            )

            guard case .ok(let ok) = response else {
                XCTFail("Expected a 200 response, got \(response).")
                return
            }
            XCTAssertEqual(try ok.body.json.captureId, "cap_1")
            XCTAssertEqual(try ok.body.json.judgmentCount, 1)

            let request = try XCTUnwrap(log.requests.first)
            XCTAssertEqual(request.operationID, "uploadJudgments")
            XCTAssertEqual(request.method, "POST")
            XCTAssertEqual(request.path, "/api/v1/captures/cap_1/judgments")

            let json = try XCTUnwrap(recordedBody(log) as? [String: Any])
            let judgments = try XCTUnwrap(json["judgments"] as? [[String: Any]])
            XCTAssertEqual(judgments.first?["pair_id"] as? String, "pair_1")
            XCTAssertEqual(judgments.first?["judgment"] as? String, "near_match")
        }

        func testFetchRankedResultsDecodesResultRows() async throws {
            let (client, log) = makeClient { _ in
                Self.ok(Self.rankedResultsJSON)
            }

            let response = try await client.fetchRankedResults(.init(path: .init(sheetId: "sheet_1")))

            guard case .ok(let ok) = response else {
                XCTFail("Expected a 200 response, got \(response).")
                return
            }
            let ranked = try ok.body.json
            XCTAssertEqual(ranked.schemaVersion.rawValue, "lps-ranked-results/v1")
            XCTAssertEqual(ranked.sheetId, "sheet_1")
            XCTAssertEqual(ranked.captureCount, 2)
            XCTAssertEqual(ranked.scoringAlgorithmVersions, ["lps-distance-v1"])
            XCTAssertEqual(ranked.results.first?.rank, 1)
            XCTAssertEqual(ranked.results.first?.pairId, "pair_1")
            XCTAssertEqual(ranked.results.first?.sourceColors.colorAHex, "#FF0000")
            XCTAssertEqual(ranked.results.first?.sourceColors.colorBHex, "#00FF00")
            XCTAssertEqual(ranked.results.first?.score.average ?? 0, 0.036, accuracy: 0.0001)
            XCTAssertEqual(ranked.results.first?.currentJudgment, "near_match")
            XCTAssertEqual(ranked.results.first?.observationCount, 1)

            let request = try XCTUnwrap(log.requests.first)
            XCTAssertEqual(request.operationID, "fetchRankedResults")
            XCTAssertEqual(request.method, "GET")
            XCTAssertEqual(request.path, "/api/v1/test_sheets/sheet_1/ranked_results")
        }

        func testBearerMiddlewareAppliesAuthorizationHeader() async throws {
            let (client, log) = makeClient(middlewares: [BearerAuthMiddleware(token: "token-123")]) { _ in
                Self.ok(Self.manifestJSON)
            }

            let response = try await client.fetchSheetManifest(.init(path: .init(sheetId: "sheet_1")))

            guard case .ok = response else {
                XCTFail("Expected a 200 response, got \(response).")
                return
            }
            XCTAssertEqual(log.requests.first?.authorization, "Bearer token-123")
        }

        private static let manifestJSON = #"""
        {
          "schema_version": "lps-sheet-manifest/v1",
          "sheet_id": "sheet_1",
          "sheet_version": "lps-letter-grid-v1",
          "manifest_url": "https://example.test/api/v1/test_sheets/sheet_1/manifest",
          "created_at": "2026-07-25T12:00:00Z",
          "page": {"units": "mm", "width": 215.9, "height": 279.4},
          "registration_markers": [
            {"role": "top_left", "shape": "solid_square", "rect": {"x": 12, "y": 12, "width": 8, "height": 8}}
          ],
          "printer_profile": {
            "printer_make_model": "Research printer",
            "paper_type": "paper name",
            "ink_type": "ink set",
            "icc_profile": null,
            "print_settings": null,
            "driver_name": null,
            "driver_version": null,
            "calibration_date": null,
            "calibration_version": null,
            "notes": null
          },
          "capture_profile": {
            "expected_illuminant": "low_pressure_sodium",
            "preferred_camera": "built_in_wide_angle_rear",
            "scoring_algorithm_version": "lps-distance-v1"
          },
          "patches": [
            {
              "id": "pair_1#first",
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
              "first_patch_id": "pair_1#first",
              "second_patch_id": "pair_1#second",
              "source_colors": ["#FF0000", "#00FF00"],
              "grid_row": 0,
              "grid_col": 1
            }
          ]
        }
        """#

        private static let rankedResultsJSON = #"""
        {
          "schema_version": "lps-ranked-results/v1",
          "sheet_id": "sheet_1",
          "printer_profile": {
            "printer_make_model": "Research printer",
            "paper_type": "paper name",
            "ink_type": "ink set",
            "icc_profile": null,
            "print_settings": null,
            "driver_name": null,
            "driver_version": null,
            "calibration_date": null,
            "calibration_version": null,
            "notes": null
          },
          "capture_count": 2,
          "latest_capture_at": "2026-07-26T10:00:00Z",
          "earliest_capture_at": "2026-07-25T12:00:00Z",
          "scoring_algorithm_versions": ["lps-distance-v1"],
          "results": [
            {
              "rank": 1,
              "pair_id": "pair_1",
              "scoring_algorithm_version": "lps-distance-v1",
              "row": 0,
              "col": 1,
              "source_colors": {"color_a_hex": "#FF0000", "color_b_hex": "#00FF00"},
              "score": {
                "average": 0.036,
                "latest": 0.035,
                "minimum": 0.035,
                "maximum": 0.037,
                "capture_count": 2,
                "sample_count": 1800,
                "algorithm_versions": ["lps-distance-v1"]
              },
              "current_judgment": "near_match",
              "current_judgment_observed_at": "2026-07-26T11:00:00Z",
              "observation_count": 1,
              "latest_observation": {"judgment": "near_match", "observed_at": "2026-07-26T11:00:00Z"},
              "capture_count": 2,
              "latest_capture_at": "2026-07-26T10:00:00Z",
              "earliest_capture_at": "2026-07-25T12:00:00Z"
            }
          ]
        }
        """#
    }

    private struct RecordedRequest {
        var method: String
        var path: String
        var operationID: String
        var authorization: String?
        var contentType: String?
        var body: Data?
        var createdAt: Date?
    }

    private final class RequestLog: @unchecked Sendable {
        private let lock = NSLock()
        private var storage: [RecordedRequest] = []

        var requests: [RecordedRequest] {
            lock.lock()
            defer { lock.unlock() }
            return storage
        }

        func append(_ request: RecordedRequest) {
            lock.lock()
            defer { lock.unlock() }
            storage.append(request)
        }
    }

    private struct StubTransport: ClientTransport {
        let log: RequestLog
        let respond: @Sendable (HTTPRequest) -> (HTTPResponse, HTTPBody?)

        func send(
            _ request: HTTPRequest,
            body: HTTPBody?,
            baseURL: URL,
            operationID: String
        ) async throws -> (HTTPResponse, HTTPBody?) {
            var bodyData: Data?
            if let body {
                bodyData = try await Data(collecting: body, upTo: 1_048_576)
            }
            log.append(
                RecordedRequest(
                    method: request.method.rawValue,
                    path: request.path ?? "",
                    operationID: operationID,
                    authorization: request.headerFields[.authorization],
                    contentType: request.headerFields[.contentType],
                    body: bodyData,
                    createdAt: Date()
                )
            )
            return respond(request)
        }
    }

    private struct BearerAuthMiddleware: ClientMiddleware {
        var token: String

        func intercept(
            _ request: HTTPRequest,
            body: HTTPBody?,
            baseURL: URL,
            operationID: String,
            next: @Sendable (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
        ) async throws -> (HTTPResponse, HTTPBody?) {
            var request = request
            request.headerFields[.authorization] = "Bearer \(token)"
            return try await next(request, body, baseURL)
        }
    }
#endif
