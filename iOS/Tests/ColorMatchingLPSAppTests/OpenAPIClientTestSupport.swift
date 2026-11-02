import Foundation
import HTTPTypes
import OpenAPIRuntime
import XCTest

/// A `ClientTransport` that never touches the network.
///
/// The generated `ColorMatchingOpenAPI.Client` is driven entirely by the
/// handler closure, so the generated client tests run against local stubbed
/// responses with no live server (CI has none).
struct StubbedTransport: ClientTransport {
    typealias Handler = @Sendable (
        _ request: HTTPRequest,
        _ body: HTTPBody?,
        _ baseURL: URL,
        _ operationID: String
    ) async throws -> (HTTPResponse, HTTPBody?)

    private let handler: Handler

    init(handler: @escaping Handler) {
        self.handler = handler
    }

    func send(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String
    ) async throws -> (HTTPResponse, HTTPBody?) {
        try await handler(request, body, baseURL, operationID)
    }
}

/// Builds a canned JSON HTTP response for the stubbed transport.
func stubbedJSONResponse(_ json: String, status: HTTPResponse.Status) -> (HTTPResponse, HTTPBody?) {
    let response = HTTPResponse(
        status: status,
        headerFields: [.init(name: .contentType, value: "application/json")]
    )
    return (response, HTTPBody(json))
}

/// Collects a request body and parses it as a JSON object, failing the test
/// when the body is missing or not an object.
func jsonObject(
    from body: HTTPBody?,
    file: StaticString = #filePath,
    line: UInt = #line
) async throws -> [String: Any] {
    let chunk = try await HTTPBody.ByteChunk(collecting: XCTUnwrap(body, file: file, line: line), upTo: 1 << 20)
    let object = try? JSONSerialization.jsonObject(with: Data(chunk))
    guard let dictionary = object as? [String: Any] else {
        XCTFail("Request body is not a JSON object: \(String(decoding: chunk, as: UTF8.self))", file: file, line: line)
        throw StubbedTransportError.notAnObject
    }
    return dictionary
}

enum StubbedTransportError: Error {
    case notAnObject
}

final class Captured<T>: @unchecked Sendable {
    var value: T?
}
