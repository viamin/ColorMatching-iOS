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

    // Success status codes published by viamin/color_matching (PR #113):
    // capture creation answers 201; reads and uploads answer 200 with a JSON body.
    private static let expectedSuccessStatuses: [String: String] = [
        "get /api/v1/test_sheets/recent": "200",
        "get /api/v1/test_sheets/{sheet_id}/manifest": "200",
        "get /api/v1/test_sheets/{sheet_id}/ranked_results": "200",
        "post /api/v1/test_sheets/{sheet_id}/captures": "201",
        "post /api/v1/captures/{capture_id}/measurements": "200",
        "post /api/v1/captures/{capture_id}/judgments": "200"
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
        for operation in Self.expectedOperations {
            let operationObject = try Self.operation(operation.path, operation.method)
            XCTAssertNotNil(operationObject["responses"])
        }
    }

    func testEveryAppOperationDeclaresSpecSuccessStatusWithJSONBody() throws {
        for operation in Self.expectedOperations {
            let key = "\(operation.method) \(operation.path)"
            let expectedStatus = Self.expectedSuccessStatuses[key] ?? "200"
            let operationObject = try Self.operation(operation.path, operation.method)
            let responses = try XCTUnwrap(operationObject["responses"] as? [String: Any])
            let success = try XCTUnwrap(
                responses[expectedStatus] as? [String: Any],
                "\(operation.method.uppercased()) \(operation.path) must declare status \(expectedStatus)"
            )
            let content = try XCTUnwrap(
                success["content"] as? [String: Any],
                "\(operation.method.uppercased()) \(operation.path) status \(expectedStatus) must carry a JSON body"
            )
            XCTAssertNotNil(
                content["application/json"],
                "\(operation.method.uppercased()) \(operation.path) status \(expectedStatus) must be application/json"
            )
        }
    }

    func testUploadOperationsDeclareJSONRequestBody() throws {
        let uploadOperations = Self.expectedOperations.filter { $0.method == "post" }
        for operation in uploadOperations {
            let operationObject = try Self.operation(operation.path, operation.method)
            let requestBody = try XCTUnwrap(
                operationObject["requestBody"] as? [String: Any],
                "\(operation.method.uppercased()) \(operation.path) must declare a requestBody"
            )
            let content = try XCTUnwrap(requestBody["content"] as? [String: Any])
            XCTAssertNotNil(
                content["application/json"],
                "\(operation.method.uppercased()) \(operation.path) requestBody must be application/json"
            )
        }
    }

    func testEveryAppOperationRequiresBearerAuth() throws {
        for operation in Self.expectedOperations {
            let operationObject = try Self.operation(operation.path, operation.method)
            let security = try XCTUnwrap(
                operationObject["security"] as? [[String: Any]],
                "\(operation.method.uppercased()) \(operation.path) must declare security requirements"
            )
            XCTAssertTrue(
                security.contains { $0["bearerAuth"] != nil },
                "\(operation.method.uppercased()) \(operation.path) must require the bearerAuth scheme"
            )
        }
    }

    func testVendoredSpecMatchesUpstreamOperationCountAtLeast() throws {
        let paths = try Self.paths()
        let operationCount = paths.values.reduce(0) { count, value in
            count + Self.methodKeys(in: value).count
        }
        XCTAssertGreaterThanOrEqual(operationCount, Self.expectedOperations.count)
    }

    private static func operation(_ path: String, _ method: String) throws -> [String: Any] {
        let paths = try Self.paths()
        let pathItem = try XCTUnwrap(
            paths[path] as? [String: Any],
            "vendored spec is missing path \(path)"
        )
        return try XCTUnwrap(
            pathItem[method] as? [String: Any],
            "vendored spec is missing \(method.uppercased()) \(path)"
        )
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
