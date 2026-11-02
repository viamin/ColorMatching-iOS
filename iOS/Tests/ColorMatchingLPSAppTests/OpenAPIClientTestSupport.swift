import Foundation
import OpenAPIRuntime
import XCTest

struct RecordedHTTPRequest {
    let operationID: String
    let method: String
    let path: String
    let authorization: String?
    let contentType: String?
    let bodyData: Data?
}

enum StubTransportError: Error {
    case noStubbedResponse
}

final class StubTransport: ClientTransport, @unchecked Sendable {
    private static let maximumBodyBytes = 1 << 20

    private let lock = NSLock()
    private var queuedResponses: [(HTTPResponse, HTTPBody?)] = []
    private var locked_recordedRequests: [RecordedHTTPRequest] = []

    func enqueue(_ response: (HTTPResponse, HTTPBody?)) {
        lock.lock()
        defer { lock.unlock() }
        queuedResponses.append(response)
    }

    var recordedRequests: [RecordedHTTPRequest] {
        lock.lock()
        defer { lock.unlock() }
        return locked_recordedRequests
    }

    func send(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String
    ) async throws -> (HTTPResponse, HTTPBody?) {
        let bodyData: Data?
        if let body {
            bodyData = try Data(collecting: body, upTo: Self.maximumBodyBytes)
        } else {
            bodyData = nil
        }
        lock.lock()
        defer { lock.unlock() }
        locked_recordedRequests.append(
            RecordedHTTPRequest(
                operationID: operationID,
                method: request.method.rawValue,
                path: request.path ?? "",
                authorization: request.headerFields[.authorization],
                contentType: request.headerFields[.contentType],
                bodyData: bodyData
            )
        )
        guard !queuedResponses.isEmpty else {
            throw StubTransportError.noStubbedResponse
        }
        return queuedResponses.removeFirst()
    }

    static func jsonResponse(statusCode: Int, payload: String) -> (HTTPResponse, HTTPBody?) {
        (
            HTTPResponse(
                status: .init(code: statusCode),
                headerFields: [.contentType: "application/json"]
            ),
            HTTPBody(Data(payload.utf8))
        )
    }
}

enum StubDates {
    private static let formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static func date(_ string: String) -> Date {
        guard let date = formatter.date(from: string) else {
            fatalError("Unparseable fixture date: \(string)")
        }
        return date
    }
}

extension XCTestCase {
    func decodeJSONObject(from data: Data?) throws -> [String: Any] {
        let object = try JSONSerialization.jsonObject(with: XCTUnwrap(data))
        return try XCTUnwrap(object as? [String: Any])
    }

    func doubleValue(_ object: [String: Any], _ key: String) throws -> Double {
        try XCTUnwrap(object[key] as? Double)
    }
}

enum Fixtures {
    static let manifest = #"""
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
        "print_settings": null,
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
    """#

    static let recentSheets = #"""
    {
      "sheets": [
        {
          "sheet_id": "sheet_123",
          "manifest_url": "https://example.test/api/v1/test_sheets/sheet_123/manifest",
          "title": null
        }
      ]
    }
    """#

    static let rankedResults = #"""
    {
      "schema_version": "lps-ranked-results/v1",
      "sheet_id": "sheet_123",
      "printer_profile": {
        "printer_make_model": "Research printer",
        "paper_type": "paper name",
        "ink_type": "ink set",
        "icc_profile": null,
        "print_settings": null,
        "driver_name": null,
        "driver_version": null,
        "calibration_date": null,
        "calibration_version": null,
        "notes": null
      },
      "capture_count": 2,
      "latest_capture_at": "2026-07-26T09:30:00Z",
      "earliest_capture_at": "2026-07-25T12:00:00Z",
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
            "average": 0.9,
            "latest": 0.95,
            "minimum": 0.85,
            "maximum": 0.95,
            "capture_count": 2,
            "sample_count": 2,
            "algorithm_versions": ["lps-distance-v1"]
          },
          "current_judgment": "near_match",
          "current_judgment_observed_at": "2026-07-26T09:31:00Z",
          "observation_count": 3,
          "latest_observation": {"judgment": "near_match", "observed_at": "2026-07-26T09:31:00Z"},
          "capture_count": 2,
          "latest_capture_at": "2026-07-26T09:30:00Z",
          "earliest_capture_at": "2026-07-25T12:00:00Z"
        }
      ]
    }
    """#

    static let captureCreated = #"{"capture_id": "cap_1"}"#

    static let measurementAccepted = #"{"capture_id": "cap_1", "measurement_count": 1, "pair_score_count": 1}"#

    static let judgmentsAccepted = #"{"capture_id": "cap_1", "judgment_count": 1}"#

    static let sheetNotFound = #"{"errors": {"detail": "Sheet not found"}}"#
}
