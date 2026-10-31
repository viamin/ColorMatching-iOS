import Foundation
import GeneratedClient
import XCTest

final class GeneratedClientCaptureCreationTests: XCTestCase {
    override func tearDown() {
        GeneratedClientMockURLProtocol.handler = nil
        super.tearDown()
    }

    func testCreateCaptureEncodesMetadataAndQualityAndDecodesCaptureID() async throws {
        var capturedRequest: URLRequest?
        var capturedBody: Data?
        GeneratedClientMockURLProtocol.handler = { request in
            capturedRequest = request
            capturedBody = GeneratedClientStubbing.readBody(of: request)
            return GeneratedClientStubbing.jsonResponse(
                status: 201,
                url: request.url,
                #"{"capture_id":"cap_1"}"#
            )
        }

        let output = try await GeneratedClientStubbing.makeClient().createCapture(
            .init(
                path: .init(sheet_id: "sheet_1"),
                body: .json(
                    .init(
                        metadata: .init(
                            device_model: "iPhone",
                            lens: "wide",
                            exposure_duration_seconds: 0.01,
                            iso: 100,
                            focus_lens_position: 0.4,
                            image_width: 4032,
                            image_height: 3024,
                            app_version: "0.1.0",
                            timestamp: Date(timeIntervalSince1970: 0)
                        ),
                        quality: .init(
                            detected_marker_count: 4,
                            blur_score: 0.75,
                            rejections: []
                        )
                    )
                )
            )
        )

        XCTAssertEqual(capturedRequest?.httpMethod, "POST")
        XCTAssertEqual(capturedRequest?.url?.path, "/api/v1/test_sheets/sheet_1/captures")
        XCTAssertEqual(
            capturedRequest?.value(forHTTPHeaderField: "Content-Type"),
            "application/json"
        )
        XCTAssertEqual(capturedRequest?.value(forHTTPHeaderField: "Authorization"), "Bearer token")
        guard case .created(let response) = output else {
            return XCTFail("Expected .created output, got \(output)")
        }
        XCTAssertEqual(try response.body.json.capture_id, "cap_1")
        let json = try XCTUnwrap(
            GeneratedClientStubbing.jsonObject(from: capturedBody) as? [String: Any]
        )
        let metadata = try XCTUnwrap(json["metadata"] as? [String: Any])
        XCTAssertEqual(metadata["device_model"] as? String, "iPhone")
        XCTAssertEqual(metadata["lens"] as? String, "wide")
        XCTAssertEqual(metadata["exposure_duration_seconds"] as? Double ?? 0, 0.01, accuracy: 0.0001)
        XCTAssertEqual(metadata["iso"] as? Int, 100)
        XCTAssertEqual(metadata["focus_lens_position"] as? Double ?? 0, 0.4, accuracy: 0.0001)
        XCTAssertEqual(metadata["image_width"] as? Int, 4032)
        XCTAssertEqual(metadata["image_height"] as? Int, 3024)
        XCTAssertEqual(metadata["app_version"] as? String, "0.1.0")
        XCTAssertEqual(metadata["timestamp"] as? String, "1970-01-01T00:00:00Z")
        let quality = try XCTUnwrap(json["quality"] as? [String: Any])
        XCTAssertEqual(quality["detected_marker_count"] as? Int, 4)
        XCTAssertEqual(quality["blur_score"] as? Double ?? 0, 0.75, accuracy: 0.0001)
        XCTAssertEqual(quality["rejections"] as? [String], [])
    }
}
