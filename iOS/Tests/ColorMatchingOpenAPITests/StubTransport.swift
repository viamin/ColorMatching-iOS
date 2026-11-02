import Foundation
import HTTPTypes
import OpenAPIRuntime
import XCTest

/// A request captured by ``StubTransport``.
struct RecordedRequest: Sendable, Equatable {
    var operationID: String
    var method: String
    var path: String
    var headerFields: [String: String]
    var body: Data?

    var bodyJSON: [String: Any] {
        get throws {
            guard let body else { return [:] }
            let object = try JSONSerialization.jsonObject(with: body)
            return try XCTUnwrap(object as? [String: Any], "request body is not a JSON object")
        }
    }
}

/// A `ClientTransport` that records generated-client requests and answers
/// them from a stubbed handler, so tests exercise the generated client
/// without contacting a live server.
final class StubTransport: ClientTransport, @unchecked Sendable {
    private let lock = NSLock()
    private let handler: @Sendable (HTTPRequest, String) throws -> (HTTPResponse, HTTPBody?)
    private var _recordedRequests: [RecordedRequest] = []

    var recordedRequests: [RecordedRequest] {
        lock.lock()
        defer { lock.unlock() }
        return _recordedRequests
    }

    init(handler: @escaping @Sendable (HTTPRequest, String) throws -> (HTTPResponse, HTTPBody?)) {
        self.handler = handler
    }

    func send(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String
    ) async throws -> (HTTPResponse, HTTPBody?) {
        let collectedBody: Data?
        if let body {
            collectedBody = try await Data(collecting: body, upTo: 1_048_576)
        } else {
            collectedBody = nil
        }
        lock.lock()
        defer { lock.unlock() }
        _recordedRequests.append(
            RecordedRequest(
                operationID: operationID,
                method: request.method.rawValue,
                path: request.path,
                headerFields: Dictionary(
                    request.headerFields.map { ($0.name, $0.value) },
                    uniquingKeysWith: { first, _ in first }
                ),
                body: collectedBody
            )
        )
        return try handler(request, operationID)
    }
}

extension StubTransport {
    /// Builds a stubbed JSON response, mirroring what the Phoenix app sends.
    static func jsonResponse(_ status: HTTPResponse.Status, _ json: String) -> (HTTPResponse, HTTPBody?) {
        (
            HTTPResponse(status: status, headerFields: [.contentType: "application/json"]),
            HTTPBody(Data(json.utf8))
        )
    }
}
