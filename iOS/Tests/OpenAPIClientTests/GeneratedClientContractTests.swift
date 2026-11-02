import Foundation
import OpenAPIGeneratedClient
import XCTest

/// Contract tests for the OpenAPI-generated client against the vendored
/// `color_matching` spec (see `docs/color-matching-openapi-client.md`).
///
/// Red phase note: these tests are the executable specification for the
/// `OpenAPIGeneratedClient` target required by issue #5. They compile (and
/// run) once that target and the `OpenAPIClientTests` test target are declared
/// in `iOS/Package.swift`; until then SwiftPM leaves this directory inert.
/// All HTTP traffic goes through `StubURLProtocol` — no live server is used.
final class GeneratedClientContractTests: XCTestCase {
    override func tearDown() {
        StubURLProtocol.handler = nil
        super.tearDown()
    }

    // MARK: - Sheet manifest

    func testGetTestSheetManifestDecodesFullManifestFixture() async throws {
        let recorder = RequestRecorder()
        let client = stubbedClient(status: 200, body: try Fixtures.manifest(), willSend: recorder.record)

        let response = try await client.getTestSheetManifest(.init(path: .init(sheet_id: "sheet_123")))

        XCTAssertEqual(recorder.request?.url?.path, "/api/v1/test_sheets/sheet_123/manifest")
        XCTAssertEqual(recorder.request?.httpMethod, "GET")
        guard case .ok(let ok) = response, case .json(let manifest) = ok.body else {
            return XCTFail("Expected .ok with JSON body, got: \(response)")
        }
        try assertManifestDecoded(manifest)
    }

    func testGetTestSheetManifestExposesNotFoundCase() async throws {
        let client = stubbedClient(status: 404, body: Fixtures.errorDetail)

        let response = try await client.getTestSheetManifest(.init(path: .init(sheet_id: "missing")))

        guard case .notFound = response else {
            return XCTFail("Expected .notFound, got: \(response)")
        }
    }

    // MARK: - Recent sheets

    func testListRecentTestSheetsDecodesSheetsAndNullableTitle() async throws {
        let recorder = RequestRecorder()
        let client = stubbedClient(status: 200, body: Fixtures.recentSheets, willSend: recorder.record)

        let response = try await client.listRecentTestSheets(.init())

        XCTAssertEqual(recorder.request?.url?.path, "/api/v1/test_sheets/recent")
        XCTAssertEqual(recorder.request?.httpMethod, "GET")
        guard case .ok(let ok) = response, case .json(let payload) = ok.body else {
            return XCTFail("Expected .ok with JSON body, got: \(response)")
        }
        XCTAssertEqual(payload.sheets.count, 2)
        XCTAssertEqual(payload.sheets.first?.sheetId, "sheet_123")
        XCTAssertEqual(payload.sheets.first?.manifestUrl, "https://example.test/api/v1/test_sheets/sheet_123/manifest")
        XCTAssertNil(payload.sheets.first?.title)
        XCTAssertEqual(payload.sheets.last?.title, "July LPS comparison sheet")
    }

    // MARK: - Capture session creation

    func testCreateCapturePostsNestedMetadataAndQuality() async throws {
        let recorder = RequestRecorder()
        let client = stubbedClient(status: 201, body: Fixtures.captureCreated, willSend: recorder.record)

        let response = try await client.createCapture(
            .init(
                path: .init(sheet_id: "sheet_123"),
                body: .json(
                    .init(
                        metadata: .init(
                            deviceModel: "iPhone 15",
                            lens: "built_in_wide_angle_rear",
                            exposureDurationSeconds: 0.016,
                            iso: 100,
                            focusLensPosition: 0.42,
                            whiteBalanceGains: .init(red: 1.2, green: 1.0, blue: 1.4),
                            imageWidth: 4032,
                            imageHeight: 3024,
                            appVersion: "0.1.0",
                            timestamp: "2026-07-25T12:00:00Z"
                        ),
                        quality: .init(detectedMarkerCount: 4, blurScore: 0.82, rejections: [])
                    )
                )
            )
        )

        XCTAssertEqual(recorder.request?.url?.path, "/api/v1/test_sheets/sheet_123/captures")
        XCTAssertEqual(recorder.request?.httpMethod, "POST")
        guard case .created(let created) = response, case .json(let payload) = created.body else {
            return XCTFail("Expected .created with JSON body, got: \(response)")
        }
        XCTAssertEqual(payload.captureId, "42")
        try assertCreateCaptureBody(StubbedRequestBody.json(from: recorder.request))
    }

    // MARK: - Measurement upload

    func testUploadMeasurementsPostsSpecShapedPayload() async throws {
        let recorder = RequestRecorder()
        let client = stubbedClient(status: 200, body: Fixtures.measurementUploadAccepted, willSend: recorder.record)

        let response = try await client.uploadMeasurements(
            .init(
                path: .init(capture_id: "42"),
                body: .json(
                    .init(
                        measurements: [
                            .init(
                                patchId: "pair_1#first",
                                linearRgbMedian: .init(r: 0.12, g: 0.1, b: 0.02),
                                normalizedLinearRgbMedian: .init(r: 0.15, g: 0.12, b: 0.02)
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
        )

        XCTAssertEqual(recorder.request?.url?.path, "/api/v1/captures/42/measurements")
        XCTAssertEqual(recorder.request?.httpMethod, "POST")
        guard case .ok(let ok) = response, case .json(let payload) = ok.body else {
            return XCTFail("Expected .ok with JSON body, got: \(response)")
        }
        XCTAssertEqual(payload.captureId, "42")
        XCTAssertEqual(payload.measurementCount, 1)
        XCTAssertEqual(payload.pairScoreCount, 1)
        try assertMeasurementUploadBody(StubbedRequestBody.json(from: recorder.request))
    }

    // MARK: - Judgment upload

    func testUploadJudgmentsPostsPairJudgments() async throws {
        let recorder = RequestRecorder()
        let client = stubbedClient(status: 200, body: Fixtures.judgmentUploadAccepted, willSend: recorder.record)

        let response = try await client.uploadJudgments(
            .init(
                path: .init(capture_id: "42"),
                body: .json(.init(judgments: [.init(pairId: "pair_1", judgment: "near_match")]))
            )
        )

        XCTAssertEqual(recorder.request?.url?.path, "/api/v1/captures/42/judgments")
        XCTAssertEqual(recorder.request?.httpMethod, "POST")
        guard case .ok(let ok) = response, case .json(let payload) = ok.body else {
            return XCTFail("Expected .ok with JSON body, got: \(response)")
        }
        XCTAssertEqual(payload.captureId, "42")
        XCTAssertEqual(payload.judgmentCount, 1)
        let body = try StubbedRequestBody.json(from: recorder.request)
        let judgment = try XCTUnwrap((body["judgments"] as? [[String: Any]])?.first)
        XCTAssertEqual(judgment["pair_id"] as? String, "pair_1")
        XCTAssertEqual(judgment["judgment"] as? String, "near_match")
    }

    // MARK: - Ranked results

    func testGetRankedResultsDecodesAggregateFixture() async throws {
        let recorder = RequestRecorder()
        let client = stubbedClient(status: 200, body: try Fixtures.rankedResults(), willSend: recorder.record)

        let response = try await client.getRankedResults(.init(path: .init(sheet_id: "sheet_123")))

        XCTAssertEqual(recorder.request?.url?.path, "/api/v1/test_sheets/sheet_123/ranked_results")
        XCTAssertEqual(recorder.request?.httpMethod, "GET")
        guard case .ok(let ok) = response, case .json(let payload) = ok.body else {
            return XCTFail("Expected .ok with JSON body, got: \(response)")
        }
        try assertRankedResultsDecoded(payload)
    }

    // MARK: - Decoding assertions

    private func assertManifestDecoded(_ manifest: Components.Schemas.TestSheetManifest) throws {
        XCTAssertEqual(manifest.schemaVersion, "lps-sheet-manifest/v1")
        XCTAssertEqual(manifest.sheetVersion, "lps-letter-grid-v1")
        XCTAssertEqual(manifest.sheetId, "sheet_123")
        XCTAssertEqual(manifest.manifestUrl, "https://example.test/api/v1/test_sheets/sheet_123/manifest")
        XCTAssertEqual(manifest.createdAt, "2026-07-25T12:00:00Z")
        XCTAssertEqual(manifest.page.units, "mm")
        XCTAssertEqual(manifest.page.width, 215.9, accuracy: 0.0001)
        XCTAssertEqual(manifest.page.height, 279.4, accuracy: 0.0001)
        XCTAssertEqual(manifest.registrationMarkers.first?.role, "top_left")
        XCTAssertEqual(manifest.registrationMarkers.first?.shape, "solid_square")
        XCTAssertEqual(manifest.printerProfile?.printerMakeModel, "Canon Pixma")
        XCTAssertEqual(manifest.printerProfile?.paperType, "Photo Paper Plus Glossy II")
        XCTAssertEqual(manifest.captureProfile.scoringAlgorithmVersion, "lps-distance-v1")
        XCTAssertEqual(manifest.patches.first?.id, "pair_1#first")
        XCTAssertEqual(manifest.patches.first?.pairId, "pair_1")
        XCTAssertEqual(manifest.patches.first?.pairSide, "first")
        XCTAssertEqual(manifest.patches.first?.sourceColor, "#FF0000")
        XCTAssertEqual(manifest.patches.first?.safeInsetMm, 1.5, accuracy: 0.0001)
        XCTAssertEqual(manifest.pairs.first?.firstPatchId, "pair_1#first")
        XCTAssertEqual(manifest.pairs.first?.secondPatchId, "pair_1#second")
        XCTAssertEqual(manifest.pairs.first?.sourceColors, ["#FF0000", "#00FF00"])
    }

    private func assertCreateCaptureBody(_ body: [String: Any]) throws {
        let metadata = try XCTUnwrap(body["metadata"] as? [String: Any])
        XCTAssertEqual(metadata["device_model"] as? String, "iPhone 15")
        XCTAssertEqual(metadata["lens"] as? String, "built_in_wide_angle_rear")
        XCTAssertEqual(metadata["exposure_duration_seconds"] as? Double, 0.016, accuracy: 0.0001)
        XCTAssertEqual(metadata["iso"] as? Int, 100)
        XCTAssertEqual(metadata["timestamp"] as? String, "2026-07-25T12:00:00Z")
        let gains = try XCTUnwrap(metadata["white_balance_gains"] as? [String: Double])
        XCTAssertEqual(gains["red"] ?? 0, 1.2, accuracy: 0.0001)
        XCTAssertEqual(gains["green"] ?? 0, 1.0, accuracy: 0.0001)
        XCTAssertEqual(gains["blue"] ?? 0, 1.4, accuracy: 0.0001)
        let quality = try XCTUnwrap(body["quality"] as? [String: Any])
        XCTAssertEqual(quality["detected_marker_count"] as? Int, 4)
        XCTAssertEqual(quality["blur_score"] as? Double, 0.82, accuracy: 0.0001)
        XCTAssertEqual(quality["rejections"] as? [String], [])
    }

    /// Delta guard (docs/color-matching-openapi-client.md, delta #8): the
    /// published spec has no top-level `scoring_algorithm_version` and no
    /// per-measurement `stats` — the generated payload must match the spec
    /// shape exactly so server-side drift surfaces as a regeneration diff.
    private func assertMeasurementUploadBody(_ body: [String: Any]) throws {
        XCTAssertNil(body["scoring_algorithm_version"])
        let measurement = try XCTUnwrap((body["measurements"] as? [[String: Any]])?.first)
        XCTAssertEqual(measurement["patch_id"] as? String, "pair_1#first")
        let median = try XCTUnwrap(measurement["linear_rgb_median"] as? [String: Double])
        XCTAssertEqual(median["r"] ?? 0, 0.12, accuracy: 0.0001)
        XCTAssertEqual(median["g"] ?? 0, 0.1, accuracy: 0.0001)
        XCTAssertNotNil(measurement["normalized_linear_rgb_median"])
        XCTAssertNil(measurement["stats"])
        let score = try XCTUnwrap((body["pair_scores"] as? [[String: Any]])?.first)
        XCTAssertEqual(score["pair_id"] as? String, "pair_1")
        XCTAssertEqual(score["algorithm_version"] as? String, "lps-distance-v1")
        XCTAssertEqual(score["similarity"] as? Double, 0.965, accuracy: 0.0001)
        XCTAssertEqual(score["distance"] as? Double, 0.035, accuracy: 0.0001)
    }

    private func assertRankedResultsDecoded(_ payload: Components.Schemas.RankedResults) throws {
        XCTAssertEqual(payload.schemaVersion, "lps-ranked-results/v1")
        XCTAssertEqual(payload.sheetId, "sheet_123")
        XCTAssertEqual(payload.captureCount, 2)
        XCTAssertEqual(payload.latestCaptureAt, "2026-07-25T12:30:00Z")
        XCTAssertEqual(payload.earliestCaptureAt, "2026-07-25T12:00:00Z")
        XCTAssertEqual(payload.scoringAlgorithmVersions, ["lps-distance-v1"])
        XCTAssertEqual(payload.printerProfile?.printerMakeModel, "Canon Pixma")
        let result = try XCTUnwrap(payload.results.first)
        XCTAssertEqual(result.rank, 1)
        XCTAssertEqual(result.pairId, "pair_1")
        XCTAssertEqual(result.scoringAlgorithmVersion, "lps-distance-v1")
        XCTAssertEqual(result.row, 0)
        XCTAssertEqual(result.col, 1)
        XCTAssertEqual(result.sourceColors.colorAHex, "#FF0000")
        XCTAssertEqual(result.sourceColors.colorBHex, "#00FF00")
        XCTAssertEqual(result.score.average, 0.035, accuracy: 0.0001)
        XCTAssertEqual(result.score.captureCount, 2)
        XCTAssertEqual(result.score.sampleCount, 2)
        XCTAssertEqual(result.currentJudgment, "match")
        XCTAssertEqual(result.observationCount, 1)
        XCTAssertEqual(result.latestObservation?.judgment, "match")
    }

    // MARK: - Helpers

    private func stubbedClient(
        status: Int,
        body: Data,
        willSend: ((URLRequest) -> Void)? = nil
    ) -> OpenAPIGeneratedClient.Client {
        StubbedTransport.client(status: status, body: body, willSend: willSend)
    }
}

// MARK: - Fixtures

/// Fixture payloads mirror what upstream `viamin/color_matching` actually
/// renders (see `ColorMatchingWeb.TestSheetJSON` / `CaptureController`),
/// not the prose contract — so these tests double as drift detectors for the
/// deltas recorded in `docs/color-matching-openapi-client.md`.
private enum Fixtures {
    static let errorDetail = Data(#"{"errors":{"detail":"Sheet not found"}}"#.utf8)
    static let captureCreated = Data(#"{"capture_id":"42"}"#.utf8)
    static let measurementUploadAccepted = Data(#"{"capture_id":"42","measurement_count":1,"pair_score_count":1}"#.utf8)
    static let judgmentUploadAccepted = Data(#"{"capture_id":"42","judgment_count":1}"#.utf8)
    static let recentSheets = Data(
        #"{"sheets":[{"sheet_id":"sheet_123","manifest_url":"https://example.test/api/v1/test_sheets/sheet_123/manifest","title":null},{"sheet_id":"sheet_456","manifest_url":"https://example.test/api/v1/test_sheets/sheet_456/manifest","title":"July LPS comparison sheet"}]}"#.utf8
    )

    static func manifest() throws -> Data {
        let manifest: [String: Any] = [
            "schema_version": "lps-sheet-manifest/v1",
            "sheet_version": "lps-letter-grid-v1",
            "sheet_id": "sheet_123",
            "manifest_url": "https://example.test/api/v1/test_sheets/sheet_123/manifest",
            "created_at": "2026-07-25T12:00:00Z",
            "page": ["units": "mm", "width": 215.9, "height": 279.4],
            "registration_markers": [
                ["role": "top_left", "shape": "solid_square", "rect": ["x": 12, "y": 12, "width": 8, "height": 8]]
            ],
            "printer_profile": [
                "printer_make_model": "Canon Pixma",
                "paper_type": "Photo Paper Plus Glossy II",
                "ink_type": "CLI-42",
                "notes": NSNull()
            ],
            "capture_profile": [
                "expected_illuminant": "low_pressure_sodium",
                "preferred_camera": "built_in_wide_angle_rear",
                "scoring_algorithm_version": "lps-distance-v1"
            ],
            "patches": [
                [
                    "id": "pair_1#first",
                    "role": "pair_color",
                    "pair_id": "pair_1",
                    "pair_side": "first",
                    "reference_role": NSNull(),
                    "source_color": "#FF0000",
                    "safe_inset_mm": 1.5,
                    "rect": ["x": 16, "y": 38, "width": 16, "height": 10]
                ]
            ],
            "pairs": [
                [
                    "id": "pair_1",
                    "first_patch_id": "pair_1#first",
                    "second_patch_id": "pair_1#second",
                    "source_colors": ["#FF0000", "#00FF00"],
                    "grid_row": 0,
                    "grid_col": 1
                ]
            ]
        ]
        return try JSONSerialization.data(withJSONObject: manifest)
    }

    static func rankedResults() throws -> Data {
        let ranked: [String: Any] = [
            "schema_version": "lps-ranked-results/v1",
            "sheet_id": "sheet_123",
            "printer_profile": [
                "printer_make_model": "Canon Pixma",
                "paper_type": "Photo Paper Plus Glossy II",
                "ink_type": "CLI-42"
            ],
            "capture_count": 2,
            "latest_capture_at": "2026-07-25T12:30:00Z",
            "earliest_capture_at": "2026-07-25T12:00:00Z",
            "scoring_algorithm_versions": ["lps-distance-v1"],
            "results": [
                [
                    "rank": 1,
                    "pair_id": "pair_1",
                    "scoring_algorithm_version": "lps-distance-v1",
                    "row": 0,
                    "col": 1,
                    "source_colors": ["color_a_hex": "#FF0000", "color_b_hex": "#00FF00"],
                    "score": [
                        "average": 0.035,
                        "latest": 0.04,
                        "minimum": 0.03,
                        "maximum": 0.04,
                        "capture_count": 2,
                        "sample_count": 2,
                        "algorithm_versions": ["lps-distance-v1"]
                    ],
                    "current_judgment": "match",
                    "current_judgment_observed_at": "2026-07-25T12:35:00Z",
                    "observation_count": 1,
                    "latest_observation": ["judgment": "match", "observed_at": "2026-07-25T12:35:00Z"],
                    "capture_count": 2,
                    "latest_capture_at": "2026-07-25T12:30:00Z",
                    "earliest_capture_at": "2026-07-25T12:00:00Z"
                ]
            ]
        ]
        return try JSONSerialization.data(withJSONObject: ranked)
    }
}
