import Foundation
import GeneratedClient
import OpenAPIRuntime
import OpenAPIURLSession
import XCTest

enum GeneratedClientStubbing {
    static let baseURL = URL(string: "https://example.test")!

    static func makeClient(token: String? = "token") -> Client {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [GeneratedClientMockURLProtocol.self]
        if let token {
            configuration.httpAdditionalHeaders = ["Authorization": "Bearer \(token)"]
        }
        return Client(
            serverURL: baseURL,
            transport: URLSessionTransport(
                configuration: .init(session: URLSession(configuration: configuration))
            )
        )
    }

    static func jsonResponse(status: Int, url: URL?, _ payload: String) -> (HTTPURLResponse, Data) {
        let response = HTTPURLResponse(
            url: url ?? baseURL,
            statusCode: status,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )
        return (response!, Data(payload.utf8))
    }

    static func jsonObject(from data: Data?) throws -> Any {
        try JSONSerialization.jsonObject(with: data!)
    }

    static func readBody(of request: URLRequest) -> Data {
        if let httpBody = request.httpBody {
            return httpBody
        }
        guard let stream = request.httpBodyStream else {
            return Data()
        }
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 1024)
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

final class GeneratedClientMockURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        do {
            let (response, data) = try Self.handler!(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
