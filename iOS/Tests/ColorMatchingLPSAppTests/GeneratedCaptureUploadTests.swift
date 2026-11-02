import ColorMatchingOpenAPI
import XCTest

final class GeneratedCaptureUploadTests: XCTestCase {
    func testCreateCapturePostsMetadataAndQualityAndDecodesCaptureID() async throws {
        let (client, transport) = makeGeneratedClient(
            stub: .json(status: .created, body: GeneratedClientFixtures.captureCreatedJSON)
        )

        let metadata = Components.Schemas.CaptureMetadata(
            deviceModel: "iPhone 15 Pro",
            lens: "built_in_wide_angle",
            exposureDurationSeconds: 0.016,
            iso: 100,
            focusLensPosition: 0.42,
            whiteBalanceGains: nil,
            imageWidth: 4032,
            imageHeight: 3024,
            appVersion: "0.1.0",
            timestamp: Date(timeIntervalSince1970: 1_785_000_000)
        )
        let quality = Components.Schemas.CaptureRequest.QualityPayload(
            detectedMarkerCount: 4,
            blurScore: 0.82,
            rejections: []
        )
        let captureRequest = Components.Schemas.CaptureRequest(metadata: metadata, quality: quality)

        let response = try await client.createCapture(
            .init(path: .init(sheetID: "sheet_123"), body: .json(captureRequest))
        )

        XCTAssertEqual(try response.created.body.json.captureId, "capture_123")

        let recorded = try XCTUnwrap(transport.recorded.first)
        XCTAssertEqual(recorded.method, "POST")
        XCTAssertEqual(recorded.path, "/api/v1/test_sheets/sheet_123/captures")
        XCTAssertEqual(recorded.contentType, "application/json")
        XCTAssertEqual(recorded.operationID, "ColorMatchingWeb.CaptureController.create")

        let json = try jsonObject(from: recorded.body)
        let metadataJSON = try object(json, "metadata")
        XCTAssertEqual(try string(metadataJSON, "device_model"), "iPhone 15 Pro")
        XCTAssertEqual(try string(metadataJSON, "lens"), "built_in_wide_angle")
        XCTAssertEqual(try double(metadataJSON, "exposure_duration_seconds"), 0.016, accuracy: 0.000001)
        XCTAssertEqual(try double(metadataJSON, "iso"), 100)
        XCTAssertEqual(try double(metadataJSON, "focus_lens_position"), 0.42, accuracy: 0.000001)
        XCTAssertEqual(try double(metadataJSON, "image_width"), 4032)
        XCTAssertEqual(try double(metadataJSON, "image_height"), 3024)
        XCTAssertEqual(try string(metadataJSON, "app_version"), "0.1.0")
        XCTAssertNotNil(metadataJSON["timestamp"] as? String)
        let qualityJSON = try object(json, "quality")
        XCTAssertEqual(try double(qualityJSON, "detected_marker_count"), 4)
        XCTAssertEqual(try double(qualityJSON, "blur_score"), 0.82, accuracy: 0.000001)
        XCTAssertEqual((qualityJSON["rejections"] as? [String]) ?? ["unexpected"], [])
    }

    func testCreateCaptureSurfacesUnauthorizedResponse() async throws {
        let (client, _) = makeGeneratedClient(
            stub: .json(status: .unauthorized, body: GeneratedClientFixtures.errorJSON)
        )

        let response = try await client.createCapture(
            .init(path: .init(sheetID: "sheet_123"), body: .json(Components.Schemas.CaptureRequest()))
        )

        switch response {
        case .unauthorized:
            break
        default:
            XCTFail("Expected an unauthorized response, got \(response)")
        }
    }

    func testUploadMeasurementsEncodesDocumentedPayloadAndDecodesCounters() async throws {
        let (client, transport) = makeGeneratedClient(
            stub: .json(status: .ok, body: GeneratedClientFixtures.measurementUploadAcceptedJSON)
        )

        let linearMedian = Components.Schemas.RgbPayload(value2: .init(r: 0.12, g: 0.1, b: 0.02))
        let normalizedMedian = Components.Schemas.RgbPayload(value2: .init(r: 0.15, g: 0.12, b: 0.02))
        let measurement = Components.Schemas.MeasurementUploadRequest.MeasurementsPayloadPayload(
            patchID: "patch_1",
            linearRGBMedian: linearMedian,
            normalizedLinearRGBMedian: normalizedMedian
        )
        let pairScore = Components.Schemas.PairScoreRequest(
            pairID: "pair_1",
            algorithmVersion: "lps-distance-v1",
            similarity: 0.965,
            distance: 0.035
        )
        let upload = Components.Schemas.MeasurementUploadRequest(
            measurements: [measurement],
            pairScores: [pairScore]
        )

        let response = try await client.uploadMeasurements(
            .init(path: .init(captureID: "capture_123"), body: .json(upload))
        )

        let payload = try response.ok.body.json
        XCTAssertEqual(payload.captureId, "capture_123")
        XCTAssertEqual(payload.measurementCount, 1)
        XCTAssertEqual(payload.pairScoreCount, 1)

        let recorded = try XCTUnwrap(transport.recorded.first)
        XCTAssertEqual(recorded.method, "POST")
        XCTAssertEqual(recorded.path, "/api/v1/captures/capture_123/measurements")
        XCTAssertEqual(recorded.operationID, "ColorMatchingWeb.CaptureController.upload_measurements")

        let json = try jsonObject(from: recorded.body)
        XCTAssertNil(json["scoring_algorithm_version"])
        let measurements = try array(json, "measurements")
        XCTAssertEqual(measurements.count, 1)
        let measurementJSON = try XCTUnwrap(measurements.first)
        XCTAssertEqual(try string(measurementJSON, "patch_id"), "patch_1")
        XCTAssertNil(measurementJSON["stats"])
        let linear = try object(measurementJSON, "linear_rgb_median")
        XCTAssertEqual(try double(linear, "r"), 0.12, accuracy: 0.0001)
        XCTAssertEqual(try double(linear, "g"), 0.1, accuracy: 0.0001)
        XCTAssertEqual(try double(linear, "b"), 0.02, accuracy: 0.0001)
        XCTAssertNotNil(try? object(measurementJSON, "normalized_linear_rgb_median"))
        let scores = try array(json, "pair_scores")
        XCTAssertEqual(scores.count, 1)
        let scoreJSON = try XCTUnwrap(scores.first)
        XCTAssertEqual(try string(scoreJSON, "pair_id"), "pair_1")
        XCTAssertEqual(try string(scoreJSON, "algorithm_version"), "lps-distance-v1")
        XCTAssertEqual(try double(scoreJSON, "similarity"), 0.965, accuracy: 0.0001)
        XCTAssertEqual(try double(scoreJSON, "distance"), 0.035, accuracy: 0.0001)
    }

    func testUploadJudgmentsEncodesPairsAndDecodesJudgmentCount() async throws {
        let (client, transport) = makeGeneratedClient(
            stub: .json(status: .ok, body: GeneratedClientFixtures.judgmentUploadAcceptedJSON)
        )

        let judgment = Components.Schemas.JudgmentUploadRequest.JudgmentsPayloadPayload(
            pairID: "pair_1",
            judgment: "near_match"
        )
        let upload = Components.Schemas.JudgmentUploadRequest(judgments: [judgment])

        let response = try await client.uploadJudgments(
            .init(path: .init(captureID: "capture_123"), body: .json(upload))
        )

        let payload = try response.ok.body.json
        XCTAssertEqual(payload.captureId, "capture_123")
        XCTAssertEqual(payload.judgmentCount, 1)

        let recorded = try XCTUnwrap(transport.recorded.first)
        XCTAssertEqual(recorded.method, "POST")
        XCTAssertEqual(recorded.path, "/api/v1/captures/capture_123/judgments")
        XCTAssertEqual(recorded.operationID, "ColorMatchingWeb.CaptureController.upload_judgments")

        let json = try jsonObject(from: recorded.body)
        let judgments = try array(json, "judgments")
        XCTAssertEqual(judgments.count, 1)
        let judgmentJSON = try XCTUnwrap(judgments.first)
        XCTAssertEqual(try string(judgmentJSON, "pair_id"), "pair_1")
        XCTAssertEqual(try string(judgmentJSON, "judgment"), "near_match")
    }
}
