import Foundation
import XCTest

/// Guards the vendored OpenAPI document against drift.
///
/// The client in this app is generated from a vendored copy of the document
/// published by `color_matching` (`GET /api/v1/openapi.json`). These tests
/// fail when that vendored document stops describing the endpoints and
/// payloads the app depends on, which is the early warning this change is
/// meant to provide.
final class OpenAPISpecDriftTests: XCTestCase {
    func testVendoredDocumentDeclaresEveryEndpointTheAppCalls() throws {
        let documents = try Self.vendoredDocuments()
        XCTAssertFalse(documents.isEmpty, "No vendored OpenAPI document was found under the iOS package")

        for operation in Self.expectedOperations {
            XCTAssertTrue(
                documents.contains { document in
                    guard let paths = document["paths"] as? [String: Any],
                          let entry = paths[operation.path] as? [String: Any]
                    else { return false }
                    return entry[operation.method] != nil
                },
                "No vendored OpenAPI document declares \(operation.method.uppercased()) \(operation.path)"
            )
        }
    }

    func testVendoredDocumentDeclaresManifestPayload() throws {
        let documents = try Self.vendoredDocuments()

        XCTAssertTrue(
            documents.contains { document in
                guard let manifest = Self.schema(named: "TestSheetManifest", in: document) else { return false }
                let properties = manifest["properties"] as? [String: Any] ?? [:]
                let required = [
                    "schema_version",
                    "sheet_id",
                    "page",
                    "registration_markers",
                    "patches",
                    "pairs"
                ]
                return required.allSatisfy { properties[$0] != nil }
            },
            "No vendored OpenAPI document declares the manifest payload the app decodes"
        )
    }

    func testVendoredDocumentDeclaresRankedResultsPayload() throws {
        let documents = try Self.vendoredDocuments()

        XCTAssertTrue(
            documents.contains { document in
                guard let ranked = Self.schema(named: "RankedResults", in: document) else { return false }
                let properties = ranked["properties"] as? [String: Any] ?? [:]
                return properties["results"] != nil
            },
            "No vendored OpenAPI document declares the ranked-results payload the app decodes"
        )
    }

    func testVendoredDocumentDeclaresMeasurementUploadStats() throws {
        let documents = try Self.vendoredDocuments()

        XCTAssertTrue(
            documents.contains { document in
                let schemas = Self.schemas(in: document)
                guard let upload = Self.schema(named: "MeasurementUploadRequest", in: document) else { return false }
                let properties = upload["properties"] as? [String: Any] ?? [:]
                guard let measurements = properties["measurements"] as? [String: Any] else { return false }
                let items = Self.resolve(measurements, in: schemas)
                guard let itemsSchema = items["items"] as? [String: Any] else { return false }
                let item = Self.resolve(itemsSchema, in: schemas)
                let itemProperties = item["properties"] as? [String: Any] ?? [:]
                guard let stats = itemProperties["stats"] as? [String: Any] else { return false }
                let statsProperties = stats["properties"] as? [String: Any] ?? [:]
                let required = ["sample_count", "clipping_fraction", "mean", "standard_deviation"]
                return required.allSatisfy { statsProperties[$0] != nil }
            },
            "No vendored OpenAPI document declares the per-patch `stats` object the server requires"
        )
    }

    func testVendoredDocumentDeclaresNestedCaptureRequest() throws {
        let documents = try Self.vendoredDocuments()

        XCTAssertTrue(
            documents.contains { document in
                guard let request = Self.schema(named: "CaptureRequest", in: document) else { return false }
                let properties = request["properties"] as? [String: Any] ?? [:]
                return properties["metadata"] != nil && properties["quality"] != nil
            },
            "No vendored OpenAPI document declares the nested `metadata`/`quality` capture request the app sends"
        )
    }

    func testVendoredDocumentDeclaresTypedWhiteBalanceGains() throws {
        let documents = try Self.vendoredDocuments()

        XCTAssertTrue(
            documents.contains { document in
                let schemas = Self.schemas(in: document)
                guard let metadata = Self.schema(named: "CaptureMetadata", in: document) else { return false }
                let properties = metadata["properties"] as? [String: Any] ?? [:]
                guard let gains = properties["white_balance_gains"] as? [String: Any] else { return false }
                let gainsSchema = Self.resolve(gains, in: schemas)
                let gainsProperties = gainsSchema["properties"] as? [String: Any] ?? [:]
                return ["red", "green", "blue"].allSatisfy { gainsProperties[$0] != nil }
            },
            "No vendored OpenAPI document declares typed `white_balance_gains` channels"
        )
    }

    func testVendoredDocumentPinsOperationIdentifiers() throws {
        let documents = try Self.vendoredDocuments()
        var identifiers: [String] = []

        for operation in Self.expectedOperations {
            let candidates = documents.compactMap { document -> String? in
                guard let paths = document["paths"] as? [String: Any],
                      let entry = paths[operation.path] as? [String: Any],
                      let definition = entry[operation.method] as? [String: Any],
                      let identifier = definition["operationId"] as? String
                else { return nil }
                return identifier
            }

            XCTAssertFalse(
                candidates.isEmpty,
                "\(operation.method.uppercased()) \(operation.path) has no operationId in any vendored OpenAPI document"
            )
            if let identifier = candidates.first {
                identifiers.append(identifier)
            }
        }

        XCTAssertEqual(
            Set(identifiers).count,
            identifiers.count,
            "The operations the app calls must have distinct operationIds"
        )
    }

    // MARK: - Helpers

    private static let expectedOperations: [(path: String, method: String)] = [
        ("/api/v1/test_sheets/{sheet_id}/manifest", "get"),
        ("/api/v1/test_sheets/recent", "get"),
        ("/api/v1/test_sheets/{sheet_id}/ranked_results", "get"),
        ("/api/v1/test_sheets/{sheet_id}/captures", "post"),
        ("/api/v1/captures/{capture_id}/measurements", "post"),
        ("/api/v1/captures/{capture_id}/judgments", "post")
    ]

    /// Every OpenAPI 3 document vendored inside the iOS package.
    private static func vendoredDocuments() throws -> [[String: Any]] {
        var documents: [[String: Any]] = []

        for url in try candidateSpecFiles() {
            guard let data = try? Data(contentsOf: url) else { continue }
            guard let object = try? JSONSerialization.jsonObject(with: data) else { continue }
            guard let document = object as? [String: Any] else { continue }
            guard (document["openapi"] as? String)?.hasPrefix("3.") == true else { continue }
            documents.append(document)
        }

        return documents
    }

    private static func candidateSpecFiles() throws -> [URL] {
        let packageRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        guard let enumerator = try FileManager.default.enumerator(
            at: packageRoot,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        var candidates: [URL] = []
        for case let url as URL in enumerator {
            let name = url.lastPathComponent.lowercased()
            guard name == "openapi.json" || name.hasSuffix(".openapi.json") else { continue }
            let values = try? url.resourceValues(forKeys: [.isRegularFileKey])
            guard values?.isRegularFile == true else { continue }
            candidates.append(url)
        }

        return candidates.sorted { $0.path < $1.path }
    }

    private static func schemas(in document: [String: Any]) -> [String: Any] {
        let components = document["components"] as? [String: Any] ?? [:]
        return components["schemas"] as? [String: Any] ?? [:]
    }

    private static func schema(named name: String, in document: [String: Any]) -> [String: Any]? {
        let schemas = schemas(in: document)
        if let schema = schemas[name] as? [String: Any] {
            return schema
        }
        for value in schemas.values {
            guard let schema = value as? [String: Any] else { continue }
            if (schema["title"] as? String) == name {
                return schema
            }
        }
        return nil
    }

    /// Follows a `$ref` into `#/components/schemas` when the node is one.
    private static func resolve(_ node: [String: Any], in schemas: [String: Any]) -> [String: Any] {
        guard let reference = node["$ref"] as? String,
              reference.hasPrefix("#/components/schemas/")
        else { return node }
        let name = String(reference.dropFirst("#/components/schemas/".count))
        return schemas[name] as? [String: Any] ?? node
    }
}
