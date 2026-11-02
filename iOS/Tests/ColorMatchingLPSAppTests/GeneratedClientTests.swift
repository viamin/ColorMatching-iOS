import Foundation
import ColorMatchingOpenAPI
import XCTest

final class GeneratedClientTests: XCTestCase {
    func testGetTestSheetManifestSendsGETAndDecodesManifest() async throws {
        let transport = RecordingTransport { _, _ in
            GeneratedClientStubs.json(GeneratedClientFixtures.manifest, status: 200)
        }

        let output = try await makeClient(transport).getTestSheetManifest(.init(path: .init(sheetID: "sheet_123")))

        switch output {
        case .ok(let ok):
            guard case .json(let manifest) = ok.body else {
                return XCTFail("Expected JSON body for manifest response")
            }
            XCTAssertEqual(manifest.schemaVersion, "lps-sheet-manifest/v1")
            XCTAssertEqual(manifest.sheetVersion, "lps-letter-grid-v1")
            XCTAssertEqual(manifest.sheetID, "sheet_123")
            XCTAssertEqual(manifest.page.units, "mm")
            XCTAssertEqual(manifest.page.width, 215.9)
            XCTAssertEqual(manifest.registrationMarkers.first?.rect, Components.Schemas.Rect(x: 12, y: 12, width: 8, height: 8))
            XCTAssertEqual(manifest.printerProfile.name, "Research printer")
            XCTAssertEqual(manifest.captureProfile.scoringAlgorithmVersion, "lps-distance-v1")
            XCTAssertEqual(manifest.createdAt, Self.date("2026-07-25T12:00:00Z"))
            XCTAssertEqual(manifest.patches.first?.sourceColor, "#FF0000")
            XCTAssertEqual(manifest.patches.first?.safeInsetMM, 1.5)
            XCTAssertEqual(manifest.pairs.first?.sourceColors, ["#FF0000", "#00FF00"])
        default:
            XCTFail("Expected 200 ok for manifest response")
        }

        XCTAssertEqual(Self.method(of: transport, at: 0), "GET")
        XCTAssertEqual(Self.path(of: transport, at: 0), "/test_sheets/sheet_123/manifest")
        XCTAssertEqual(Self.operationID(of: transport, at: 0), "getTestSheetManifest")
        XCTAssertEqual(transport.baseURLs[0].absoluteString, "https://example.test/api/v1")
    }

    func testGetRecentTestSheetsDecodesSheetsIncludingNullTitle() async throws {
        let transport = RecordingTransport { _, _ in
            GeneratedClientStubs.json(GeneratedClientFixtures.recentSheets, status: 200)
        }

        let output = try await makeClient(transport).getRecentTestSheets(.init())

        switch output {
        case .ok(let ok):
            guard case .json(let payload) = ok.body else {
                return XCTFail("Expected JSON body for recent sheets response")
            }
            XCTAssertEqual(payload.sheets.map(\.sheetID), ["sheet_123", "sheet_456"])
            XCTAssertEqual(payload.sheets[0].title, "July LPS comparison sheet")
            XCTAssertNil(payload.sheets[1].title)
            XCTAssertEqual(payload.sheets[1].manifestURL, URL(string: "https://example.test/api/v1/test_sheets/sheet_456/manifest"))
        default:
            XCTFail("Expected 200 ok for recent sheets response")
        }

        XCTAssertEqual(Self.method(of: transport, at: 0), "GET")
        XCTAssertEqual(Self.path(of: transport, at: 0), "/test_sheets/recent")
        XCTAssertEqual(Self.operationID(of: transport, at: 0), "getRecentTestSheets")
    }

    func testCreateCaptureEncodesMetadataQualityAndDecodesCaptureID() async throws {
        let transport = RecordingTransport { _, _ in
            GeneratedClientStubs.json(GeneratedClientFixtures.captureSession, status: 201)
        }

        let input = Operations.createCapture.Input(
            path: .init(sheetID: "sheet_123"),
            body: .json(Components.Schemas.CreateCaptureRequest(
                metadata: Components.Schemas.CaptureMetadata(
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
                ),
                quality: Components.Schemas.CaptureQuality(
                    detectedMarkerCount: 4,
                    blurScore: 0.82,
                    rejections: []
                )
            ))
        )

        let output = try await makeClient(transport).createCapture(input)

        switch output {
        case .created(let created):
            guard case .json(let payload) = created.body else {
                return XCTFail("Expected JSON body for capture session response")
            }
            XCTAssertEqual(payload.captureID, "cap_123")
        default:
            XCTFail("Expected 201 created for capture session response")
        }

        XCTAssertEqual(Self.method(of: transport, at: 0), "POST")
        XCTAssertEqual(Self.path(of: transport, at: 0), "/test_sheets/sheet_123/captures")
        XCTAssertEqual(Self.operationID(of: transport, at: 0), "createCapture")
        XCTAssertEqual(Self.header(of: transport, at: 0, named: "content-type"), "application/json")

        let json = try Self.jsonObject(from: transport.bodies[0]) as? [String: Any]
        let metadata = try XCTUnwrap(json?["metadata"] as? [String: Any])
        XCTAssertEqual(metadata["device_model"] as? String, "iPhone 15")
        XCTAssertEqual(metadata["app_version"] as? String, "0.1.0")
        XCTAssertEqual(metadata["image_width"] as? Int, 4032)
        XCTAssertEqual((metadata["white_balance_gains"] as? [String: Any])?["red"] as? Double, 1.2)
        let timestamp = try XCTUnwrap(metadata["timestamp"] as? String)
        XCTAssertTrue(timestamp.hasPrefix("1970-01-01T00:00:00"), "unexpected timestamp encoding: \(timestamp)")
        let quality = try XCTUnwrap(json?["quality"] as? [String: Any])
        XCTAssertEqual(quality["detected_marker_count"] as? Int, 4)
        XCTAssertEqual(quality["rejections"] as? [String], [])
    }

    func testUploadMeasurementsEncodesSnakeCasePayloadAndAcceptsNoContent() async throws {
        let transport = RecordingTransport { _, _ in
            GeneratedClientStubs.noContent()
        }

        let input = Operations.uploadMeasurements.Input(
            path: .init(captureID: "cap_123"),
            body: .json(Components.Schemas.MeasurementUploadRequest(
                scoringAlgorithmVersion: "lps-distance-v1",
                measurements: [
                    Components.Schemas.PatchMeasurementUpload(
                        patchID: "patch_1",
                        linearRgbMedian: .init(r: 0.12, g: 0.10, b: 0.02),
                        normalizedLinearRgbMedian: .init(r: 0.15, g: 0.12, b: 0.02),
                        stats: .init(
                            sampleCount: 900,
                            clippingFraction: 0,
                            mean: .init(r: 0.12, g: 0.10, b: 0.02),
                            standardDeviation: .init(r: 0.01, g: 0.01, b: 0.004)
                        )
                    )
                ],
                pairScores: [
                    .init(
                        pairID: "pair_1",
                        distance: 0.035,
                        similarity: 0.965,
                        algorithmVersion: "lps-distance-v1"
                    )
                ]
            ))
        )

        let output = try await makeClient(transport).uploadMeasurements(input)

        if case .noContent = output {} else {
            XCTFail("Expected 204 no content for measurement upload")
        }

        XCTAssertEqual(Self.method(of: transport, at: 0), "POST")
        XCTAssertEqual(Self.path(of: transport, at: 0), "/captures/cap_123/measurements")
        XCTAssertEqual(Self.operationID(of: transport, at: 0), "uploadMeasurements")

        let json = try Self.jsonObject(from: transport.bodies[0]) as? [String: Any]
        XCTAssertEqual(json?["scoring_algorithm_version"] as? String, "lps-distance-v1")
        let measurement = try XCTUnwrap((json?["measurements"] as? [[String: Any]])?.first)
        XCTAssertEqual(measurement["patch_id"] as? String, "patch_1")
        XCTAssertEqual((measurement["linear_rgb_median"] as? [String: Any])?["r"] as? Double, 0.12)
        XCTAssertEqual((measurement["normalized_linear_rgb_median"] as? [String: Any])?["g"] as? Double, 0.12)
        let stats = try XCTUnwrap(measurement["stats"] as? [String: Any])
        XCTAssertEqual(Set(stats.keys), ["sample_count", "clipping_fraction", "mean", "standard_deviation"])
        XCTAssertEqual(stats["sample_count"] as? Int, 900)
        let score = try XCTUnwrap((json?["pair_scores"] as? [[String: Any]])?.first)
        XCTAssertEqual(score["pair_id"] as? String, "pair_1")
        XCTAssertEqual(score["similarity"] as? Double, 0.965)
    }

    func testUploadJudgmentsEncodesJudgmentWireValue() async throws {
        let transport = RecordingTransport { _, _ in
            GeneratedClientStubs.noContent()
        }

        let input = Operations.uploadJudgments.Input(
            path: .init(captureID: "cap_123"),
            body: .json(Components.Schemas.JudgmentUploadRequest(
                judgments: [.init(pairID: "pair_1", judgment: .nearMatch)]
            ))
        )

        let output = try await makeClient(transport).uploadJudgments(input)

        if case .noContent = output {} else {
            XCTFail("Expected 204 no content for judgment upload")
        }

        XCTAssertEqual(Self.method(of: transport, at: 0), "POST")
        XCTAssertEqual(Self.path(of: transport, at: 0), "/captures/cap_123/judgments")
        XCTAssertEqual(Self.operationID(of: transport, at: 0), "uploadJudgments")

        let json = try Self.jsonObject(from: transport.bodies[0]) as? [String: Any]
        let judgment = try XCTUnwrap((json?["judgments"] as? [[String: Any]])?.first)
        XCTAssertEqual(judgment["pair_id"] as? String, "pair_1")
        XCTAssertEqual(judgment["judgment"] as? String, "near_match")
    }

    func testGetRankedResultsDecodesRankedPairs() async throws {
        let transport = RecordingTransport { _, _ in
            GeneratedClientStubs.json(GeneratedClientFixtures.rankedResults, status: 200)
        }

        let output = try await makeClient(transport).getRankedResults(.init(path: .init(sheetID: "sheet_123")))

        switch output {
        case .ok(let ok):
            guard case .json(let payload) = ok.body else {
                return XCTFail("Expected JSON body for ranked results response")
            }
            XCTAssertEqual(payload.schemaVersion, "lps-ranked-results/v1")
            XCTAssertEqual(payload.sheetID, "sheet_123")
            XCTAssertEqual(payload.scoringAlgorithmVersion, "lps-distance-v1")
            XCTAssertEqual(payload.results.count, 1)
            let result = try XCTUnwrap(payload.results.first)
            XCTAssertEqual(result.pairID, "pair_1")
            XCTAssertEqual(result.rank, 1)
            XCTAssertEqual(result.sourceColors, ["#FF0000", "#00FF00"])
            XCTAssertEqual(result.distance, 0.035, accuracy: 0.0001)
            XCTAssertEqual(result.similarity, 0.965, accuracy: 0.0001)
            XCTAssertEqual(result.judgment, .nearMatch)
            XCTAssertEqual(result.captureID, "capture_123")
        default:
            XCTFail("Expected 200 ok for ranked results response")
        }

        XCTAssertEqual(Self.method(of: transport, at: 0), "GET")
        XCTAssertEqual(Self.path(of: transport, at: 0), "/test_sheets/sheet_123/ranked_results")
        XCTAssertEqual(Self.operationID(of: transport, at: 0), "getRankedResults")
    }

    private func makeClient(_ transport: RecordingTransport) -> ColorMatchingOpenAPI.Client {
        ColorMatchingOpenAPI.Client(
            serverURL: URL(string: "https://example.test/api/v1")!,
            transport: transport
        )
    }

    private static func method(of transport: RecordingTransport, at index: Int) -> String {
        transport.requests[index].method.rawValue.uppercased()
    }

    private static func path(of transport: RecordingTransport, at index: Int) -> String {
        transport.requests[index].path
    }

    private static func operationID(of transport: RecordingTransport, at index: Int) -> String {
        transport.operationIDs[index]
    }

    private static func header(of transport: RecordingTransport, at index: Int, named name: String) -> String? {
        transport.requests[index].headerFields.first {
            $0.name.rawValue.lowercased() == name.lowercased()
        }?.value
    }

    private static func jsonObject(from data: Data) throws -> Any {
        try JSONSerialization.jsonObject(with: data)
    }

    private static func date(_ iso: String) -> Date {
        ISO8601DateFormatter().date(from: iso)!
    }
}
