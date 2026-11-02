import Foundation
import XCTest

final class OpenAPISpecVendorTests: XCTestCase {
    private struct EndpointExpectation {
        let method: String
        let path: String
        let operationID: String
        let successStatus: String
        let responseSchemaTitle: String
        let expectsRequestBody: Bool
    }

    private struct SpecError: Error {}

    private static let endpoints: [EndpointExpectation] = [
        EndpointExpectation(
            method: "get",
            path: "/api/v1/test_sheets/recent",
            operationID: "ColorMatchingWeb.TestSheetController.recent",
            successStatus: "200",
            responseSchemaTitle: "RecentSheetsResponse",
            expectsRequestBody: false
        ),
        EndpointExpectation(
            method: "get",
            path: "/api/v1/test_sheets/{sheet_id}/manifest",
            operationID: "ColorMatchingWeb.TestSheetController.manifest",
            successStatus: "200",
            responseSchemaTitle: "TestSheetManifest",
            expectsRequestBody: false
        ),
        EndpointExpectation(
            method: "get",
            path: "/api/v1/test_sheets/{sheet_id}/ranked_results",
            operationID: "ColorMatchingWeb.TestSheetController.ranked_results",
            successStatus: "200",
            responseSchemaTitle: "RankedResults",
            expectsRequestBody: false
        ),
        EndpointExpectation(
            method: "post",
            path: "/api/v1/test_sheets/{sheet_id}/captures",
            operationID: "ColorMatchingWeb.CaptureController.create",
            successStatus: "201",
            responseSchemaTitle: "CaptureCreatedResponse",
            expectsRequestBody: true
        ),
        EndpointExpectation(
            method: "post",
            path: "/api/v1/captures/{capture_id}/measurements",
            operationID: "ColorMatchingWeb.CaptureController.upload_measurements",
            successStatus: "200",
            responseSchemaTitle: "MeasurementUploadResponse",
            expectsRequestBody: true
        ),
        EndpointExpectation(
            method: "post",
            path: "/api/v1/captures/{capture_id}/judgments",
            operationID: "ColorMatchingWeb.CaptureController.upload_judgments",
            successStatus: "200",
            responseSchemaTitle: "JudgmentUploadResponse",
            expectsRequestBody: true
        ),
    ]

    func testVendoredSpecDocumentExistsAtCanonicalPath() throws {
        _ = try loadSpecObject()
    }

    func testVendoredSpecDeclaresOpenAPI3AndInfo() throws {
        let spec = try loadSpecObject()
        let version = try XCTUnwrap(spec["openapi"] as? String, "Vendored spec is missing the top-level \"openapi\" version.")
        XCTAssertTrue(version.hasPrefix("3."), "Vendored spec declares openapi \(version); expected OpenAPI 3.x.")
        let info = try XCTUnwrap(spec["info"] as? [String: Any], "Vendored spec is missing the \"info\" object.")
        XCTAssertFalse((info["title"] as? String ?? "").isEmpty, "Vendored spec info.title must be a non-empty string.")
        XCTAssertFalse((info["version"] as? String ?? "").isEmpty, "Vendored spec info.version must be a non-empty string.")
    }

    func testVendoredSpecCoversEveryEndpointUsedByTheApp() throws {
        let spec = try loadSpecObject()
        for endpoint in Self.endpoints {
            let pathItem = try Self.pathItem(spec, endpoint.path)
            let operation = try Self.operation(pathItem, endpoint.method, on: endpoint.path)
            let operationID = try XCTUnwrap(
                operation["operationId"] as? String,
                "Operation \(endpoint.method.uppercased()) \(endpoint.path) is missing an operationId."
            )
            XCTAssertEqual(
                operationID,
                endpoint.operationID,
                "Operation \(endpoint.method.uppercased()) \(endpoint.path) changed identity; the generated Swift method name follows the operationId."
            )
            for parameterName in Self.pathParameterNames(in: endpoint.path) {
                try Self.assertDeclaresPathParameter(parameterName, operation: operation, pathItem: pathItem, on: endpoint.path)
            }
        }
    }

    func testVendoredSpecDeclaresTypedSuccessResponseForEachEndpoint() throws {
        let spec = try loadSpecObject()
        for endpoint in Self.endpoints {
            let pathItem = try Self.pathItem(spec, endpoint.path)
            let operation = try Self.operation(pathItem, endpoint.method, on: endpoint.path)
            let responses = try XCTUnwrap(
                operation["responses"] as? [String: Any],
                "Operation \(endpoint.method.uppercased()) \(endpoint.path) declares no responses."
            )
            let response = try XCTUnwrap(
                responses[endpoint.successStatus] as? [String: Any],
                "Operation \(endpoint.method.uppercased()) \(endpoint.path) declares statuses \(responses.keys.sorted()); expected \(endpoint.successStatus)."
            )
            let content = try XCTUnwrap(
                (response["content"] as? [String: Any])?["application/json"] as? [String: Any],
                "Response \(endpoint.successStatus) of \(endpoint.path) must declare application/json content."
            )
            let schema = try XCTUnwrap(
                content["schema"] as? [String: Any],
                "Response \(endpoint.successStatus) of \(endpoint.path) must declare a JSON schema."
            )
            if let reference = schema["$ref"] as? String {
                XCTAssertTrue(
                    reference.hasSuffix("/\(endpoint.responseSchemaTitle)"),
                    "Response \(endpoint.successStatus) of \(endpoint.path) references \(reference); expected the \(endpoint.responseSchemaTitle) schema."
                )
            }
        }
    }

    func testVendoredSpecDeclaresJSONRequestBodyForUploadEndpoints() throws {
        let spec = try loadSpecObject()
        for endpoint in Self.endpoints where endpoint.expectsRequestBody {
            let pathItem = try Self.pathItem(spec, endpoint.path)
            let operation = try Self.operation(pathItem, endpoint.method, on: endpoint.path)
            let requestBody = try XCTUnwrap(
                operation["requestBody"] as? [String: Any],
                "Operation \(endpoint.method.uppercased()) \(endpoint.path) must declare a requestBody."
            )
            XCTAssertNotNil(
                (requestBody["content"] as? [String: Any])?["application/json"],
                "Request body of \(endpoint.path) must declare application/json content."
            )
        }
    }

    func testVendoredSpecDeclaresBearerSecurityScheme() throws {
        let spec = try loadSpecObject()
        let components = try XCTUnwrap(spec["components"] as? [String: Any], "Vendored spec is missing \"components\".")
        let schemes = try XCTUnwrap(
            components["securitySchemes"] as? [String: Any],
            "Vendored spec is missing components.securitySchemes."
        )
        let bearer = try XCTUnwrap(
            schemes["bearerAuth"] as? [String: Any],
            "Vendored spec must declare the bearerAuth security scheme used by every /api/v1 route."
        )
        XCTAssertEqual(bearer["type"] as? String, "http")
        XCTAssertEqual(bearer["scheme"] as? String, "bearer")
    }

    private func loadSpecObject() throws -> [String: Any] {
        let url = Self.vendoredSpecURL
        guard FileManager.default.fileExists(atPath: url.path) else {
            XCTFail(
                "Vendored OpenAPI document not found at \(url.path). Fetch it from GET /api/v1/openapi.json "
                    + "(viamin/color_matching#110, shipped in #113) and vendor it with the ColorMatchingOpenAPI "
                    + "target as described in docs/openapi-generated-client.md."
            )
            throw SpecError()
        }
        let data = try Data(contentsOf: url)
        let object = try JSONSerialization.jsonObject(with: data)
        guard let spec = object as? [String: Any] else {
            XCTFail("Vendored OpenAPI document at \(url.path) is not a JSON object.")
            throw SpecError()
        }
        return spec
    }

    private static var packageRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private static var vendoredSpecURL: URL {
        packageRoot
            .appendingPathComponent("Sources")
            .appendingPathComponent("ColorMatchingOpenAPI")
            .appendingPathComponent("openapi.json")
    }

    private static func pathItem(_ spec: [String: Any], _ path: String) throws -> [String: Any] {
        let paths = try XCTUnwrap(spec["paths"] as? [String: Any], "Vendored spec is missing the \"paths\" object.")
        return try XCTUnwrap(paths[path] as? [String: Any], "Vendored spec is missing the path \(path) used by the app.")
    }

    private static func operation(_ pathItem: [String: Any], _ method: String, on path: String) throws -> [String: Any] {
        try XCTUnwrap(pathItem[method] as? [String: Any], "Path \(path) is missing a \(method.uppercased()) operation.")
    }

    private static func pathParameterNames(in path: String) -> [String] {
        path.split(separator: "/").compactMap { segment in
            guard segment.hasPrefix("{"), segment.hasSuffix("}") else { return nil }
            return String(segment.dropFirst().dropLast())
        }
    }

    private static func assertDeclaresPathParameter(
        _ name: String,
        operation: [String: Any],
        pathItem: [String: Any],
        on path: String
    ) throws {
        let candidates = ((operation["parameters"] as? [[String: Any]]) ?? [])
            + ((pathItem["parameters"] as? [[String: Any]]) ?? [])
        let declared = candidates.contains { parameter in
            (parameter["name"] as? String) == name && (parameter["in"] as? String) == "path"
        }
        XCTAssertTrue(
            declared,
            "Operation on \(path) must declare the {\(name)} path parameter; without it the generated client cannot type the path input."
        )
    }
}
