import Foundation
import GeneratedClient
import XCTest

final class GeneratedClientManifestTests: XCTestCase {
    override func tearDown() {
        GeneratedClientMockURLProtocol.handler = nil
        super.tearDown()
    }

    func testManifestDecodesVersionedSchemaAndSendsAuthorizedGET() async throws {
        var capturedRequest: URLRequest?
        GeneratedClientMockURLProtocol.handler = { request in
            capturedRequest = request
            return GeneratedClientStubbing.jsonResponse(
                status: 200,
                url: request.url,
                #"{"schema_version":"lps-sheet-manifest/v1","sheet_id":"sheet_1","capture_profile":{"scoring_algorithm_version":"lps-distance-v1"},"sheet_version":"lps-letter-grid-v1","patches":[{"id":"patch_1","role":"pair_color"}]}"#
            )
        }

        let output = try await GeneratedClientStubbing.makeClient()
            .getTestSheetManifest(.init(path: .init(sheet_id: "sheet_1")))

        XCTAssertEqual(capturedRequest?.url?.path, "/api/v1/test_sheets/sheet_1/manifest")
        XCTAssertEqual(capturedRequest?.httpMethod, "GET")
        XCTAssertEqual(capturedRequest?.value(forHTTPHeaderField: "Authorization"), "Bearer token")
        guard case .ok(let response) = output else {
            return XCTFail("Expected .ok output, got \(output)")
        }
        let manifest = try response.body.json
        XCTAssertEqual(manifest.schema_version.rawValue, "lps-sheet-manifest/v1")
        XCTAssertEqual(manifest.sheet_id, "sheet_1")
        XCTAssertEqual(
            manifest.capture_profile.scoring_algorithm_version.rawValue,
            "lps-distance-v1"
        )
    }

    func testManifestMapsNotFoundResponse() async throws {
        GeneratedClientMockURLProtocol.handler = { request in
            GeneratedClientStubbing.jsonResponse(
                status: 404,
                url: request.url,
                #"{"errors":{"detail":"Sheet not found"}}"#
            )
        }

        let output = try await GeneratedClientStubbing.makeClient()
            .getTestSheetManifest(.init(path: .init(sheet_id: "missing")))

        guard case .notFound = output else {
            return XCTFail("Expected .notFound output, got \(output)")
        }
    }
}
