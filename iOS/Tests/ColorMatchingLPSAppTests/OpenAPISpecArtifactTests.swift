import Foundation
import XCTest

final class OpenAPISpecArtifactTests: XCTestCase {
    private static let repoRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    func testPackageDeclaresOpenAPIGeneratorAndRuntimeDependencies() throws {
        let manifest = try String(contentsOf: Self.repoRoot.appendingPathComponent("iOS/Package.swift"), encoding: .utf8)
        XCTAssertTrue(
            manifest.contains("swift-openapi-generator"),
            "iOS/Package.swift must depend on swift-openapi-generator so the client is generated at build time"
        )
        XCTAssertTrue(
            manifest.contains("swift-openapi-runtime"),
            "iOS/Package.swift must depend on swift-openapi-runtime for the generated client's runtime types"
        )
    }

    func testVendoredOpenAPIDocumentExists() throws {
        let document = try XCTUnwrap(
            Self.vendoredSpecDocuments().first,
            "No vendored OpenAPI document (openapi.yaml/openapi.yml/openapi.json) found under iOS/. "
                + "Vendor the document published at GET /api/v1/openapi.json by viamin/color_matching#110."
        )
        XCTAssertGreaterThanOrEqual(document.contents.count, 500, "Vendored OpenAPI document looks empty")
        let isJSON = document.url.pathExtension == "json"
        XCTAssertTrue(
            isJSON
                ? document.contents.contains("\"openapi\"")
                : document.contents.contains("openapi:"),
            "Vendored document must be an OpenAPI 3 document"
        )
    }

    func testVendoredSpecCoversSurfacesUsedByTheApp() throws {
        let document = try XCTUnwrap(Self.vendoredSpecDocuments().first)
        let spec = document.contents

        let expectedPaths = [
            "/api/v1/test_sheets/recent",
            "/api/v1/test_sheets/{sheet_id}/manifest",
            "/api/v1/test_sheets/{sheet_id}/ranked_results",
            "/api/v1/test_sheets/{sheet_id}/captures",
            "/api/v1/captures/{capture_id}/measurements",
            "/api/v1/captures/{capture_id}/judgments",
        ]
        for path in expectedPaths {
            XCTAssertTrue(
                spec.contains(path),
                "Vendored OpenAPI document \(document.url.lastPathComponent) is missing path \(path)"
            )
        }

        let expectedSchemas = [
            "TestSheetManifest",
            "RecentSheetsResponse",
            "CaptureRequest",
            "CaptureCreatedResponse",
            "MeasurementUploadRequest",
            "MeasurementUploadResponse",
            "JudgmentUploadRequest",
            "JudgmentUploadResponse",
            "RankedResults",
        ]
        for schema in expectedSchemas {
            XCTAssertTrue(
                spec.contains(schema),
                "Vendored OpenAPI document \(document.url.lastPathComponent) is missing schema \(schema)"
            )
        }
    }

    func testVendoredSpecDeclaresAppOperationsWithMethods() throws {
        let document = try XCTUnwrap(Self.vendoredSpecDocuments().first)
        let spec = document.contents
        let isJSON = document.url.pathExtension == "json"

        let postOperations = [
            "/api/v1/test_sheets/{sheet_id}/captures",
            "/api/v1/captures/{capture_id}/measurements",
            "/api/v1/captures/{capture_id}/judgments",
        ]
        for path in postOperations {
            let pathPresent = isJSON ? spec.contains("\"\(path)\"") : spec.contains("\(path):")
            XCTAssertTrue(
                pathPresent && spec.contains(isJSON ? "\"post\"" : "post:"),
                "Vendored spec must declare a POST operation for \(path)"
            )
        }

        let getOperations = [
            "/api/v1/test_sheets/recent",
            "/api/v1/test_sheets/{sheet_id}/manifest",
            "/api/v1/test_sheets/{sheet_id}/ranked_results",
        ]
        for path in getOperations {
            let pathPresent = isJSON ? spec.contains("\"\(path)\"") : spec.contains("\(path):")
            XCTAssertTrue(
                pathPresent && spec.contains(isJSON ? "\"get\"" : "get:"),
                "Vendored spec must declare a GET operation for \(path)"
            )
        }
    }

    private static func vendoredSpecDocuments() -> [(url: URL, contents: String)] {
        let iOSRoot = repoRoot.appendingPathComponent("iOS")
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(at: iOSRoot, includingPropertiesForKeys: nil) else {
            return []
        }

        var matches: [(url: URL, contents: String)] = []
        for case let url as URL in enumerator {
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) else { continue }
            if isDirectory.boolValue {
                if [".build", ".git", "DerivedData"].contains(url.lastPathComponent) {
                    enumerator.skipDescendants()
                }
                continue
            }
            guard ["openapi.yaml", "openapi.yml", "openapi.json"].contains(url.lastPathComponent) else { continue }
            guard let contents = try? String(contentsOf: url, encoding: .utf8) else { continue }
            matches.append((url, contents))
        }
        return matches.sorted { $0.url.path < $1.url.path }
    }
}
