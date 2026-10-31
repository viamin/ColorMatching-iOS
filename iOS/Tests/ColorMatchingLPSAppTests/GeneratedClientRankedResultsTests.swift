import Foundation
import GeneratedClient
import XCTest

final class GeneratedClientRankedResultsTests: XCTestCase {
    override func tearDown() {
        GeneratedClientMockURLProtocol.handler = nil
        super.tearDown()
    }

    func testRankedResultsDecodesVersionedSchemaAndIgnoresUndocumentedFields() async throws {
        var capturedRequest: URLRequest?
        GeneratedClientMockURLProtocol.handler = { request in
            capturedRequest = request
            return GeneratedClientStubbing.jsonResponse(
                status: 200,
                url: request.url,
                #"{"schema_version":"lps-ranked-results/v1","sheet_id":"sheet_1","pairs":[{"pair_id":"pair_1","similarity":0.9}]}"#
            )
        }

        let output = try await GeneratedClientStubbing.makeClient()
            .getRankedResults(.init(path: .init(sheet_id: "sheet_1")))

        XCTAssertEqual(capturedRequest?.url?.path, "/api/v1/test_sheets/sheet_1/ranked_results")
        XCTAssertEqual(capturedRequest?.httpMethod, "GET")
        XCTAssertEqual(capturedRequest?.value(forHTTPHeaderField: "Authorization"), "Bearer token")
        guard case .ok(let response) = output else {
            return XCTFail("Expected .ok output, got \(output)")
        }
        let results = try response.body.json
        XCTAssertEqual(results.schema_version.rawValue, "lps-ranked-results/v1")
        XCTAssertEqual(results.sheet_id, "sheet_1")
    }
}
