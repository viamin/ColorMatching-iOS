import Foundation
import XCTest

final class GeneratedClientAdoptionTests: XCTestCase {
    func testPackageDeclaresOpenAPIGeneratorAndRuntime() throws {
        let package = try String(contentsOf: iOSDirectory.appending(path: "Package.swift"))

        XCTAssertTrue(package.contains("swift-openapi-generator"))
        XCTAssertTrue(package.contains("swift-openapi-runtime"))
        XCTAssertTrue(package.contains("OpenAPIGenerator"))
        XCTAssertTrue(package.contains("OpenAPIRuntime"))
    }

    func testVendoredOpenAPISpecDefinesEveryAppEndpoint() throws {
        let specification = try String(contentsOf: try XCTUnwrap(vendoredSpecificationURL()))

        [
            "/api/v1/test_sheets/{sheet_id}/manifest",
            "/api/v1/test_sheets/recent",
            "/api/v1/test_sheets/{sheet_id}/captures",
            "/api/v1/captures/{capture_id}/measurements",
            "/api/v1/captures/{capture_id}/judgments",
            "/api/v1/test_sheets/{sheet_id}/ranked_results"
        ].forEach { endpoint in
            XCTAssertTrue(specification.contains(endpoint), "Missing \(endpoint) from vendored OpenAPI spec")
        }
    }

    func testAPIClientImportsGeneratedRuntimeInsteadOfHandwrittenTransport() throws {
        let source = try String(contentsOf: iOSDirectory.appending(path: "Sources/ColorMatchingLPSAppCore/APIClient.swift"))

        XCTAssertTrue(source.contains("import OpenAPIRuntime"))
        XCTAssertFalse(source.contains("JSONEncoder.snakeCase"))
        XCTAssertFalse(source.contains("JSONDecoder.snakeCase"))
    }

    private var iOSDirectory: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func vendoredSpecificationURL() -> URL? {
        let candidates = [
            iOSDirectory.appending(path: "openapi.json"),
            iOSDirectory.appending(path: "openapi.yaml"),
            iOSDirectory.appending(path: "openapi.yml"),
            iOSDirectory.appending(path: "Sources/ColorMatchingLPSAppCore/openapi.json"),
            iOSDirectory.appending(path: "Sources/ColorMatchingLPSAppCore/openapi.yaml"),
            iOSDirectory.appending(path: "Sources/ColorMatchingLPSAppCore/openapi.yml")
        ]

        return candidates.first(where: FileManager.default.fileExists(atPath:))
    }
}
