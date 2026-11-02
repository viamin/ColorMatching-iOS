import Foundation
import HTTPTypes
import OpenAPIRuntime
import XCTest

import ColorMatchingLPSAPI

typealias StubHandler = @Sendable (
    HTTPRequest,
    HTTPBody?,
    URL,
    String
) async throws -> (HTTPResponse, HTTPBody?)

struct StubTransport: ClientTransport {
    let handler: StubHandler

    func send(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String
    ) async throws -> (HTTPResponse, HTTPBody?) {
        try await handler(request, body, baseURL, operationID)
    }
}

enum StubError: Error {
    case missingRecordedRequestBody(String)
}

struct RecordedRequest {
    let request: HTTPRequest
    let body: Data
}

final class RequestRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var recorded: [String: RecordedRequest] = [:]

    func record(_ request: HTTPRequest, body: HTTPBody?, operationID: String) async {
        let entry = RecordedRequest(request: request, body: await Self.collected(body))
        lock.lock()
        defer { lock.unlock() }
        recorded[operationID] = entry
    }

    func request(_ operationID: String) -> HTTPRequest? {
        lock.lock()
        defer { lock.unlock() }
        return recorded[operationID]?.request
    }

    func bodyData(_ operationID: String) -> Data? {
        lock.lock()
        defer { lock.unlock() }
        return recorded[operationID]?.body
    }

    func jsonDictionary(_ operationID: String) throws -> [String: Any] {
        guard let data = bodyData(operationID) else {
            throw StubError.missingRecordedRequestBody(operationID)
        }
        return try JSONSerialization.jsonObject(with: data) as! [String: Any]
    }

    private static func collected(_ body: HTTPBody?) async -> Data {
        guard let body else { return Data() }
        return (try? await Data(collecting: body, upTo: 1 << 20)) ?? Data()
    }
}

extension HTTPResponse {
    static func stubbedJSON(
        _ status: HTTPResponse.Status,
        _ payload: String
    ) -> (HTTPResponse, HTTPBody) {
        (
            HTTPResponse(status: status, headerFields: [.contentType: "application/json"]),
            HTTPBody(payload)
        )
    }
}

class GeneratedClientTestCase: XCTestCase {
    func makeClient(_ handler: @escaping StubHandler) -> Client {
        Client(
            serverURL: URL(string: "https://example.test")!,
            transport: StubTransport(handler: handler)
        )
    }
}

enum Fixtures {
    static let manifestCreatedAt = ISO8601DateFormatter().date(from: "2026-07-25T12:00:00Z")!

    static let manifest = #"""
    {
      "schema_version": "lps-sheet-manifest/v1",
      "sheet_version": "lps-letter-grid-v1",
      "sheet_id": "sheet_1",
      "manifest_url": "https://example.test/api/v1/test_sheets/sheet_1/manifest",
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
        },
        {
          "id": "patch_2",
          "role": "pair_color",
          "pair_id": "pair_1",
          "pair_side": "second",
          "reference_role": null,
          "source_color": "#00FF00",
          "safe_inset_mm": 1.5,
          "rect": {"x": 16, "y": 50, "width": 16, "height": 10}
        },
        {
          "id": "patch_3",
          "role": "reference",
          "pair_id": null,
          "pair_side": null,
          "reference_role": "gray",
          "source_color": null,
          "safe_inset_mm": 1.5,
          "rect": {"x": 16, "y": 62, "width": 16, "height": 10}
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
    """#

    static let manifestWithUnknownPatchRole = #"""
    {
      "schema_version": "lps-sheet-manifest/v1",
      "sheet_version": "lps-letter-grid-v1",
      "sheet_id": "sheet_1",
      "manifest_url": "https://example.test/api/v1/test_sheets/sheet_1/manifest",
      "created_at": "2026-07-25T12:00:00Z",
      "page": {"units": "mm", "width": 215.9, "height": 279.4},
      "registration_markers": [],
      "patches": [
        {
          "id": "patch_1",
          "role": "saturated",
          "pair_id": "pair_1",
          "pair_side": "first",
          "reference_role": null,
          "source_color": "#FF0000",
          "safe_inset_mm": 1.5,
          "rect": {"x": 16, "y": 38, "width": 16, "height": 10}
        }
      ],
      "pairs": []
    }
    """#

    static let recentSheets = #"""
    {
      "sheets": [
        {
          "sheet_id": "sheet_1",
          "manifest_url": "https://example.test/api/v1/test_sheets/sheet_1/manifest",
          "title": "July LPS comparison sheet"
        },
        {
          "sheet_id": "sheet_2",
          "manifest_url": "https://example.test/api/v1/test_sheets/sheet_2/manifest",
          "title": null
        }
      ]
    }
    """#

    static let rankedResults = #"""
    {
      "sheet_id": "sheet_1",
      "scoring_algorithm_version": "lps-distance-v1",
      "printer_profile": {
        "id": "printer_profile_1",
        "name": "Research printer",
        "paper": "paper name",
        "ink": "ink set",
        "settings": {}
      },
      "results": [
        {
          "pair_id": "pair_1",
          "source_colors": ["#FF0000", "#00FF00"],
          "distance": 0.035,
          "similarity": 0.965,
          "algorithm_version": "lps-distance-v1",
          "capture_id": "capture_123",
          "judgment": "near_match"
        }
      ]
    }
    """#
}
