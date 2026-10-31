import Foundation
import OpenAPIRuntime

/// Records outgoing generated-client requests and answers them with canned
/// responses, so `GeneratedClientTests` exercises the generated client with
/// no live server.
///
/// Written against swift-openapi-runtime 1.x, where `Request.body`/`Response.body`
/// are `Data?`. If the package pins an older runtime, adapt the body handling
/// (e.g. `HTTPBody` collection) — the recorded-request assertions are the
/// binding contract, not the transport internals.
final class OpenAPIStubTransport: Transport, @unchecked Sendable {
    struct Recorded: Equatable {
        let method: String
        let path: String
        let operationID: String
        let authorization: String?
        let contentType: String?
        let body: Data?
    }

    private let lock = NSLock()
    private var recordedRequests: [Recorded] = []
    private let respond: (Recorded) throws -> Response

    init(respond: @escaping (Recorded) throws -> Response) {
        self.respond = respond
    }

    var recorded: [Recorded] {
        lock.withLock { recordedRequests }
    }

    func send(_ request: Request, baseURL: URL, operationID: String) async throws -> Response {
        let entry = Recorded(
            method: request.method.raw,
            path: request.path,
            operationID: operationID,
            authorization: request.headerFields[.authorization],
            contentType: request.headerFields[.contentType],
            body: request.body
        )
        lock.withLock { recordedRequests.append(entry) }
        return try respond(entry)
    }
}

extension OpenAPIStubTransport {
    static func json(_ status: Response.Status, _ json: String) -> Response {
        Response(
            status: status,
            headerFields: [.init(name: .contentType, value: "application/json")],
            body: Data(json.utf8)
        )
    }

    static func noContent() -> Response {
        Response(status: .noContent)
    }
}
