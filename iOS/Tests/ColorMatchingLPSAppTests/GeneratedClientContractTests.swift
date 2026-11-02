import XCTest
import OpenAPIRuntime
import ColorMatchingAPI

final class GeneratedClientContractTests: XCTestCase {
    private static let baseURL = URL(string: "https://example.test")!

    func testGetTestSheetManifestBuildsExpectedRequestAndDecodesServerManifest() async throws {
        let transport = StubTransport()
        transport.enqueue(StubTransport.jsonResponse(statusCode: 200, payload: Fixtures.manifest))
        let client = Self.makeClient(transport)

        let output = try await client.getTestSheetManifest(.init(path: .init(sheetId: "sheet_123")))

        guard case .ok(let okPayload) = output, case .json(let manifest) = okPayload.body else {
            return XCTFail("Expected 200 JSON manifest body")
        }
        XCTAssertEqual(manifest.schemaVersion, "lps-sheet-manifest/v1")
        XCTAssertEqual(manifest.sheetVersion, "lps-letter-grid-v1")
        XCTAssertEqual(manifest.sheetId, "sheet_123")
        XCTAssertEqual(manifest.manifestUrl, "https://example.test/api/v1/test_sheets/sheet_123/manifest")
        XCTAssertEqual(manifest.createdAt, StubDates.date("2026-07-25T12:00:00Z"))
        XCTAssertEqual(manifest.page.units, "mm")
        XCTAssertEqual(manifest.page.width, 215.9, accuracy: 0.0001)
        XCTAssertEqual(manifest.registrationMarkers.first?.role, "top_left")
        let marker = try XCTUnwrap(manifest.registrationMarkers.first)
        XCTAssertEqual(marker.rect.width, 8, accuracy: 0.0001)
        XCTAssertEqual(manifest.printerProfile.printerMakeModel, "Research printer")
        XCTAssertEqual(manifest.printerProfile.paperType, "paper name")
        XCTAssertEqual(manifest.captureProfile.expectedIlluminant, "low_pressure_sodium")
        XCTAssertEqual(manifest.captureProfile.scoringAlgorithmVersion, "lps-distance-v1")

        let patch = try XCTUnwrap(manifest.patches.first)
        XCTAssertEqual(patch.id, "pair_1#first")
        XCTAssertEqual(patch.role, "pair_color")
        XCTAssertEqual(patch.pairId, "pair_1")
        XCTAssertEqual(patch.pairSide, "first")
        XCTAssertNil(patch.referenceRole)
        XCTAssertEqual(patch.sourceColor, "#FF0000")
        XCTAssertEqual(patch.safeInsetMm, 1.5, accuracy: 0.0001)
        XCTAssertEqual(patch.rect.x, 16, accuracy: 0.0001)

        let pair = try XCTUnwrap(manifest.pairs.first)
        XCTAssertEqual(pair.id, "pair_1")
        XCTAssertEqual(pair.firstPatchId, "pair_1#first")
        XCTAssertEqual(pair.secondPatchId, "pair_1#second")
        XCTAssertEqual(pair.sourceColors, ["#FF0000", "#00FF00"])
        XCTAssertEqual(pair.gridRow, 0)
        XCTAssertEqual(pair.gridCol, 1)

        let recorded = try XCTUnwrap(transport.recordedRequests.first)
        XCTAssertEqual(recorded.operationID, "getTestSheetManifest")
        XCTAssertEqual(recorded.method, "GET")
        XCTAssertEqual(recorded.path, "/api/v1/test_sheets/sheet_123/manifest")
    }

    func testListRecentTestSheetsDecodesNullableTitle() async throws {
        let transport = StubTransport()
        transport.enqueue(StubTransport.jsonResponse(statusCode: 200, payload: Fixtures.recentSheets))
        let client = Self.makeClient(transport)

        let output = try await client.listRecentTestSheets(.init())

        guard case .ok(let okPayload) = output, case .json(let body) = okPayload.body else {
            return XCTFail("Expected 200 JSON recent-sheets body")
        }
        XCTAssertEqual(body.sheets.count, 1)
        let sheet = try XCTUnwrap(body.sheets.first)
        XCTAssertEqual(sheet.sheetId, "sheet_123")
        XCTAssertEqual(sheet.manifestUrl, "https://example.test/api/v1/test_sheets/sheet_123/manifest")
        XCTAssertNil(sheet.title)

        let recorded = try XCTUnwrap(transport.recordedRequests.first)
        XCTAssertEqual(recorded.operationID, "listRecentTestSheets")
        XCTAssertEqual(recorded.method, "GET")
        XCTAssertEqual(recorded.path, "/api/v1/test_sheets/recent")
    }

    func testCreateCaptureEncodesNestedMetadataAndQualityAndDecodesCreatedCapture() async throws {
        let transport = StubTransport()
        transport.enqueue(StubTransport.jsonResponse(statusCode: 201, payload: Fixtures.captureCreated))
        let client = Self.makeClient(transport)

        let metadata = Components.Schemas.CaptureMetadata(
            deviceModel: "iPhone 15",
            lens: "built_in_wide_angle",
            exposureDurationSeconds: 0.016,
            iso: 100,
            focusLensPosition: 0.42,
            whiteBalanceGains: Components.Schemas.WhiteBalanceGains(red: 1.2, green: 1.0, blue: 1.4),
            imageWidth: 4032,
            imageHeight: 3024,
            appVersion: "0.1.0",
            timestamp: Date(timeIntervalSince1970: 0)
        )
        let quality = Components.Schemas.CaptureQuality(
            detectedMarkerCount: 4,
            blurScore: 0.82,
            rejections: []
        )
        let output = try await client.createCapture(
            .init(
                path: .init(sheetId: "sheet_1"),
                body: .json(Components.Schemas.CaptureRequest(metadata: metadata, quality: quality))
            )
        )

        guard case .created(let payload) = output, case .json(let created) = payload.body else {
            return XCTFail("Expected 201 JSON capture body")
        }
        XCTAssertEqual(created.captureId, "cap_1")

        let recorded = try XCTUnwrap(transport.recordedRequests.first)
        XCTAssertEqual(recorded.operationID, "createCapture")
        XCTAssertEqual(recorded.method, "POST")
        XCTAssertEqual(recorded.path, "/api/v1/test_sheets/sheet_1/captures")
        XCTAssertEqual(recorded.contentType?.hasPrefix("application/json"), true)
        let json = try decodeJSONObject(from: recorded.bodyData)
        let metadataJSON = try XCTUnwrap(json["metadata"] as? [String: Any])
        XCTAssertEqual(metadataJSON["device_model"] as? String, "iPhone 15")
        XCTAssertEqual(metadataJSON["lens"] as? String, "built_in_wide_angle")
        XCTAssertEqual(try doubleValue(metadataJSON, "exposure_duration_seconds"), 0.016, accuracy: 0.000001)
        XCTAssertEqual(metadataJSON["iso"] as? Int, 100)
        XCTAssertEqual(metadataJSON["image_width"] as? Int, 4032)
        XCTAssertEqual(metadataJSON["timestamp"] as? String, "1970-01-01T00:00:00Z")
        let gainsJSON = try XCTUnwrap(metadataJSON["white_balance_gains"] as? [String: Any])
        XCTAssertEqual(try doubleValue(gainsJSON, "red"), 1.2, accuracy: 0.000001)
        XCTAssertEqual(try doubleValue(gainsJSON, "blue"), 1.4, accuracy: 0.000001)
        let qualityJSON = try XCTUnwrap(json["quality"] as? [String: Any])
        XCTAssertEqual(qualityJSON["detected_marker_count"] as? Int, 4)
        XCTAssertEqual(try doubleValue(qualityJSON, "blur_score"), 0.82, accuracy: 0.000001)
        XCTAssertEqual(qualityJSON["rejections"] as? [String], [])
    }

    func testUploadMeasurementsEncodesSpecShapedPayloadAndDecodesCounters() async throws {
        let transport = StubTransport()
        transport.enqueue(StubTransport.jsonResponse(statusCode: 200, payload: Fixtures.measurementAccepted))
        let client = Self.makeClient(transport)

        let request = Components.Schemas.MeasurementUploadRequest(
            measurements: [
                Components.Schemas.MeasurementEntry(
                    patchId: "pair_1#first",
                    linearRgbMedian: Components.Schemas.RgbChannelValues(r: 0.12, g: 0.1, b: 0.02),
                    normalizedLinearRgbMedian: Components.Schemas.RgbChannelValues(r: 0.15, g: 0.12, b: 0.02),
                    stats: Components.Schemas.MeasurementStats(
                        sampleCount: 900,
                        clippingFraction: 0,
                        mean: Components.Schemas.RgbChannelValues(r: 0.12, g: 0.1, b: 0.02),
                        standardDeviation: Components.Schemas.RgbChannelValues(r: 0.01, g: 0.01, b: 0.004)
                    )
                )
            ],
            pairScores: [
                Components.Schemas.PairScoreEntry(
                    pairId: "pair_1",
                    algorithmVersion: "lps-distance-v1",
                    similarity: 0.965,
                    distance: 0.035
                )
            ]
        )
        let output = try await client.uploadMeasurements(
            .init(path: .init(captureId: "cap_1"), body: .json(request))
        )

        guard case .ok(let okPayload) = output, case .json(let accepted) = okPayload.body else {
            return XCTFail("Expected 200 JSON measurement-upload body")
        }
        XCTAssertEqual(accepted.captureId, "cap_1")
        XCTAssertEqual(accepted.measurementCount, 1)
        XCTAssertEqual(accepted.pairScoreCount, 1)

        let recorded = try XCTUnwrap(transport.recordedRequests.first)
        XCTAssertEqual(recorded.operationID, "uploadMeasurements")
        XCTAssertEqual(recorded.method, "POST")
        XCTAssertEqual(recorded.path, "/api/v1/captures/cap_1/measurements")
        let json = try decodeJSONObject(from: recorded.bodyData)
        XCTAssertNil(json["scoring_algorithm_version"])
        let measurementJSON = try XCTUnwrap((json["measurements"] as? [[String: Any]])?.first)
        XCTAssertEqual(measurementJSON["patch_id"] as? String, "pair_1#first")
        let linearJSON = try XCTUnwrap(measurementJSON["linear_rgb_median"] as? [String: Any])
        XCTAssertEqual(try doubleValue(linearJSON, "r"), 0.12, accuracy: 0.000001)
        XCTAssertEqual(try doubleValue(linearJSON, "b"), 0.02, accuracy: 0.000001)
        let normalizedJSON = try XCTUnwrap(measurementJSON["normalized_linear_rgb_median"] as? [String: Any])
        XCTAssertEqual(try doubleValue(normalizedJSON, "r"), 0.15, accuracy: 0.000001)
        let statsJSON = try XCTUnwrap(measurementJSON["stats"] as? [String: Any])
        XCTAssertEqual(statsJSON["sample_count"] as? Int, 900)
        XCTAssertEqual(try doubleValue(statsJSON, "clipping_fraction"), 0, accuracy: 0.000001)
        let standardDeviationJSON = try XCTUnwrap(statsJSON["standard_deviation"] as? [String: Any])
        XCTAssertEqual(try doubleValue(standardDeviationJSON, "b"), 0.004, accuracy: 0.000001)
        let scoreJSON = try XCTUnwrap((json["pair_scores"] as? [[String: Any]])?.first)
        XCTAssertEqual(scoreJSON["pair_id"] as? String, "pair_1")
        XCTAssertEqual(scoreJSON["algorithm_version"] as? String, "lps-distance-v1")
        XCTAssertEqual(try doubleValue(scoreJSON, "similarity"), 0.965, accuracy: 0.000001)
        XCTAssertEqual(try doubleValue(scoreJSON, "distance"), 0.035, accuracy: 0.000001)
    }

    func testUploadJudgmentsEncodesEntriesAndDecodesCount() async throws {
        let transport = StubTransport()
        transport.enqueue(StubTransport.jsonResponse(statusCode: 200, payload: Fixtures.judgmentsAccepted))
        let client = Self.makeClient(transport)

        let output = try await client.uploadJudgments(
            .init(
                path: .init(captureId: "cap_1"),
                body: .json(
                    Components.Schemas.JudgmentUploadRequest(
                        judgments: [
                            Components.Schemas.PairJudgmentEntry(pairId: "pair_1", judgment: "near_match")
                        ]
                    )
                )
            )
        )

        guard case .ok(let okPayload) = output, case .json(let accepted) = okPayload.body else {
            return XCTFail("Expected 200 JSON judgment-upload body")
        }
        XCTAssertEqual(accepted.captureId, "cap_1")
        XCTAssertEqual(accepted.judgmentCount, 1)

        let recorded = try XCTUnwrap(transport.recordedRequests.first)
        XCTAssertEqual(recorded.operationID, "uploadJudgments")
        XCTAssertEqual(recorded.method, "POST")
        XCTAssertEqual(recorded.path, "/api/v1/captures/cap_1/judgments")
        let json = try decodeJSONObject(from: recorded.bodyData)
        let judgmentJSON = try XCTUnwrap((json["judgments"] as? [[String: Any]])?.first)
        XCTAssertEqual(judgmentJSON["pair_id"] as? String, "pair_1")
        XCTAssertEqual(judgmentJSON["judgment"] as? String, "near_match")
    }

    func testGetRankedResultsDecodesAggregatePayload() async throws {
        let transport = StubTransport()
        transport.enqueue(StubTransport.jsonResponse(statusCode: 200, payload: Fixtures.rankedResults))
        let client = Self.makeClient(transport)

        let output = try await client.getRankedResults(.init(path: .init(sheetId: "sheet_123")))

        guard case .ok(let okPayload) = output, case .json(let results) = okPayload.body else {
            return XCTFail("Expected 200 JSON ranked-results body")
        }
        XCTAssertEqual(results.schemaVersion, "lps-ranked-results/v1")
        XCTAssertEqual(results.sheetId, "sheet_123")
        XCTAssertEqual(results.printerProfile.inkType, "ink set")
        XCTAssertEqual(results.captureCount, 2)
        XCTAssertEqual(results.latestCaptureAt, StubDates.date("2026-07-26T09:30:00Z"))
        XCTAssertEqual(results.earliestCaptureAt, StubDates.date("2026-07-25T12:00:00Z"))
        XCTAssertEqual(results.scoringAlgorithmVersions, ["lps-distance-v1"])

        let entry = try XCTUnwrap(results.results.first)
        XCTAssertEqual(entry.rank, 1)
        XCTAssertEqual(entry.pairId, "pair_1")
        XCTAssertEqual(entry.scoringAlgorithmVersion, "lps-distance-v1")
        XCTAssertEqual(entry.row, 0)
        XCTAssertEqual(entry.col, 1)
        XCTAssertEqual(entry.sourceColors.colorAHex, "#FF0000")
        XCTAssertEqual(entry.sourceColors.colorBHex, "#00FF00")
        XCTAssertEqual(entry.score.average, 0.9, accuracy: 0.000001)
        XCTAssertEqual(entry.score.latest, 0.95, accuracy: 0.000001)
        XCTAssertEqual(entry.score.minimum, 0.85, accuracy: 0.000001)
        XCTAssertEqual(entry.score.captureCount, 2)
        XCTAssertEqual(entry.score.sampleCount, 2)
        XCTAssertEqual(entry.score.algorithmVersions, ["lps-distance-v1"])
        XCTAssertEqual(entry.currentJudgment, "near_match")
        XCTAssertEqual(entry.currentJudgmentObservedAt, StubDates.date("2026-07-26T09:31:00Z"))
        XCTAssertEqual(entry.observationCount, 3)
        XCTAssertEqual(entry.captureCount, 2)

        let recorded = try XCTUnwrap(transport.recordedRequests.first)
        XCTAssertEqual(recorded.operationID, "getRankedResults")
        XCTAssertEqual(recorded.method, "GET")
        XCTAssertEqual(recorded.path, "/api/v1/test_sheets/sheet_123/ranked_results")
    }

    func testGetTestSheetManifestSurfacesNotFoundCase() async throws {
        let transport = StubTransport()
        transport.enqueue(StubTransport.jsonResponse(statusCode: 404, payload: Fixtures.sheetNotFound))
        let client = Self.makeClient(transport)

        let output = try await client.getTestSheetManifest(.init(path: .init(sheetId: "missing")))

        guard case .notFound = output else {
            return XCTFail("Expected notFound output case")
        }
    }

    private static func makeClient(_ transport: StubTransport) -> ColorMatchingAPI.Client {
        ColorMatchingAPI.Client(serverURL: baseURL, transport: transport)
    }
}
