import Foundation
import XCTest

// Shared support for the generated OpenAPI client test target.
//
// Stubs are shaped after the real `color_matching` Phoenix responses
// (see docs/openapi-contract-deltas.md for the published-spec deltas these
// fixtures encode). No live server is required in CI.

enum Fixtures {
    // Mirrors ColorMatchingWeb.TestSheetJSON.manifest/1, including the
    // `pair_id#side` patch id convention and the printer_profile key names
    // that differ from the prose contract.
    // Uses `##` raw delimiters because the payload contains `"#` sequences
    // (hex colors like "#FF0000" and `pair_id#side` patch ids).
    static let manifestJSON = data(##"""
    {
      "schema_version": "lps-sheet-manifest/v1",
      "sheet_id": "sheet_123",
      "sheet_version": "lps-letter-grid-v1",
      "manifest_url": "https://example.test/api/v1/test_sheets/sheet_123/manifest",
      "created_at": "2026-07-25T12:00:00Z",
      "page": {"units": "mm", "width": 215.9, "height": 279.4},
      "registration_markers": [
        {"role": "top_left", "shape": "solid_square", "rect": {"x": 12, "y": 12, "width": 8, "height": 8}}
      ],
      "printer_profile": {
        "printer_make_model": "Research printer",
        "paper_type": "plain",
        "ink_type": "dye",
        "icc_profile": null,
        "print_settings": {},
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
        },
        {
          "id": "pair_1#second",
          "role": "pair_color",
          "pair_id": "pair_1",
          "pair_side": "second",
          "reference_role": null,
          "source_color": "#00FF00",
          "safe_inset_mm": 1.5,
          "rect": {"x": 36, "y": 38, "width": 16, "height": 10}
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
    """##)

    // Mirrors ColorMatchingWeb.TestSheetJSON.render_recent_sheet/1 —
    // `title` is always null in the current upstream renderer.
    static let recentSheetsJSON = data(#"""
    {
      "sheets": [
        {
          "sheet_id": "sheet_123",
          "manifest_url": "https://example.test/api/v1/test_sheets/sheet_123/manifest",
          "title": null
        }
      ]
    }
    """#)

    // Mirrors ColorMatchingWeb.TestSheetJSON.ranked_results/2. The published
    // RankedResults schema only guarantees schema_version + sheet_id; the
    // extra rendered fields must decode without breaking the generated client.
    static let rankedResultsJSON = data(##"""
    {
      "schema_version": "lps-ranked-results/v1",
      "sheet_id": "sheet_123",
      "printer_profile": {
        "printer_make_model": "Research printer",
        "paper_type": "plain",
        "ink_type": "dye",
        "icc_profile": null,
        "print_settings": {},
        "driver_name": null,
        "driver_version": null,
        "calibration_date": null,
        "calibration_version": null,
        "notes": null
      },
      "capture_count": 2,
      "latest_capture_at": "2026-07-25T12:30:00Z",
      "earliest_capture_at": "2026-07-24T09:00:00Z",
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
            "average": 0.035,
            "latest": 0.035,
            "minimum": 0.03,
            "maximum": 0.04,
            "capture_count": 2,
            "sample_count": 2,
            "algorithm_versions": ["lps-distance-v1"]
          },
          "current_judgment": "near_match",
          "current_judgment_observed_at": "2026-07-25T12:35:00Z",
          "observation_count": 1,
          "latest_observation": {"judgment": "near_match", "observed_at": "2026-07-25T12:35:00Z"},
          "capture_count": 2,
          "latest_capture_at": "2026-07-25T12:30:00Z",
          "earliest_capture_at": "2026-07-24T09:00:00Z"
        }
      ]
    }
    """##)

    // Mirrors ColorMatchingWeb.CaptureController.create/2 — a 201 whose
    // capture_id is the stringified integer database id.
    static let captureCreatedJSON = data(#"{"capture_id": "421"}"#)

    // Mirrors ColorMatchingWeb.CaptureController.upload_measurements/2.
    static let measurementUploadResponseJSON = data("""
    {"capture_id": "421", "measurement_count": 2, "pair_score_count": 1}
    """)

    // Mirrors ColorMatchingWeb.CaptureController.upload_judgments/2.
    static let judgmentUploadResponseJSON = data("""
    {"capture_id": "421", "judgment_count": 1}
    """)

    // Mirrors the documented ApiErrorResponse object form.
    static let notFoundErrorJSON = data(#"{"errors": {"detail": "Sheet not found"}}"#)

    // A MeasurementUploadRequest payload (object-form RgbPayload channels)
    // used to build generated requests by decoding, mirroring what the app
    // sends today (stats + top-level scoring_algorithm_version included as
    // tolerated extra properties).
    static let measurementUploadRequestJSON = data(##"""
    {
      "scoring_algorithm_version": "lps-distance-v1",
      "measurements": [
        {
          "patch_id": "pair_1#first",
          "linear_rgb_median": {"r": 0.12, "g": 0.1, "b": 0.02},
          "normalized_linear_rgb_median": {"r": 0.15, "g": 0.12, "b": 0.02},
          "stats": {
            "sample_count": 900,
            "clipping_fraction": 0.0,
            "mean": {"r": 0.12, "g": 0.1, "b": 0.02},
            "standard_deviation": {"r": 0.01, "g": 0.01, "b": 0.004}
          }
        },
        {
          "patch_id": "pair_1#second",
          "linear_rgb_median": {"r": 0.11, "g": 0.09, "b": 0.02},
          "normalized_linear_rgb_median": {"r": 0.14, "g": 0.11, "b": 0.02},
          "stats": {
            "sample_count": 900,
            "clipping_fraction": 0.0,
            "mean": {"r": 0.11, "g": 0.09, "b": 0.02},
            "standard_deviation": {"r": 0.01, "g": 0.01, "b": 0.004}
          }
        }
      ],
      "pair_scores": [
        {"pair_id": "pair_1", "algorithm_version": "lps-distance-v1", "distance": 0.035, "similarity": 0.965}
      ]
    }
    """##)

    private static func data(_ json: String) -> Data {
        Data(json.utf8)
    }
}

final class StubbedURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        do {
            guard let handler = Self.handler else {
                throw StubError.noHandlerInstalled
            }
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}

    private enum StubError: Error {
        case noHandlerInstalled
    }
}

enum Stubbing {
    static func session() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubbedURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    static func jsonResponse(for request: URLRequest, status: Int, json: Data) -> (HTTPURLResponse, Data) {
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: status,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        return (response, json)
    }

    static func emptyResponse(for request: URLRequest, status: Int) -> (HTTPURLResponse, Data) {
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: status,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        return (response, Data())
    }
}

enum RequestBody {
    /// Reads a URLRequest body whether URLSession exposed it as httpBody or
    /// httpBodyStream (URLSessionTransport produces the stream form).
    static func data(of request: URLRequest) -> Data? {
        if let body = request.httpBody {
            return body
        }
        guard let stream = request.httpBodyStream else { return nil }
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
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

    static func jsonObject(of request: URLRequest) throws -> Any {
        let data = try XCTUnwrap(data(of: request))
        return try JSONSerialization.jsonObject(with: data)
    }
}
