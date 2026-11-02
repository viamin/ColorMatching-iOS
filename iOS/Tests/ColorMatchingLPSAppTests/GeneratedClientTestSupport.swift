import Foundation
import OpenAPIRuntime
import XCTest

enum GeneratedClientStubError: Error {
    case unexpectedRequest
}

enum GeneratedClientFixtures {
    static let manifest = ##"""
    {
      "schema_version": "lps-sheet-manifest/v1",
      "sheet_version": "lps-letter-grid-v1",
      "sheet_id": "sheet_123",
      "manifest_url": "https://example.test/api/v1/test_sheets/sheet_123/manifest",
      "created_at": "2026-07-25T12:00:00Z",
      "page": {"units": "mm", "width": 215.9, "height": 279.4},
      "registration_markers": [
        {"role": "top_left", "shape": "solid_square", "rect": {"x": 12, "y": 12, "width": 8, "height": 8}}
      ],
      "printer_profile": {
        "id": "printer_profile_1",
        "name": "Research printer",
        "paper": "paper name",
        "ink": "ink set",
        "settings": {}
      },
      "capture_profile": {
        "expected_illuminant": "low_pressure_sodium",
        "preferred_camera": "built_in_wide_angle_rear",
        "scoring_algorithm_version": "lps-distance-v1"
      },
      "patches": [
        {
          "id": "patch_1",
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
          "first_patch_id": "patch_1",
          "second_patch_id": "patch_2",
          "source_colors": ["#FF0000", "#00FF00"],
          "grid_row": 0,
          "grid_col": 1
        }
      ]
    }
    """##

    static let recentSheets = ##"""
    {
      "sheets": [
        {
          "sheet_id": "sheet_123",
          "manifest_url": "https://example.test/api/v1/test_sheets/sheet_123/manifest",
          "title": "July LPS comparison sheet"
        },
        {
          "sheet_id": "sheet_456",
          "manifest_url": "https://example.test/api/v1/test_sheets/sheet_456/manifest",
          "title": null
        }
      ]
    }
    """##

    static let rankedResults = ##"""
    {
      "schema_version": "lps-ranked-results/v1",
      "sheet_id": "sheet_123",
      "scoring_algorithm_version": "lps-distance-v1",
      "results": [
        {
          "pair_id": "pair_1",
          "rank": 1,
          "source_colors": ["#FF0000", "#00FF00"],
          "distance": 0.035,
          "similarity": 0.965,
          "judgment": "near_match",
          "capture_id": "capture_123"
        }
      ]
    }
    """##

    static let captureSession = #"{"capture_id": "cap_123"}"#
}

enum GeneratedClientStubs {
    static func json(_ payload: String, status: Int) -> (HTTPResponse, HTTPBody) {
        var fields = HTTPFields()
        fields.append(HTTPField(name: "Content-Type", value: "application/json"))
        return (HTTPResponse(statusCode: status, headerFields: fields), HTTPBody(Data(payload.utf8)))
    }

    static func noContent() -> (HTTPResponse, HTTPBody) {
        return (HTTPResponse(statusCode: 204, headerFields: HTTPFields()), HTTPBody(Data()))
    }
}

final class RecordingTransport: ClientTransport, @unchecked Sendable {
    private let lock = NSLock()
    private(set) var requests: [HTTPRequest] = []
    private(set) var bodies: [Data] = []
    private(set) var baseURLs: [URL] = []
    private(set) var operationIDs: [String] = []
    var responder: (HTTPRequest, String) throws -> (HTTPResponse, HTTPBody)

    init(responder: @escaping (HTTPRequest, String) throws -> (HTTPResponse, HTTPBody) = { _, _ in
        throw GeneratedClientStubError.unexpectedRequest
    }) {
        self.responder = responder
    }

    func send(_ request: HTTPRequest, body: HTTPBody, baseURL: URL, operationID: String) async throws -> (HTTPResponse, HTTPBody) {
        let data = try await Self.collectedData(from: body)
        lock.lock()
        defer { lock.unlock() }
        requests.append(request)
        bodies.append(data)
        baseURLs.append(baseURL)
        operationIDs.append(operationID)
        return try responder(request, operationID)
    }

    static func collectedData(from body: HTTPBody) async throws -> Data {
        let collected = try await body.collect(upTo: 1 << 20)
        return collected.data ?? Data()
    }
}
