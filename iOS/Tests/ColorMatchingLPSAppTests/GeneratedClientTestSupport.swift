import Foundation
import HTTPTypes
import OpenAPIRuntime
import XCTest

// Test support for exercising the swift-openapi-generator client (module
// `ColorMatchingOpenAPI`) against local stubbed responses. No live server is
// contacted: every request is answered by `StubbedResponseTransport`.
//
// Method names used by the tests (e.g. `getColorMatchingWebTestSheetControllerManifest`)
// are derived mechanically from the verbatim operationIds in the vendored spec
// (`ColorMatchingWeb.TestSheetController.manifest` and friends). See
// docs/openapi-client-migration.md for the full derivation table.

/// A `ClientTransport` that records outgoing requests and answers them with a
/// canned `HTTPResponse`, following the testing pattern documented by
// swift-openapi-runtime.
struct StubbedResponseTransport: ClientTransport {
    var respond: @Sendable (HTTPRequest, HTTPBody?, String) async throws -> (HTTPResponse, HTTPBody?)

    func send(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String
    ) async throws -> (HTTPResponse, HTTPBody?) {
        try await respond(request, body, operationID)
    }
}

/// Middleware that injects the shared bearer token, mirroring the documented
/// OpenAPIRuntime authentication pattern used by the app.
struct BearerTokenMiddleware: ClientMiddleware {
    var token: String

    func intercept(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String,
        next: @Sendable (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
    ) async throws -> (HTTPResponse, HTTPBody?) {
        var request = request
        request.headerFields[.authorization] = "Bearer \(token)"
        return try await next(request, body, baseURL)
    }
}

/// A thread-safe record of the requests the generated client produced, so tests
/// can assert on method, path, headers, and encoded JSON bodies.
final class RecordedRequests: @unchecked Sendable {
    struct Entry {
        var method: HTTPRequest.Method
        var path: String
        var authorization: String?
        var contentType: String?
        var operationID: String
        var body: Data?
    }

    private let lock = NSLock()
    private var entries: [Entry] = []

    func record(_ request: HTTPRequest, body: HTTPBody?, operationID: String) async {
        let bodyData = try? await body.map { try Data(collecting: $0, upTo: 1 << 20) }
        lock.lock()
        defer { lock.unlock() }
        entries.append(
            Entry(
                method: request.method,
                path: request.path,
                authorization: request.headerFields[.authorization],
                contentType: request.headerFields[.contentType],
                operationID: operationID,
                body: bodyData
            )
        )
    }

    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return entries.count
    }

    var first: Entry? {
        lock.lock()
        defer { lock.unlock() }
        return entries.first
    }
}

enum StubbedResponse {
    /// Builds a JSON HTTP response from a string literal fixture.
    static func json(
        _ payload: String,
        status: HTTPRequest.Status = .ok
    ) -> (HTTPResponse, HTTPBody?) {
        (
            HTTPResponse(status: status, headerFields: [.contentType: "application/json"]),
            HTTPBody(Data(payload.utf8))
        )
    }
}

enum Fixture {
    /// Manifest as actually rendered by the Phoenix app
    /// (`ColorMatchingWeb.TestSheetJSON.manifest/1`). Only the fields typed in
    /// the published spec (`schema_version`, `sheet_id`, `capture_profile`)
    /// are decodable by the generated client; the remaining keys are ignored.
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
            "printer_make_model": "SureColor P700",
            "paper_type": "Premium Luster",
            "ink_type": "UltraChrome PRO10",
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

    /// Recent sheets as rendered by the server; `title` is always present and
    /// currently `null`, which the published spec allows via `nullable: true`.
    static let recentSheets = """
        {
          "sheets": [
            {
              "sheet_id": "sheet_123",
              "manifest_url": "https://example.test/api/v1/test_sheets/sheet_123/manifest",
              "title": null
            }
          ]
        }
        """

    /// Ranked results as rendered by the server. The published spec only types
    /// `schema_version` and `sheet_id`; the rich payload keys are ignored by
    /// the generated decoder today (recorded as a spec gap).
    static let rankedResults = """
        {
          "schema_version": "lps-ranked-results/v1",
          "sheet_id": "sheet_123",
          "printer_profile": {
            "printer_make_model": "SureColor P700",
            "paper_type": "Premium Luster",
            "ink_type": "UltraChrome PRO10",
            "icc_profile": null,
            "print_settings": {},
            "driver_name": null,
            "driver_version": null,
            "calibration_date": null,
            "calibration_version": null,
            "notes": null
          },
          "capture_count": 2,
          "latest_capture_at": "2026-07-25T12:00:00Z",
          "earliest_capture_at": "2026-07-20T09:30:00Z",
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
                "latest": 0.03,
                "minimum": 0.02,
                "maximum": 0.05,
                "capture_count": 2,
                "sample_count": 2,
                "algorithm_versions": ["lps-distance-v1"]
              },
              "current_judgment": "near_match",
              "current_judgment_observed_at": "2026-07-25T12:05:00Z",
              "observation_count": 1,
              "latest_observation": {"judgment": "near_match", "observed_at": "2026-07-25T12:05:00Z"},
              "capture_count": 2,
              "latest_capture_at": "2026-07-25T12:00:00Z",
              "earliest_capture_at": "2026-07-20T09:30:00Z"
            }
          ]
        }
        """
}
