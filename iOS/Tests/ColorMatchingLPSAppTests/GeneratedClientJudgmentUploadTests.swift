import Foundation
import GeneratedClient
import XCTest

final class GeneratedClientJudgmentUploadTests: XCTestCase {
    override func tearDown() {
        GeneratedClientMockURLProtocol.handler = nil
        super.tearDown()
    }

    func testUploadJudgmentsEncodesPairJudgmentsAndDecodesCount() async throws {
        var capturedRequest: URLRequest?
        var capturedBody: Data?
        GeneratedClientMockURLProtocol.handler = { request in
            capturedRequest = request
            capturedBody = GeneratedClientStubbing.readBody(of: request)
            return GeneratedClientStubbing.jsonResponse(
                status: 200,
                url: request.url,
                #"{"capture_id":"cap_1","judgment_count":1}"#
            )
        }

        let output = try await GeneratedClientStubbing.makeClient().uploadJudgments(
            .init(
                path: .init(capture_id: "cap_1"),
                body: .json(
                    .init(
                        judgments: [
                            .init(pair_id: "pair_1", judgment: "near_match")
                        ]
                    )
                )
            )
        )

        XCTAssertEqual(capturedRequest?.httpMethod, "POST")
        XCTAssertEqual(capturedRequest?.url?.path, "/api/v1/captures/cap_1/judgments")
        XCTAssertEqual(
            capturedRequest?.value(forHTTPHeaderField: "Content-Type"),
            "application/json"
        )
        XCTAssertEqual(capturedRequest?.value(forHTTPHeaderField: "Authorization"), "Bearer token")
        guard case .ok(let response) = output else {
            return XCTFail("Expected .ok output, got \(output)")
        }
        let accepted = try response.body.json
        XCTAssertEqual(accepted.capture_id, "cap_1")
        XCTAssertEqual(accepted.judgment_count, 1)
        let json = try XCTUnwrap(
            GeneratedClientStubbing.jsonObject(from: capturedBody) as? [String: Any]
        )
        let judgment = try XCTUnwrap((json["judgments"] as? [[String: Any]])?.first)
        XCTAssertEqual(judgment["pair_id"] as? String, "pair_1")
        XCTAssertEqual(judgment["judgment"] as? String, "near_match")
    }

    func testUploadJudgmentsMapsUnprocessableEntity() async throws {
        GeneratedClientMockURLProtocol.handler = { request in
            GeneratedClientStubbing.jsonResponse(
                status: 422,
                url: request.url,
                #"{"errors":{"judgments":[{"pair_id":"pair_2","index":1,"errors":["is invalid"]}]}}"#
            )
        }

        let output = try await GeneratedClientStubbing.makeClient().uploadJudgments(
            .init(
                path: .init(capture_id: "cap_1"),
                body: .json(.init(judgments: [.init(pair_id: "pair_2", judgment: "bogus")]))
            )
        )

        guard case .unprocessableContent = output else {
            return XCTFail("Expected .unprocessableContent output, got \(output)")
        }
    }
}
