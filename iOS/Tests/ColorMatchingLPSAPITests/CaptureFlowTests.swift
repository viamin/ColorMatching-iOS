import XCTest

import ColorMatchingLPSAPI

final class CaptureFlowTests: GeneratedClientTestCase {
    func testCreateCaptureSessionPostsContractPayload() async throws {
        let recorder = RequestRecorder()
        let client = makeClient { request, body, _, operationID in
            await recorder.record(request, body: body, operationID: operationID)
            return HTTPResponse.stubbedJSON(.created, #"{"capture_id":"capture_123"}"#)
        }

        let response = try await client.createCaptureSession(
            .init(path: .init(sheet_id: "sheet_1"), body: .json(makeCapturePayload()))
        )

        XCTAssertEqual(try response.created.body.json.capture_id, "capture_123")
        let request = try XCTUnwrap(recorder.request("createCaptureSession"))
        XCTAssertEqual(request.method, .post)
        XCTAssertEqual(request.path, "/api/v1/test_sheets/sheet_1/captures")
        XCTAssertTrue(request.headerFields[.contentType]?.hasPrefix("application/json") == true)
        assertCaptureBody(try recorder.jsonDictionary("createCaptureSession"))
    }

    func testUploadMeasurementsPostsScoresAndStats() async throws {
        let recorder = RequestRecorder()
        let client = makeClient { request, body, _, operationID in
            await recorder.record(request, body: body, operationID: operationID)
            return (HTTPResponse(status: .noContent), nil)
        }

        let response = try await client.uploadMeasurements(
            .init(path: .init(capture_id: "capture_123"), body: .json(makeMeasurementPayload()))
        )

        guard case .noContent = response else {
            return XCTFail("Expected 204 noContent for measurement upload.")
        }
        let request = try XCTUnwrap(recorder.request("uploadMeasurements"))
        XCTAssertEqual(request.path, "/api/v1/captures/capture_123/measurements")
        assertMeasurementBody(try recorder.jsonDictionary("uploadMeasurements"))
    }

    func testUploadJudgmentsPostsTypedJudgments() async throws {
        let recorder = RequestRecorder()
        let client = makeClient { request, body, _, operationID in
            await recorder.record(request, body: body, operationID: operationID)
            return (HTTPResponse(status: .noContent), nil)
        }

        let response = try await client.uploadJudgments(
            .init(
                path: .init(capture_id: "capture_123"),
                body: .json(.init(judgments: [.init(pair_id: "pair_1", judgment: .near_match)]))
            )
        )

        guard case .noContent = response else {
            return XCTFail("Expected 204 noContent for judgment upload.")
        }
        XCTAssertEqual(recorder.request("uploadJudgments")?.path, "/api/v1/captures/capture_123/judgments")
        let json = try recorder.jsonDictionary("uploadJudgments")
        let judgment = try XCTUnwrap((json["judgments"] as? [[String: Any]])?.first)
        XCTAssertEqual(judgment["pair_id"] as? String, "pair_1")
        XCTAssertEqual(judgment["judgment"] as? String, "near_match")
    }

    private func makeCapturePayload() -> Components.Schemas.CreateCaptureSessionRequest {
        Components.Schemas.CreateCaptureSessionRequest(
            metadata: makeMetadata(),
            quality: .init(detected_marker_count: 4, blur_score: 0.82, rejections: [])
        )
    }

    private func makeMetadata() -> Components.Schemas.CaptureMetadata {
        Components.Schemas.CaptureMetadata(
            device_model: "iPhone",
            lens: "wide",
            exposure_duration_seconds: 0.016,
            iso: 100,
            focus_lens_position: 0.42,
            white_balance_gains: .init(red: 1.2, green: 1.0, blue: 1.4),
            image_width: 4032,
            image_height: 3024,
            app_version: "0.1.0",
            timestamp: Date(timeIntervalSince1970: 0)
        )
    }

    private func makeMeasurementPayload() -> Components.Schemas.MeasurementUploadRequest {
        Components.Schemas.MeasurementUploadRequest(
            scoring_algorithm_version: "lps-distance-v1",
            measurements: [makeMeasurement()],
            pair_scores: [
                .init(
                    pair_id: "pair_1",
                    distance: 0.035,
                    similarity: 0.965,
                    algorithm_version: "lps-distance-v1"
                )
            ]
        )
    }

    private func makeMeasurement() -> Components.Schemas.PatchMeasurementUpload {
        Components.Schemas.PatchMeasurementUpload(
            patch_id: "patch_1",
            linear_rgb_median: .init(r: 0.12, g: 0.1, b: 0.02),
            normalized_linear_rgb_median: .init(r: 0.15, g: 0.12, b: 0.02),
            stats: .init(
                sample_count: 900,
                clipping_fraction: 0,
                mean: .init(r: 0.12, g: 0.1, b: 0.02),
                standard_deviation: .init(r: 0.01, g: 0.01, b: 0.004)
            )
        )
    }

    private func assertCaptureBody(_ json: [String: Any]) {
        let metadata = json["metadata"] as! [String: Any]
        XCTAssertEqual(metadata["device_model"] as? String, "iPhone")
        XCTAssertEqual(metadata["lens"] as? String, "wide")
        XCTAssertEqual(metadata["timestamp"] as? String, "1970-01-01T00:00:00Z")
        XCTAssertEqual(metadata["image_width"] as? Int, 4032)
        let gains = metadata["white_balance_gains"] as! [String: Any]
        XCTAssertEqual(gains["red"] as? Double, 1.2)
        let quality = json["quality"] as! [String: Any]
        XCTAssertEqual(quality["detected_marker_count"] as? Int, 4)
        XCTAssertEqual(quality["rejections"] as? [String], [])
    }

    private func assertMeasurementBody(_ json: [String: Any]) throws {
        XCTAssertEqual(json["scoring_algorithm_version"] as? String, "lps-distance-v1")
        let measurement = try XCTUnwrap((json["measurements"] as? [[String: Any]])?.first)
        XCTAssertEqual(measurement["patch_id"] as? String, "patch_1")
        let stats = try XCTUnwrap(measurement["stats"] as? [String: Any])
        XCTAssertEqual(Set(stats.keys), ["sample_count", "clipping_fraction", "mean", "standard_deviation"])
        XCTAssertEqual((json["pair_scores"] as? [[String: Any]])?.first?["pair_id"] as? String, "pair_1")
    }
}
