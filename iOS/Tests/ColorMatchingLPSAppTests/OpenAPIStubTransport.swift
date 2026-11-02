import ColorMatchingOpenAPI
import Foundation
import OpenAPIRuntime
import XCTest

struct RecordedClientRequest {
    let method: String
    let path: String
    let operationID: String
    let authorization: String?
    let contentType: String?
    let accept: String?
    let body: Data?
}

final class RecordingClientTransport: ClientTransport, @unchecked Sendable {
    enum StubResponse {
        case json(status: HTTPResponse.Status, body: String)
        case empty(status: HTTPResponse.Status)
    }

    var stub: StubResponse = .empty(status: .internalServerError)

    private let lock = NSLock()
    private var requests: [RecordedClientRequest] = []

    var recorded: [RecordedClientRequest] {
        lock.lock()
        defer { lock.unlock() }
        return requests
    }

    func send(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String
    ) async throws -> (HTTPResponse, HTTPBody?) {
        let collectedBody: Data?
        if let body {
            collectedBody = try await Data(collecting: body, upTo: 1 << 20)
        } else {
            collectedBody = nil
        }

        lock.lock()
        requests.append(
            RecordedClientRequest(
                method: request.method.rawValue,
                path: request.path ?? "",
                operationID: operationID,
                authorization: request.headerFields[.authorization],
                contentType: request.headerFields[.contentType],
                accept: request.headerFields[.accept],
                body: collectedBody
            )
        )
        let stub = self.stub
        lock.unlock()

        switch stub {
        case .json(let status, let body):
            var response = HTTPResponse(status: status)
            response.headerFields[.contentType] = "application/json"
            return (response, HTTPBody(body))
        case .empty(let status):
            return (HTTPResponse(status: status), nil)
        }
    }
}

extension XCTestCase {
    func makeGeneratedClient(
        stub: RecordingClientTransport.StubResponse,
        middlewares: [any ClientMiddleware] = []
    ) -> (ColorMatchingOpenAPI.Client, RecordingClientTransport) {
        let transport = RecordingClientTransport()
        transport.stub = stub
        let client = ColorMatchingOpenAPI.Client(
            serverURL: URL(string: "https://example.test")!,
            transport: transport,
            middlewares: middlewares
        )
        return (client, transport)
    }
}

extension XCTestCase {
    func jsonObject(from data: Data?) throws -> [String: Any] {
        let object = try JSONSerialization.jsonObject(with: XCTUnwrap(data))
        return try XCTUnwrap(object as? [String: Any])
    }

    func object(_ json: [String: Any], _ key: String) throws -> [String: Any] {
        try XCTUnwrap(json[key] as? [String: Any])
    }

    func array(_ json: [String: Any], _ key: String) throws -> [[String: Any]] {
        try XCTUnwrap(json[key] as? [[String: Any]])
    }

    func string(_ json: [String: Any], _ key: String) throws -> String {
        try XCTUnwrap(json[key] as? String)
    }

    func double(_ json: [String: Any], _ key: String) throws -> Double {
        try XCTUnwrap(json[key] as? Double)
    }
}

enum GeneratedClientFixtures {
    static let fullManifestJSON = """
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
          "capture_profile": {"scoring_algorithm_version": "lps-distance-v1"},
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
        """

    static let recentSheetsJSON = """
        {
          "sheets": [
            {
              "sheet_id": "sheet_123",
              "manifest_url": "https://example.test/api/v1/test_sheets/sheet_123/manifest",
              "title": "July LPS comparison sheet"
            },
            {
              "sheet_id": "sheet_124",
              "manifest_url": "https://example.test/api/v1/test_sheets/sheet_124/manifest",
              "title": null
            }
          ]
        }
        """

    static let rankedResultsJSON = """
        {
          "schema_version": "lps-ranked-results/v1",
          "sheet_id": "sheet_123",
          "results": [{"pair_id": "pair_1", "similarity": 0.965}]
        }
        """

    static let captureCreatedJSON = """
        {"capture_id": "capture_123"}
        """

    static let measurementUploadAcceptedJSON = """
        {"capture_id": "capture_123", "measurement_count": 1, "pair_score_count": 1}
        """

    static let judgmentUploadAcceptedJSON = """
        {"capture_id": "capture_123", "judgment_count": 1}
        """

    static let errorJSON = """
        {"errors": {"detail": "Unauthorized"}}
        """
}
