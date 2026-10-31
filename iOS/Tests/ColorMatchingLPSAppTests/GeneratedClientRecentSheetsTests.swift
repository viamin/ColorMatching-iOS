import Foundation
import GeneratedClient
import XCTest

final class GeneratedClientRecentSheetsTests: XCTestCase {
    override func tearDown() {
        GeneratedClientMockURLProtocol.handler = nil
        super.tearDown()
    }

    func testRecentSheetsDecodesNullableTitle() async throws {
        var capturedRequest: URLRequest?
        GeneratedClientMockURLProtocol.handler = { request in
            capturedRequest = request
            return GeneratedClientStubbing.jsonResponse(
                status: 200,
                url: request.url,
                #"{"sheets":[{"sheet_id":"sheet_123","manifest_url":"https://example.test/api/v1/test_sheets/sheet_123/manifest","title":null}]}"#
            )
        }

        let output = try await GeneratedClientStubbing.makeClient()
            .listRecentTestSheets(.init())

        XCTAssertEqual(capturedRequest?.url?.path, "/api/v1/test_sheets/recent")
        XCTAssertEqual(capturedRequest?.httpMethod, "GET")
        XCTAssertEqual(capturedRequest?.value(forHTTPHeaderField: "Authorization"), "Bearer token")
        guard case .ok(let response) = output else {
            return XCTFail("Expected .ok output, got \(output)")
        }
        let sheets = try response.body.json.sheets
        XCTAssertEqual(sheets.map(\.sheet_id), ["sheet_123"])
        XCTAssertEqual(
            sheets.first?.manifest_url,
            "https://example.test/api/v1/test_sheets/sheet_123/manifest"
        )
        XCTAssertNil(sheets.first?.title)
    }
}
