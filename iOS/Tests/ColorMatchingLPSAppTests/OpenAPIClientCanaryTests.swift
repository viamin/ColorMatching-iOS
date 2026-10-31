import Foundation
import OpenAPIRuntime
import ColorMatchingOpenAPI
import XCTest

final class OpenAPIClientCanaryTests: XCTestCase {
    func testGeneratedModuleExposesClientInitializedWithURLSessionTransport() {
        let configuration = URLSessionConfiguration.ephemeral
        let session = URLSession(configuration: configuration)
        let transport = URLSessionTransport(configuration: .init(session: session))

        let client = ColorMatchingOpenAPI.Client(
            serverURL: URL(string: "https://example.test")!,
            transport: transport
        )

        XCTAssertTrue(client is ColorMatchingOpenAPI.Client)
    }
}
