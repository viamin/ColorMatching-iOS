import Foundation
import XCTest

// Test support for the generated-client contract suite.
//
// All responses are stubbed at the URLSession layer (MockURLProtocol) beneath
// URLSessionTransport, so no test ever performs network I/O. Fixtures mirror
// the published OpenAPI spec from viamin/color_matching#110 and the Phoenix
// app's actual JSON rendering (lib/color_matching_web/controllers/test_sheet_json.ex,
// capture_controller.ex). See docs/openapi-client-migration.md for the
// contract-delta table these fixtures encode.

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
            let handler = try XCTUnwrap(Self.handler)
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

/// Reference box for capturing the outgoing request from the stub handler
/// (the handler closure escapes, so `inout` capture is not possible).
final class RequestBox {
    var request: URLRequest?
    var body: Data?
}

enum Stubber {
    /// Routes each stubbed response by URL path suffix, e.g. "/manifest",
    /// recording the outgoing request into `box`.
    static func route(
        _ stubs: [String: (Int, String)],
        into box: RequestBox
    ) -> ((URLRequest) throws -> (HTTPURLResponse, Data)) {
        { incoming in
            box.request = incoming
            box.body = Self.readBody(of: incoming)
            let path = try XCTUnwrap(incoming.url?.path)
            let match = try XCTUnwrap(
                stubs.first { path.hasSuffix($0.key) },
                "No stub registered for path \(path)"
            )
            let response = HTTPURLResponse(
                url: try XCTUnwrap(incoming.url),
                statusCode: match.value.0,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, Data(match.value.1.utf8))
        }
    }

    static func readBody(of request: URLRequest) -> Data? {
        if let httpBody = request.httpBody {
            return httpBody
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
}

// MARK: - Wire fixtures (published spec + actual server rendering)

enum Fixtures {
    /// GET /api/v1/test_sheets/{sheet_id}/manifest — 200
    /// Rendered shape from TestSheetJSON.manifest/2. Note the deltas from the
    /// prose contract: printer_profile keys (D2) and "pair_id#side" patch ids (D3).
    static let manifest = """
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
        "paper_type": "paper name",
        "ink_type": "ink set",
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
          "rect": {"x": 40, "y": 38, "width": 16, "height": 10}
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
    """

    /// GET /api/v1/test_sheets/recent — 200 (title nullable; server renders null today, D4)
    static let recentSheets = """
    {
      "sheets": [
        {
          "sheet_id": "sheet_123",
          "manifest_url": "https://example.test/api/v1/test_sheets/sheet_123/manifest",
          "title": null
        },
        {
          "sheet_id": "sheet_456",
          "manifest_url": "https://example.test/api/v1/test_sheets/sheet_456/manifest",
          "title": "July LPS comparison sheet"
        }
      ]
    }
    """

    /// GET /api/v1/test_sheets/{sheet_id}/ranked_results — 200
    /// Spec declares only the envelope (schema_version, sheet_id); the server
    /// renders the richer aggregate shape below (D9/G3).
    static let rankedResults = """
    {
      "schema_version": "lps-ranked-results/v1",
      "sheet_id": "sheet_123",
      "printer_profile": {
        "printer_make_model": "Research printer",
        "paper_type": "paper name",
        "ink_type": "ink set",
        "icc_profile": null,
        "print_settings": {},
        "driver_name": null,
        "driver_version": null,
        "calibration_date": null,
        "calibration_version": null,
        "notes": null
      },
      "capture_count": 3,
      "latest_capture_at": "2026-07-25T12:00:00Z",
      "earliest_capture_at": "2026-07-01T09:00:00Z",
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
            "average": 0.03,
            "latest": 0.035,
            "minimum": 0.02,
            "maximum": 0.05,
            "capture_count": 3,
            "sample_count": 3,
            "algorithm_versions": ["lps-distance-v1"]
          },
          "current_judgment": "near_match",
          "current_judgment_observed_at": "2026-07-25T12:00:00Z",
          "observation_count": 1,
          "latest_observation": {"judgment": "near_match", "observed_at": "2026-07-25T12:00:00Z"},
          "capture_count": 3,
          "latest_capture_at": "2026-07-25T12:00:00Z",
          "earliest_capture_at": "2026-07-01T09:00:00Z"
        }
      ]
    }
    """

    /// POST /api/v1/test_sheets/{sheet_id}/captures — 201 (D5)
    static let captureCreated = #"{"capture_id": "42"}"#

    /// POST /api/v1/captures/{capture_id}/measurements — 200 with a JSON body (D7),
    /// not the 204 the hand-written layer assumed.
    static let measurementUploadResponse = """
    {"capture_id": "42", "measurement_count": 1, "pair_score_count": 1}
    """

    /// POST /api/v1/captures/{capture_id}/judgments — 200 with a JSON body (D8).
    static let judgmentUploadResponse = """
    {"capture_id": "42", "judgment_count": 2}
    """

    /// ApiErrorResponse (D10), json_render_error_v2 shape for a 422 on judgments.
    static let judgmentValidationError = """
    {"errors": {"judgments": [{"pair_id": "pair_9", "index": 0, "errors": {"judgment": ["is invalid"]}}]}}
    """

    /// ApiErrorResponse shape for 401/404.
    static let notFoundError = #"{"errors": {"detail": "Sheet not found"}}"#
    static let unauthorizedError = #"{"errors": {"detail": "Unauthorized"}}"#
}
