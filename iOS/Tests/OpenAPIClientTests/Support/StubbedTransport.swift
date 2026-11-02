import Foundation
import OpenAPIGeneratedClient
import OpenAPIRuntime

/// Records the outgoing `URLRequest` produced by the generated client so tests
/// can assert on the exact wire format (path, method, JSON body).
final class RequestRecorder: @unchecked Sendable {
    private(set) var request: URLRequest?

    func record(_ request: URLRequest) {
        self.request = request
    }
}

/// URLProtocol-backed HTTP stub: generated-client tests never touch a live
/// server (issue #5 requires stubbed responses in CI).
final class StubURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        do {
            let (response, data) = try Self.handler?(request) ?? unexpectedResponse
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}

    private var unexpectedResponse: (HTTPURLResponse, Data) {
        (HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!, Data())
    }
}

enum StubbedTransport {
    static let serverURL = URL(string: "https://example.test")!

    /// Builds a generated `Client` whose HTTP traffic hits `StubURLProtocol`,
    /// which replies with `status`/`body` for every request it receives.
    static func client(
        status: Int,
        body: Data,
        willSend: ((URLRequest) -> Void)? = nil
    ) -> OpenAPIGeneratedClient.Client {
        StubURLProtocol.handler = { request in
            willSend?(request)
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: status,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, body)
        }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return OpenAPIGeneratedClient.Client(
            serverURL: serverURL,
            transport: URLSessionTransport(urlSession: URLSession(configuration: configuration))
        )
    }
}

enum StubbedRequestBody {
    static func json(from request: URLRequest?) throws -> [String: Any] {
        guard let data = data(from: request),
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(
                domain: "StubbedRequestBody",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "No JSON body captured on stubbed request"]
            )
        }
        return json
    }

    private static func data(from request: URLRequest?) -> Data? {
        guard let request else { return nil }
        if let body = request.httpBody { return body }
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
