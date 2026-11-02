import Foundation
import XCTest

final class OpenAPISpecVendoringTests: XCTestCase {
    private enum SpecError: Error { case missingSpec }

    func testVendoredSpecExistsForGeneratedClientTarget() throws {
        try loadSpecObject()
    }

    func testVendoredSpecDeclaresRequiredOperationsWithCleanOperationIDs() throws {
        let spec = try loadSpecObject()
        let paths = try XCTUnwrap(spec["paths"] as? [String: Any])

        let expected: [(path: String, method: String, operationID: String, status: String)] = [
            ("/api/v1/test_sheets/{sheet_id}/manifest", "get", "getTestSheetManifest", "200"),
            ("/api/v1/test_sheets/recent", "get", "listRecentTestSheets", "200"),
            ("/api/v1/test_sheets/{sheet_id}/ranked_results", "get", "getRankedResults", "200"),
            ("/api/v1/test_sheets/{sheet_id}/captures", "post", "createCapture", "201"),
            ("/api/v1/captures/{capture_id}/measurements", "post", "uploadMeasurements", "200"),
            ("/api/v1/captures/{capture_id}/judgments", "post", "uploadJudgments", "200")
        ]

        for expectation in expected {
            let operation = try XCTUnwrap(
                operation(expectation.method, at: expectation.path, in: paths),
                "Missing \(expectation.method.uppercased()) \(expectation.path) in the vendored spec"
            )
            XCTAssertEqual(
                operation["operationId"] as? String,
                expectation.operationID,
                "\(expectation.method.uppercased()) \(expectation.path) must use the clean operationId \(expectation.operationID)"
            )
            let responses = try XCTUnwrap(operation["responses"] as? [String: Any])
            let response = try XCTUnwrap(
                responses[expectation.status] as? [String: Any],
                "Missing \(expectation.status) response on \(expectation.path)"
            )
            let content = try XCTUnwrap(response["content"] as? [String: Any])
            XCTAssertNotNil(content["application/json"], "\(expectation.path) \(expectation.status) must declare application/json")
        }
    }

    func testVendoredSpecDeclaresPathParametersForParameterizedOperations() throws {
        let spec = try loadSpecObject()
        let paths = try XCTUnwrap(spec["paths"] as? [String: Any])

        let expected: [(path: String, method: String, parameter: String)] = [
            ("/api/v1/test_sheets/{sheet_id}/manifest", "get", "sheet_id"),
            ("/api/v1/test_sheets/{sheet_id}/ranked_results", "get", "sheet_id"),
            ("/api/v1/test_sheets/{sheet_id}/captures", "post", "sheet_id"),
            ("/api/v1/captures/{capture_id}/measurements", "post", "capture_id"),
            ("/api/v1/captures/{capture_id}/judgments", "post", "capture_id")
        ]

        for expectation in expected {
            let operation = try XCTUnwrap(
                operation(expectation.method, at: expectation.path, in: paths),
                "Missing \(expectation.method.uppercased()) \(expectation.path) in the vendored spec"
            )
            let parameters = try XCTUnwrap(operation["parameters"] as? [[String: Any]])
            let parameter = try XCTUnwrap(
                parameters.first { ($0["name"] as? String) == expectation.parameter },
                "Missing path parameter \(expectation.parameter) on \(expectation.path)"
            )
            XCTAssertEqual(parameter["in"] as? String, "path")
            XCTAssertEqual(parameter["required"] as? Bool, true)
        }
    }

    func testVendoredSpecKeepsBearerAuthAndRootServer() throws {
        let spec = try loadSpecObject()
        let servers = try XCTUnwrap(spec["servers"] as? [[String: Any]])
        XCTAssertTrue(servers.contains { ($0["url"] as? String) == "/" }, "Vendored spec must keep servers: [{url: \"/\"}]")

        let components = try XCTUnwrap(spec["components"] as? [String: Any])
        let schemes = try XCTUnwrap(components["securitySchemes"] as? [String: Any])
        let bearer = try XCTUnwrap(schemes["bearerAuth"] as? [String: Any])
        XCTAssertEqual(bearer["type"] as? String, "http")
        XCTAssertEqual(bearer["scheme"] as? String, "bearer")

        let paths = try XCTUnwrap(spec["paths"] as? [String: Any])
        let manifest = try XCTUnwrap(operation("get", at: "/api/v1/test_sheets/{sheet_id}/manifest", in: paths))
        let security = try XCTUnwrap(manifest["security"] as? [[String: Any]])
        XCTAssertTrue(security.contains { ($0.keys.first) == "bearerAuth" })
    }

    func testVendoredSpecDeclaresSchemasForSurfacesTheAppUses() throws {
        let schemas = try loadSchemas()

        let required = [
            "TestSheetManifest",
            "RecentSheetsResponse",
            "CaptureRequest",
            "CaptureMetadata",
            "CaptureCreatedResponse",
            "MeasurementUploadRequest",
            "MeasurementUploadResponse",
            "JudgmentUploadRequest",
            "JudgmentUploadResponse",
            "RankedResults"
        ]
        for name in required {
            XCTAssertNotNil(schemas[name], "Vendored spec must declare components.schemas.\(name)")
        }
    }

    func testVendoredSpecNormalizesCodegenHostileSchemas() throws {
        let schemas = try loadSchemas()

        let captureRequest = try XCTUnwrap(schemas["CaptureRequest"] as? [String: Any])
        XCTAssertNil(captureRequest["anyOf"], "CaptureRequest must not combine properties with anyOf; keep the nested {metadata, quality} shape")
        let requestProperties = try XCTUnwrap(captureRequest["properties"] as? [String: Any])
        XCTAssertNotNil(requestProperties["metadata"])
        XCTAssertNotNil(requestProperties["quality"])

        let metadata = try XCTUnwrap(schemas["CaptureMetadata"] as? [String: Any])
        let metadataProperties = try XCTUnwrap(metadata["properties"] as? [String: Any])
        let gains = try XCTUnwrap(
            metadataProperties["white_balance_gains"] as? [String: Any],
            "CaptureMetadata.white_balance_gains must be a structured object, not a bare type: object"
        )
        let gainProperties = try XCTUnwrap(gains["properties"] as? [String: Any])
        for channel in ["red", "green", "blue"] {
            XCTAssertNotNil(gainProperties[channel], "white_balance_gains must declare \(channel)")
        }

        let pairScore = try XCTUnwrap(schemas["PairScoreRequest"] as? [String: Any])
        XCTAssertNil(pairScore["anyOf"], "PairScoreRequest must not combine properties with anyOf; keep score/similarity/distance as optional properties")
        let scoreProperties = try XCTUnwrap(pairScore["properties"] as? [String: Any])
        for property in ["pair_id", "algorithm_version", "distance", "similarity"] {
            XCTAssertNotNil(scoreProperties[property], "PairScoreRequest must declare \(property)")
        }
    }

    func testVendoredSpecMatchesPublishedResponseShapeDeltas() throws {
        let schemas = try loadSchemas()

        let captureCreated = try XCTUnwrap(schemas["CaptureCreatedResponse"] as? [String: Any])
        XCTAssertTrue(try requires(captureCreated, "capture_id"))

        let measurementAccepted = try XCTUnwrap(schemas["MeasurementUploadResponse"] as? [String: Any])
        for property in ["capture_id", "measurement_count", "pair_score_count"] {
            XCTAssertTrue(try requires(measurementAccepted, property))
        }

        let judgmentsAccepted = try XCTUnwrap(schemas["JudgmentUploadResponse"] as? [String: Any])
        for property in ["capture_id", "judgment_count"] {
            XCTAssertTrue(try requires(judgmentsAccepted, property))
        }

        let manifest = try XCTUnwrap(schemas["TestSheetManifest"] as? [String: Any])
        XCTAssertTrue(try requires(manifest, "schema_version"))
        XCTAssertTrue(try requires(manifest, "sheet_id"))
    }

    private var specURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "Sources/ColorMatchingAPI/openapi.json")
    }

    private func loadSpecObject() throws -> [String: Any] {
        let url = specURL
        guard FileManager.default.fileExists(atPath: url.path) else {
            XCTFail(
                "Vendored OpenAPI document is missing at \(url.path). Fetch it from GET /api/v1/openapi.json "
                    + "(viamin/color_matching#110) and apply the normalizations recorded in "
                    + "docs/plans/issue-5-openapi-generated-client-tests.md."
            )
            throw SpecError.missingSpec
        }
        return try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
    }

    private func loadSchemas() throws -> [String: Any] {
        let spec = try loadSpecObject()
        let components = try XCTUnwrap(spec["components"] as? [String: Any])
        return try XCTUnwrap(components["schemas"] as? [String: Any])
    }

    private func operation(_ method: String, at path: String, in paths: [String: Any]) -> [String: Any]? {
        (paths[path] as? [String: Any])?[method] as? [String: Any]
    }

    private func requires(_ schema: [String: Any], _ property: String) throws -> Bool {
        let required = try XCTUnwrap(schema["required"] as? [String])
        return required.contains(property)
    }
}
