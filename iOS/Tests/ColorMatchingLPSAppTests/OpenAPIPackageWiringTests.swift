import Foundation
import XCTest

final class OpenAPIPackageWiringTests: XCTestCase {
    func testPackageManifestWiresOpenAPIGeneratorAndRuntime() throws {
        let manifest = try String(contentsOf: Self.packageManifestURL, encoding: .utf8)

        Self.assertContains(manifest, needle: "swift-openapi-generator", message: "Package.swift must declare the apple/swift-openapi-generator dependency")
        Self.assertContains(manifest, needle: "swift-openapi-runtime", message: "Package.swift must declare the apple/swift-openapi-runtime dependency")
        Self.assertContains(manifest, needle: "OpenAPIGenerator", message: "the OpenAPIGenerator build plugin must be attached to a generated-client target")
        Self.assertContains(manifest, needle: "OpenAPIRuntime", message: "the generated-client target must link the OpenAPIRuntime product")
    }

    func testVendoredOpenAPIDocumentCoversAppSurfaces() throws {
        let documentURL = try Self.locateVendoredOpenAPIDocument()
        let text = try String(contentsOf: documentURL, encoding: .utf8)

        for path in Self.requiredPaths {
            Self.assertContains(text, needle: path, message: "vendored OpenAPI document must cover the app surface")
        }
        for schemaTitle in Self.requiredSchemaTitles {
            Self.assertContains(text, needle: schemaTitle, message: "vendored OpenAPI document must declare the published schema")
        }
        Self.assertContains(text, needle: "bearerAuth", message: "vendored OpenAPI document must declare the bearerAuth security scheme")
        for schemaVersion in ["lps-sheet-manifest/v1", "lps-distance-v1", "lps-ranked-results/v1"] {
            Self.assertContains(text, needle: schemaVersion, message: "vendored OpenAPI document must pin the published schema version")
        }
    }

    func testVendoredOpenAPIDocumentIsParseableJSONWithRequiredPaths() throws {
        let documentURL = try Self.locateVendoredOpenAPIDocument()
        let json = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: Data(contentsOf: documentURL)) as? [String: Any],
            "vendored OpenAPI document must be a JSON object (fetch it from GET /api/v1/openapi.json)"
        )
        let version = try XCTUnwrap(json["openapi"] as? String, "vendored document must declare its OpenAPI version")
        XCTAssertTrue(version.hasPrefix("3."), "vendored document must be OpenAPI 3.x, found \(version)")

        let paths = try XCTUnwrap(json["paths"] as? [String: Any], "vendored document must declare a paths object")
        for path in Self.requiredPaths {
            XCTAssertNotNil(paths[path], "vendored document must declare path \(path)")
        }
    }

    private static let requiredPaths = [
        "/api/v1/test_sheets/recent",
        "/api/v1/test_sheets/{sheet_id}/manifest",
        "/api/v1/test_sheets/{sheet_id}/ranked_results",
        "/api/v1/test_sheets/{sheet_id}/captures",
        "/api/v1/captures/{capture_id}/measurements",
        "/api/v1/captures/{capture_id}/judgments",
    ]

    private static let requiredSchemaTitles = [
        "TestSheetManifest",
        "RecentSheetsResponse",
        "CaptureMetadata",
        "CaptureRequest",
        "MeasurementUploadRequest",
        "JudgmentUploadRequest",
        "RankedResults",
    ]

    private static let testFileURL = URL(fileURLWithPath: #filePath)

    private static var packageRoot: URL {
        testFileURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private static var packageManifestURL: URL {
        packageRoot.appendingPathComponent("Package.swift")
    }

    private static func locateVendoredOpenAPIDocument(file: StaticString = #filePath, line: UInt = #line) throws -> URL {
        let candidates = try openAPIDocumentCandidates()
        let match = candidates.first { url in
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { return false }
            return text.contains("openapi") && text.contains("/api/v1/test_sheets")
        }
        return try XCTUnwrap(
            match,
            "no vendored OpenAPI document found under \(packageRoot.path) (searched \(candidates.count) .json/.yaml/.yml files); vendor the published spec from viamin/color_matching#110, e.g. iOS/Sources/ColorMatchingOpenAPI/openapi.json",
            file: file,
            line: line
        )
    }

    private static func openAPIDocumentCandidates() throws -> [URL] {
        let enumerator = FileManager.default.enumerator(
            at: packageRoot,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )
        let urls = (enumerator?.allObjects as? [URL]) ?? []
        return try urls
            .filter { ["json", "yaml", "yml"].contains($0.pathExtension.lowercased()) }
            .filter { try $0.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true }
            .sorted { $0.standardizedFileURL.path < $1.standardizedFileURL.path }
    }

    private static func assertContains(_ haystack: String, needle: String, message: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(
            haystack.contains(needle),
            "\(message): expected to find \"\(needle)\"",
            file: file,
            line: line
        )
    }
}
