import Foundation
import MeasurementCore
import XCTest
@testable import ColorMatchingLPSAppCore

/// Checks that the API layer is served by the generated OpenAPI client.
///
/// The generated client is the only component that knows how to negotiate a
/// media type or how to name the generated schema types, so both are asserted
/// through observable behaviour instead of through internal symbols.
final class GeneratedClientWiringTests: XCTestCase {
    override func tearDown() {
        StubURLProtocol.handler = nil
        super.tearDown()
    }

    func testCaptureRequestIsIssuedByTheGeneratedOpenAPIClient() async throws {
        var capturedRequest: URLRequest?
        StubURLProtocol.handler = { request in
            capturedRequest = request
            return StubURLProtocol.Stub(statusCode: 201, json: #"{"capture_id":"cap_1"}"#)
        }

        let response = try await client().createCapture(
            sheetID: "sheet_123",
            baseURL: URL(string: "https://example.test")!,
            metadata: try decodeValue(from: APIFixtures.captureMetadata),
            quality: CaptureQuality(detectedMarkerCount: 4, blurScore: 0.75, rejections: [])
        )

        let accept = capturedRequest?.value(forHTTPHeaderField: "Accept")
        XCTAssertTrue(
            accept?.contains("application/json") == true,
            "The generated OpenAPI client negotiates the response media type, got \(accept ?? "no Accept header")"
        )
        XCTAssertTrue(
            capturedRequest?.value(forHTTPHeaderField: "Content-Type")?.contains("application/json") == true,
            "The request body must be sent as JSON"
        )

        let typeName = String(describing: type(of: response))
        XCTAssertTrue(
            typeName.contains("Components") && typeName.contains("Schemas"),
            "The capture response must be a generated schema type, got \(typeName)"
        )
    }

    func testGeneratedClientSendsTheDocumentedSheetIdentifier() async throws {
        var capturedRequest: URLRequest?
        StubURLProtocol.handler = { request in
            capturedRequest = request
            return StubURLProtocol.Stub(statusCode: 200, json: APIFixtures.manifest)
        }

        _ = try await client().fetchManifest(baseURL: URL(string: "https://example.test")!, sheetCode: "sheet_123")

        XCTAssertEqual(capturedRequest?.url?.path, "/api/v1/test_sheets/sheet_123/manifest")
        XCTAssertEqual(capturedRequest?.httpMethod, "GET")
    }

    private func client() -> APIClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return APIClient(token: "token", session: URLSession(configuration: configuration))
    }
}
