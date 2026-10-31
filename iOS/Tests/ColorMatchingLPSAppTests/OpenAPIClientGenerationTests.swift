import Foundation
import XCTest

final class OpenAPIClientGenerationTests: XCTestCase {
    private let requiredPaths = [
        "/api/v1/test_sheets/recent",
        "/api/v1/test_sheets/{sheet_id}/manifest",
        "/api/v1/test_sheets/{sheet_id}/captures",
        "/api/v1/captures/{capture_id}/measurements",
        "/api/v1/captures/{capture_id}/judgments",
        "/api/v1/test_sheets/{sheet_id}/ranked_results"
    ]

    func testPackageDeclaresTheOpenAPIGeneratorAndRuntime() throws {
        let package = try String(contentsOf: packageRoot.appending(path: "Package.swift"), encoding: .utf8)

        XCTAssertTrue(package.contains("swift-openapi-generator"))
        XCTAssertTrue(package.contains("swift-openapi-runtime"))
        XCTAssertTrue(package.contains("OpenAPIGenerator"))
    }

    func testVendoredOpenAPIDocumentContainsEveryConsumedOperation() throws {
        let document = try XCTUnwrap(vendoredOpenAPIDocument())
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: document)) as? [String: Any])
        let paths = try XCTUnwrap(object["paths"] as? [String: Any])

        XCTAssertTrue(object["openapi"] is String)
        XCTAssertEqual(Set(requiredPaths).subtracting(paths.keys), [])
    }

    func testGeneratedClientExposesRankedResultsOperation() throws {
        let apiClient = try String(contentsOf: packageRoot.appending(path: "Sources/ColorMatchingLPSAppCore/APIClient.swift"), encoding: .utf8)

        XCTAssertTrue(apiClient.contains("fetchRankedResults"))
    }

    private var packageRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func vendoredOpenAPIDocument() -> URL? {
        let enumerator = FileManager.default.enumerator(
            at: packageRoot,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )

        return enumerator?.compactMap { $0 as? URL }.first { url in
            guard ["json", "yaml", "yml"].contains(url.pathExtension) else { return false }
            guard let contents = try? String(contentsOf: url, encoding: .utf8) else { return false }
            return contents.contains("\"openapi\"") || contents.contains("openapi:")
        }
    }
}
