import Foundation
import XCTest

/// Checks the contract the generated client is built from.
///
/// The Swift package vendors the OpenAPI document published by
/// `viamin/color_matching`; these tests make sure the vendored copy is
/// present, still describes the surfaces the app uses, and that the package
/// really pulls in the generator and the runtime.
final class OpenAPIContractTests: XCTestCase {
    /// The paths of the API the iOS app uses today.
    private static let usedPaths = [
        "/api/v1/test_sheets/{sheet_id}/manifest",
        "/api/v1/test_sheets/recent",
        "/api/v1/test_sheets/{sheet_id}/captures",
        "/api/v1/captures/{capture_id}/measurements",
        "/api/v1/captures/{capture_id}/judgments",
        "/api/v1/test_sheets/{sheet_id}/ranked_results"
    ]

    /// The component schemas the generated client is built from.
    private static let usedSchemas = [
        "TestSheetManifest",
        "RecentSheetsResponse",
        "CaptureRequest",
        "CaptureCreatedResponse",
        "MeasurementUploadRequest",
        "MeasurementUploadResponse",
        "JudgmentUploadRequest",
        "JudgmentUploadResponse",
        "RankedResults"
    ]

    func testTheVendoredOpenAPIDocumentExists() throws {
        let document = try Self.vendoredDocumentURL()
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: document.path),
            "the vendored OpenAPI document is missing at \(document.path)"
        )
    }

    func testTheVendoredOpenAPIDocumentIsAnOpenAPIThreeDocument() throws {
        let spec = try Self.vendoredSpec()
        let version = try XCTUnwrap(spec["openapi"] as? String)
        XCTAssertTrue(version.hasPrefix("3."), "expected an OpenAPI 3 document, found \(version)")
        XCTAssertNotNil(spec["info"])
        XCTAssertNotNil(spec["paths"])
    }

    func testTheVendoredOpenAPIDocumentDeclaresEverySurfaceTheAppUses() throws {
        let spec = try Self.vendoredSpec()
        let paths = try XCTUnwrap(spec["paths"] as? [String: Any])
        for path in Self.usedPaths {
            XCTAssertNotNil(paths[path], "the vendored OpenAPI document does not declare \(path)")
        }
    }

    func testTheVendoredOpenAPIDocumentDeclaresTheComponentSchemasTheClientUses() throws {
        let spec = try Self.vendoredSpec()
        let components = try XCTUnwrap(spec["components"] as? [String: Any])
        let schemas = try XCTUnwrap(components["schemas"] as? [String: Any])
        for schema in Self.usedSchemas {
            XCTAssertNotNil(schemas[schema], "the vendored OpenAPI document does not declare the \(schema) schema")
        }
    }

    func testThePackageDependsOnTheGeneratorAndTheRuntime() throws {
        let manifest = try Self.packageManifest()
        XCTAssertTrue(
            manifest.contains("swift-openapi-generator"),
            "the package does not depend on swift-openapi-generator"
        )
        XCTAssertTrue(
            manifest.contains("swift-openapi-runtime"),
            "the package does not depend on swift-openapi-runtime"
        )
        XCTAssertTrue(
            manifest.contains("OpenAPIGenerator"),
            "the package does not run the OpenAPIGenerator plugin"
        )
    }

    func testTheGeneratedClientTargetIsPartOfThePackage() throws {
        let manifest = try Self.packageManifest()
        XCTAssertTrue(
            manifest.contains("ColorMatchingOpenAPI"),
            "the package does not declare the ColorMatchingOpenAPI target"
        )
    }

    // MARK: - Helpers

    /// The root of the Swift package under test.
    private static var packageRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private static func packageManifest() throws -> String {
        let url = packageRoot.appending(path: "Package.swift")
        let data = try Data(contentsOf: url)
        return String(decoding: data, as: UTF8.self)
    }

    /// The vendored OpenAPI document.
    ///
    /// `swift-openapi-generator` looks for `openapi.json` (or `.yaml`/`.yml`)
    /// inside the sources of the target it generates, so the document is
    /// searched for there.
    private static func vendoredDocumentURL() throws -> URL {
        let sources = packageRoot.appending(path: "Sources")
        let names = ["openapi.json", "openapi.yaml", "openapi.yml"]
        guard let enumerator = FileManager.default.enumerator(
            at: sources,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            throw ContractError.missingDocument("the package has no Sources directory")
        }
        let documents = enumerator
            .compactMap { $0 as? URL }
            .filter { names.contains($0.lastPathComponent) }
            .sorted { $0.path < $1.path }
        guard let document = documents.first else {
            throw ContractError.missingDocument("no vendored OpenAPI document found under \(sources.path)")
        }
        return document
    }

    private static func vendoredSpec() throws -> [String: Any] {
        let document = try vendoredDocumentURL()
        let data = try Data(contentsOf: document)
        guard let spec = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ContractError.unreadableDocument(
                "the vendored OpenAPI document at \(document.path) is not a JSON object; vendor it as openapi.json"
            )
        }
        return spec
    }

    private enum ContractError: Error, LocalizedError {
        case missingDocument(String)
        case unreadableDocument(String)

        var errorDescription: String? {
            switch self {
            case let .missingDocument(detail): return detail
            case let .unreadableDocument(detail): return detail
            }
        }
    }
}
