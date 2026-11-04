import Foundation
import XCTest
@testable import ColorMatchingLPSAppCore

final class OpenAPIIntegrationContractTests: XCTestCase {
    func testSheetReadOperationsDecodeStubbedResponses() async throws {
        let manifestResponse = """
        {
          "schema_version":"lps-sheet-manifest/v1",
          "sheet_version":"lps-letter-grid-v1",
          "sheet_id":"sheet_1",
          "manifest_url":"https://example.test/api/v1/test_sheets/sheet_1/manifest",
          "page":{"units":"mm","width":215.9,"height":279.4},
          "registration_markers":[],
          "patches":[],
          "pairs":[]
        }
        """
        let recentSheetsResponse = """
        {"sheets":[{"sheet_id":"sheet_1","manifest_url":"https://example.test/api/v1/test_sheets/sheet_1/manifest","title":"October sheet"}]}
        """

        MockURLProtocol.handler = { request in
            switch request.url?.path {
            case "/api/v1/test_sheets/sheet_1/manifest":
                return (Self.response(for: request), Data(manifestResponse.utf8))
            case "/api/v1/test_sheets/recent":
                return (Self.response(for: request), Data(recentSheetsResponse.utf8))
            default:
                throw URLError(.badURL)
            }
        }
        defer { MockURLProtocol.handler = nil }

        let manifest = try await client().fetchManifest(
            baseURL: URL(string: "https://example.test")!,
            sheetCode: "sheet_1"
        )
        let sheets = try await client().fetchRecentSheets(baseURL: URL(string: "https://example.test")!)

        XCTAssertEqual(manifest.sheetID, "sheet_1")
        XCTAssertEqual(sheets.map(\.sheetID), ["sheet_1"])
        XCTAssertEqual(sheets.first?.title, "October sheet")
    }

    func testPackageConfiguresGenerationAndRuntimeDependencies() throws {
        let package = try sourceFile(named: "Package.swift")

        XCTAssertTrue(package.contains("swift-openapi-generator"))
        XCTAssertTrue(package.contains("swift-openapi-runtime"))
        XCTAssertTrue(package.contains("OpenAPIGenerator"))
    }

    func testPublishedSpecIsVendoredAndCoversEveryAppOperation() throws {
        let data = try Data(contentsOf: packageRoot.appending(path: "OpenAPI/color-matching-api.json"))
        let document = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let paths = try XCTUnwrap(document["paths"] as? [String: Any])

        XCTAssertEqual(document["openapi"] as? String, "3.0.0")
        XCTAssertNotNil(paths["/api/v1/test_sheets/recent"])
        XCTAssertNotNil(paths["/api/v1/test_sheets/{sheet_id}/manifest"])
        XCTAssertNotNil(paths["/api/v1/test_sheets/{sheet_id}/captures"])
        XCTAssertNotNil(paths["/api/v1/captures/{capture_id}/measurements"])
        XCTAssertNotNil(paths["/api/v1/captures/{capture_id}/judgments"])
        XCTAssertNotNil(paths["/api/v1/test_sheets/{sheet_id}/ranked_results"])
    }

    func testAPIBoundaryUsesGeneratedTypesInsteadOfHandWrittenWireModels() throws {
        let source = try sourceFile(named: "Sources/ColorMatchingLPSAppCore/APIClient.swift")

        XCTAssertTrue(source.contains("import ColorMatchingOpenAPI"))
        XCTAssertFalse(source.contains("public struct CaptureMetadata"))
        XCTAssertFalse(source.contains("public struct CaptureSessionResponse"))
        XCTAssertFalse(source.contains("public struct RecentSheet"))
        XCTAssertFalse(source.contains("public struct PairJudgment"))
    }

    private func client() -> APIClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        return APIClient(token: "token", session: URLSession(configuration: configuration))
    }

    private static func response(for request: URLRequest) -> HTTPURLResponse {
        HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
    }

    private var packageRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func sourceFile(named name: String) throws -> String {
        try String(contentsOf: packageRoot.appending(path: name), encoding: .utf8)
    }
}
