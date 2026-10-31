import XCTest

final class VendoredOpenAPISpecTests: XCTestCase {
    private static let expectedOperations: [(path: String, method: String)] = [
        ("/api/v1/test_sheets/recent", "get"),
        ("/api/v1/test_sheets/{sheet_id}/manifest", "get"),
        ("/api/v1/test_sheets/{sheet_id}/ranked_results", "get"),
        ("/api/v1/test_sheets/{sheet_id}/captures", "post"),
        ("/api/v1/captures/{capture_id}/measurements", "post"),
        ("/api/v1/captures/{capture_id}/judgments", "post")
    ]

    func testVendoredOpenAPIDocumentExists() throws {
        let document = try Self.vendoredDocument()
        XCTAssertFalse(document.text.isEmpty)
        XCTAssertTrue(document.url.pathExtension.lowercased() == "json")
    }

    func testVendoredSpecDeclaresOpenAPI3() throws {
        let spec = try Self.spec()
        let version = try XCTUnwrap(spec["openapi"] as? String)
        XCTAssertTrue(version.hasPrefix("3."), "expected OpenAPI 3.x, found \(version)")
    }

    func testVendoredSpecCoversEveryAppSurface() throws {
        let paths = try Self.paths()
        for operation in Self.expectedOperations {
            let pathItem = try XCTUnwrap(
                paths[operation.path],
                "vendored spec is missing path \(operation.path)"
            )
            let operationObject = try XCTUnwrap(
                (pathItem as? [String: Any])?[operation.method],
                "vendored spec is missing \(operation.method.uppercased()) \(operation.path)"
            )
            let responses = try XCTUnwrap(
                (operationObject as? [String: Any])?["responses"],
                "\(operation.method.uppercased()) \(operation.path) has no responses"
            )
            XCTAssertNotNil(responses)
        }
    }

    func testVendoredSpecMatchesUpstreamOperationCountAtLeast() throws {
        let paths = try Self.paths()
        let operationCount = paths.values.reduce(0) { count, value in
            count + Self.methodKeys(in: value).count
        }
        XCTAssertGreaterThanOrEqual(operationCount, Self.expectedOperations.count)
    }

    private static func methodKeys(in pathItem: Any) -> [String] {
        guard let dictionary = pathItem as? [String: Any] else {
            return []
        }
        return ["get", "post", "put", "patch", "delete"].filter { dictionary[$0] != nil }
    }

    private static func packageRoot() -> URL {
        URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private static func vendoredDocument() throws -> OpenAPIDocument {
        try OpenAPIDocumentLocator.vendoredDocument(packageRoot: packageRoot())
    }

    private static func spec() throws -> [String: Any] {
        try vendoredDocument().jsonObject()
    }

    private static func paths() throws -> [String: Any] {
        try XCTUnwrap(spec()["paths"] as? [String: Any])
    }
}
