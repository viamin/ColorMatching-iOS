import Foundation
import XCTest

/// A `URLProtocol` that answers every intercepted request from a stub handler.
///
/// The generated OpenAPI client and the hand-written client both talk to the
/// network through `URLSession`, so a stubbed transport exercises the real
/// request/response cycle without a live server.
final class StubURLProtocol: URLProtocol {
    /// The canned reply handed back to the client under test.
    struct Stub {
        var statusCode: Int
        var body: Data
        var headers: [String: String]

        init(statusCode: Int, json: String) {
            self.statusCode = statusCode
            self.body = Data(json.utf8)
            self.headers = ["Content-Type": "application/json"]
        }

        init(statusCode: Int) {
            self.statusCode = statusCode
            self.body = Data()
            self.headers = [:]
        }
    }

    /// The handler consulted for every intercepted request.
    static var handler: ((URLRequest) throws -> Stub)?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        do {
            let stub = try XCTUnwrap(Self.handler)(request)
            let response = HTTPURLResponse(
                url: request.url ?? URL(string: "https://example.test")!,
                statusCode: stub.statusCode,
                httpVersion: nil,
                headerFields: stub.headers
            )!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: stub.body)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}

    /// Reads the body of a captured request, whether the transport buffered it or streamed it.
    static func body(of request: URLRequest) -> Data? {
        request.httpBodyStream.flatMap(readStream) ?? request.httpBody
    }

    private static func readStream(_ stream: InputStream) -> Data? {
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 1024)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            if count > 0 {
                data.append(buffer, count: count)
            } else {
                break
            }
        }
        return data
    }
}
