import Foundation
import MeasurementCore
import XCTest
@testable import ColorMatchingLPSAppCore

enum APIFixtures {
    static let manifestJSON = Data(
        """
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
            "id": 7,
            "printer_make_model": "Canon PIXMA Pro-200",
            "paper_type": "Ilford Galerie Smooth Pearl",
            "ink_type": "CLI-42 dye",
            "icc_profile": null,
            "print_settings": {"quality": "high"},
            "driver_name": null,
            "driver_version": null,
            "calibration_date": "2026-07-01",
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
            },
            {
              "id": "pair_1#second",
              "role": "pair_color",
              "pair_id": "pair_1",
              "pair_side": "second",
              "reference_role": null,
              "source_color": "#00FF00",
              "safe_inset_mm": 1.5,
              "rect": {"x": 34, "y": 38, "width": 16, "height": 10}
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
        """.utf8
    )

    static let recentSheetsJSON = Data(
        """
        {
          "sheets": [
            {
              "sheet_id": "sheet_1",
              "manifest_url": "https://example.test/api/v1/test_sheets/sheet_1/manifest",
              "title": null
            },
            {
              "sheet_id": "sheet_2",
              "manifest_url": "https://example.test/api/v1/test_sheets/sheet_2/manifest",
              "title": "July LPS comparison sheet"
            }
          ]
        }
        """.utf8
    )

    static let rankedResultsJSON = Data(
        """
        {
          "schema_version": "lps-ranked-results/v1",
          "sheet_id": "sheet_1",
          "printer_profile": {
            "id": 7,
            "printer_make_model": "Canon PIXMA Pro-200",
            "paper_type": "Ilford Galerie Smooth Pearl",
            "ink_type": "CLI-42 dye",
            "icc_profile": null,
            "print_settings": {"quality": "high"},
            "driver_name": null,
            "driver_version": null,
            "calibration_date": "2026-07-01",
            "calibration_version": null,
            "notes": null
          },
          "capture_count": 2,
          "latest_capture_at": "2026-07-25T12:30:00Z",
          "earliest_capture_at": "2026-07-24T12:00:00Z",
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
                "average": 0.04,
                "latest": 0.05,
                "minimum": 0.03,
                "maximum": 0.05,
                "capture_count": 2,
                "sample_count": 4,
                "algorithm_versions": ["lps-distance-v1"]
              },
              "current_judgment": "near_match",
              "current_judgment_observed_at": "2026-07-25T12:31:00Z",
              "observation_count": 1,
              "latest_observation": {"judgment": "near_match", "observed_at": "2026-07-25T12:31:00Z"},
              "capture_count": 2,
              "latest_capture_at": "2026-07-25T12:30:00Z",
              "earliest_capture_at": "2026-07-24T12:00:00Z"
            }
          ]
        }
        """.utf8
    )

    static let captureCreatedJSON = Data(#"{"capture_id": "42"}"#.utf8)

    static let measurementUploadResponseJSON = Data(
        #"{"capture_id": "42", "measurement_count": 1, "pair_score_count": 1}"#.utf8
    )

    static let judgmentUploadResponseJSON = Data(
        #"{"capture_id": "42", "judgment_count": 1}"#.utf8
    )

    static let errorJSON = Data(#"{"errors": {"detail": "Unauthorized"}}"#.utf8)
}

func stubbedClient(token: String = "token") -> APIClient {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [MockURLProtocol.self]
    return APIClient(token: token, session: URLSession(configuration: configuration))
}

func jsonBody(of request: URLRequest?) throws -> [String: Any] {
    let data = request?.httpBody ?? request?.httpBodyStream.map(HTTPRequestBodyReader.read)
    return try JSONSerialization.jsonObject(with: XCTUnwrap(data)) as! [String: Any]
}

enum HTTPResponseBodyReader {
    static func read(from stream: InputStream) -> Data {
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 1024)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            if count > 0 {
                data.append(buffer, count)
            } else {
                break
            }
        }
        return data
    }
}

enum StubResponse {
    static func ok(_ body: Data, status: Int = 200, for request: URLRequest) throws -> (HTTPURLResponse, Data) {
        try make(status: status, body: body, for: request)
    }

    static func make(status: Int, body: Data = Data(), for request: URLRequest) throws -> (HTTPURLResponse, Data) {
        guard let url = request.url,
              let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: ["Content-Type": "application/json"]) else {
            throw URLError(.badServerResponse)
        }
        return (response, body)
    }
}

final class MockURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        do {
            let (response, data) = try XCTUnwrap(Self.handler)(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
