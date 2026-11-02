import Foundation
import XCTest

final class OpenAPIClientWiringTests: XCTestCase {
    func testPackageManifestDeclaresOpenAPIToolchain() throws {
        let manifest = try packageManifestContents()

        XCTAssertTrue(
            manifest.contains("swift-openapi-generator"),
            "iOS/Package.swift must depend on apple/swift-openapi-generator to generate the typed API client."
        )
        XCTAssertTrue(
            manifest.contains("swift-openapi-runtime"),
            "iOS/Package.swift must depend on apple/swift-openapi-runtime for the generated client's transport and serialization."
        )
    }

    func testPackageManifestDeclaresGeneratedClientTarget() throws {
        let manifest = try packageManifestContents()

        XCTAssertTrue(
            manifest.contains("OpenAPIGeneratedClient"),
            "iOS/Package.swift must declare a target named OpenAPIGeneratedClient for the generated client."
        )
    }

    func testGeneratedClientTargetDirectoryIsConfigured() throws {
        let targetDirectory = Self.iosDirectory.appendingPathComponent("Sources/OpenAPIGeneratedClient")

        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: targetDirectory.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            XCTFail("Expected a generated-client target directory at \(targetDirectory.path) containing the OpenAPI document and generator config.")
            return
        }

        let entries = try FileManager.default.contentsOfDirectory(atPath: targetDirectory.path)
        XCTAssertFalse(entries.isEmpty, "The OpenAPIGeneratedClient target directory must not be empty.")
    }

    func testVendoredOpenAPIDocumentCoversAppSurfaces() throws {
        let documentURL = try XCTUnwrap(
            vendoredOpenAPIDocument(),
            "No vendored OpenAPI document found under iOS/. Vendor the published /api/v1 spec from viamin/color_matching#110 (e.g. iOS/Sources/OpenAPIGeneratedClient/openapi.yaml or iOS/OpenAPI/openapi.json)."
        )
        let contents = try String(contentsOf: documentURL, encoding: .utf8)

        XCTAssertTrue(
            contents.contains("openapi") && (contents.contains("3.0") || contents.contains("3.1")),
            "The vendored document at \(documentURL.path) must be an OpenAPI 3 document."
        )
        XCTAssertTrue(
            contents.contains("bearerAuth"),
            "The vendored document must declare the bearerAuth security scheme used by /api/v1."
        )

        for path in Self.appSurfacePaths {
            XCTAssertTrue(
                contents.contains(path),
                "The vendored OpenAPI document is missing the app surface path \(path)."
            )
        }
    }

    func testVendoredOpenAPIDocumentTypesUploadResponseBodies() throws {
        let documentURL = try XCTUnwrap(
            vendoredOpenAPIDocument(),
            "No vendored OpenAPI document found under iOS/."
        )
        let contents = try String(contentsOf: documentURL, encoding: .utf8)

        XCTAssertTrue(
            contents.contains("measurement_count") && contents.contains("pair_score_count"),
            "The vendored document must type the measurement upload 200 response body {capture_id, measurement_count, pair_score_count}."
        )
        XCTAssertTrue(
            contents.contains("judgment_count"),
            "The vendored document must type the judgment upload 200 response body {capture_id, judgment_count}."
        )
        XCTAssertTrue(
            contents.contains("capture_id"),
            "The vendored document must type capture creation and upload response identifiers."
        )
    }

    private func packageManifestContents() throws -> String {
        try String(contentsOf: Self.iosDirectory.appendingPathComponent("Package.swift"), encoding: .utf8)
    }

    private func vendoredOpenAPIDocument() -> URL? {
        guard let enumerator = FileManager.default.enumerator(
            at: Self.iosDirectory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return nil }

        for case let url as URL in enumerator {
            let lowercasedName = url.lastPathComponent.lowercased()
            guard ["json", "yaml", "yml"].contains(url.pathExtension.lowercased()) else { continue }
            guard lowercasedName.contains("openapi") else { continue }
            return url
        }
        return nil
    }

    private static let iosDirectory: URL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    private static let appSurfacePaths = [
        "/api/v1/test_sheets/recent",
        "/api/v1/test_sheets/{sheet_id}/manifest",
        "/api/v1/test_sheets/{sheet_id}/ranked_results",
        "/api/v1/test_sheets/{sheet_id}/captures",
        "/api/v1/captures/{capture_id}/measurements",
        "/api/v1/captures/{capture_id}/judgments"
    ]
}
