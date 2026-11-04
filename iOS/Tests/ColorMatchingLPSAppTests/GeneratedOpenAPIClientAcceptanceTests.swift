import Foundation
import XCTest
@testable import ColorMatchingLPSAppCore

final class GeneratedOpenAPIClientAcceptanceTests: XCTestCase {
    func testVendoredOpenAPISpecDefinesEveryAppOperation() throws {
        let specURL = repositoryRoot
            .appending(path: "iOS")
            .appending(path: "OpenAPI")
            .appending(path: "color-matching-openapi.json")

        XCTAssertTrue(FileManager.default.fileExists(atPath: specURL.path), "Vendor the published /api/v1/openapi.json before generating the client.")

        let data = try Data(contentsOf: specURL)
        let document = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let paths = try XCTUnwrap(document["paths"] as? [String: Any])

        for path in [
            "/api/v1/test_sheets/recent",
            "/api/v1/test_sheets/{sheet_id}/manifest",
            "/api/v1/test_sheets/{sheet_id}/captures",
            "/api/v1/captures/{capture_id}/measurements",
            "/api/v1/captures/{capture_id}/judgments",
            "/api/v1/test_sheets/{sheet_id}/ranked_results"
        ] {
            XCTAssertNotNil(paths[path], "Missing generated-client operation for \(path)")
        }
    }

    func testManifestAndRecentSheetsDecodeLocalPublishedResponses() async throws {
        var requestedPaths: [String] = []
        StubURLProtocol.handler = { request in
            requestedPaths.append(try XCTUnwrap(request.url?.path))

            switch request.url?.path {
            case "/api/v1/test_sheets/SHEET-1/manifest":
                return Self.response(for: request, status: 200, json: Self.manifestJSON)
            case "/api/v1/test_sheets/recent":
                return Self.response(for: request, status: 200, json: """
                {"sheets":[{"sheet_id":"SHEET-1","manifest_url":"https://example.test/api/v1/test_sheets/SHEET-1/manifest","title":null}]}
                """)
            default:
                throw URLError(.badURL)
            }
        }

        let api = client()
        let baseURL = try XCTUnwrap(URL(string: "https://example.test"))
        let manifest = try await api.fetchManifest(baseURL: baseURL, sheetCode: "SHEET-1")
        let sheets = try await api.fetchRecentSheets(baseURL: baseURL)

        XCTAssertEqual(manifest.sheetID, "SHEET-1")
        XCTAssertEqual(sheets.map(\.sheetID), ["SHEET-1"])
        XCTAssertEqual(requestedPaths, ["/api/v1/test_sheets/SHEET-1/manifest", "/api/v1/test_sheets/recent"])
    }

    override func tearDown() {
        StubURLProtocol.handler = nil
        super.tearDown()
    }

    private var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func client() -> APIClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return APIClient(token: "token", session: URLSession(configuration: configuration))
    }

    private static func response(for request: URLRequest, status: Int, json: String) -> (HTTPURLResponse, Data) {
        (
            HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!,
            Data(json.utf8)
        )
    }

    private static let manifestJSON = """
    {"schema_version":"lps-sheet-manifest/v1","sheet_version":"lps-letter-grid-v1","sheet_id":"SHEET-1","manifest_url":"https://example.test/api/v1/test_sheets/SHEET-1/manifest","created_at":"2026-07-25T12:00:00Z","page":{"units":"mm","width":215.9,"height":279.4},"registration_markers":[],"printer_profile":{"printer_make_model":"Printer","paper_type":"Paper","ink_type":"Ink"},"patches":[],"pairs":[]}
    """
}

private final class StubURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        do {
            let (response, data) = try XCTUnwrap(Self.handler)(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
