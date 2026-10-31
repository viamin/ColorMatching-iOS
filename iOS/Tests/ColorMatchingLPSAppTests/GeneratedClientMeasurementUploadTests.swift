import Foundation
import GeneratedClient
import XCTest

final class GeneratedClientMeasurementUploadTests: XCTestCase {
    override func tearDown() {
        GeneratedClientMockURLProtocol.handler = nil
        super.tearDown()
    }

    func testUploadMeasurementsEncodesRgbObjectsScoresAndDecodesCounts() async throws {
        var capturedRequest: URLRequest?
        var capturedBody: Data?
        GeneratedClientMockURLProtocol.handler = { request in
            capturedRequest = request
            capturedBody = GeneratedClientStubbing.readBody(of: request)
            return GeneratedClientStubbing.jsonResponse(
                status: 200,
                url: request.url,
                #"{"capture_id":"cap_1","measurement_count":1,"pair_score_count":1}"#
            )
        }

        let output = try await GeneratedClientStubbing.makeClient().uploadMeasurements(
            .init(
                path: .init(capture_id: "cap_1"),
                body: .json(
                    .init(
                        measurements: [
                            .init(
                                patch_id: "patch_1",
                                linear_rgb_median: .init(value2: .init(r: 0.2, g: 0.3, b: 0.4)),
                                normalized_linear_rgb_median: .init(
                                    value2: .init(r: 0.15, g: 0.12, b: 0.02)
                                )
                            )
                        ],
                        pair_scores: [
                            .init(
                                pair_id: "pair_1",
                                algorithm_version: "lps-distance-v1",
                                similarity: 0.9,
                                distance: 0.1
                            )
                        ]
                    )
                )
            )
        )

        XCTAssertEqual(capturedRequest?.httpMethod, "POST")
        XCTAssertEqual(capturedRequest?.url?.path, "/api/v1/captures/cap_1/measurements")
        XCTAssertEqual(
            capturedRequest?.value(forHTTPHeaderField: "Content-Type"),
            "application/json"
        )
        XCTAssertEqual(capturedRequest?.value(forHTTPHeaderField: "Authorization"), "Bearer token")
        guard case .ok(let response) = output else {
            return XCTFail("Expected .ok output, got \(output)")
        }
        let accepted = try response.body.json
        XCTAssertEqual(accepted.capture_id, "cap_1")
        XCTAssertEqual(accepted.measurement_count, 1)
        XCTAssertEqual(accepted.pair_score_count, 1)
        let json = try XCTUnwrap(
            GeneratedClientStubbing.jsonObject(from: capturedBody) as? [String: Any]
        )
        let measurement = try XCTUnwrap((json["measurements"] as? [[String: Any]])?.first)
        XCTAssertEqual(measurement["patch_id"] as? String, "patch_1")
        let median = try XCTUnwrap(measurement["linear_rgb_median"] as? [String: Double])
        XCTAssertEqual(median["r"] ?? 0, 0.2, accuracy: 0.0001)
        XCTAssertEqual(median["g"] ?? 0, 0.3, accuracy: 0.0001)
        XCTAssertEqual(median["b"] ?? 0, 0.4, accuracy: 0.0001)
        let normalized = try XCTUnwrap(measurement["normalized_linear_rgb_median"] as? [String: Double])
        XCTAssertEqual(normalized["r"] ?? 0, 0.15, accuracy: 0.0001)
        XCTAssertEqual(normalized["g"] ?? 0, 0.12, accuracy: 0.0001)
        XCTAssertEqual(normalized["b"] ?? 0, 0.02, accuracy: 0.0001)
        let score = try XCTUnwrap((json["pair_scores"] as? [[String: Any]])?.first)
        XCTAssertEqual(score["pair_id"] as? String, "pair_1")
        XCTAssertEqual(score["algorithm_version"] as? String, "lps-distance-v1")
        XCTAssertEqual(score["similarity"] as? Double ?? 0, 0.9, accuracy: 0.0001)
        XCTAssertEqual(score["distance"] as? Double ?? 0, 0.1, accuracy: 0.0001)
    }
}
