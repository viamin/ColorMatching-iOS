import Foundation
import XCTest

final class OpenAPIDocumentContractTests: XCTestCase {
    func testVendoredDocumentCoversEveryAppOperation() throws {
        let document = try openAPIDocument()
        let paths = try XCTUnwrap(document["paths"] as? [String: Any])

        for operation in requiredOperations {
            let path = try XCTUnwrap(paths[operation.path] as? [String: Any], "Missing \(operation.path)")
            XCTAssertNotNil(path[operation.method], "Missing \(operation.method.uppercased()) \(operation.path)")
        }
    }

    func testVendoredDocumentDescribesFieldsNeededByGeneratedClient() throws {
        let document = try openAPIDocument()
        let schemas = try XCTUnwrap((document["components"] as? [String: Any])?["schemas"] as? [String: Any])

        XCTAssertTrue(requiredManifestFields.isSubset(of: requiredFields(in: schemas, named: "TestSheetManifest")))
        XCTAssertTrue(requiredRankedResultsFields.isSubset(of: requiredFields(in: schemas, named: "RankedResults")))
        XCTAssertTrue(requiredFields(in: schemas, named: "MeasurementUploadResponse").isSuperset(of: ["capture_id", "measurement_count", "pair_score_count"]))
        XCTAssertTrue(requiredFields(in: schemas, named: "JudgmentUploadResponse").isSuperset(of: ["capture_id", "judgment_count"]))
    }

    private var requiredOperations: [(path: String, method: String)] {
        [
            ("/api/v1/test_sheets/{sheet_id}/manifest", "get"),
            ("/api/v1/test_sheets/recent", "get"),
            ("/api/v1/test_sheets/{sheet_id}/captures", "post"),
            ("/api/v1/captures/{capture_id}/measurements", "post"),
            ("/api/v1/captures/{capture_id}/judgments", "post"),
            ("/api/v1/test_sheets/{sheet_id}/ranked_results", "get")
        ]
    }

    private var requiredManifestFields: Set<String> {
        Set(["schema_version", "sheet_id", "sheet_version", "manifest_url", "page", "registration_markers", "patches", "pairs"])
    }

    private var requiredRankedResultsFields: Set<String> {
        Set(["schema_version", "sheet_id", "results"])
    }

    private func openAPIDocument() throws -> [String: Any] {
        let packageRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let documentURL = packageRoot.appending(path: "OpenAPI/openapi.json")
        let data = try Data(contentsOf: documentURL)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private func requiredFields(in schemas: [String: Any], named name: String) -> Set<String> {
        let schema = schemas[name] as? [String: Any]
        return Set(schema?["required"] as? [String] ?? [])
    }
}
