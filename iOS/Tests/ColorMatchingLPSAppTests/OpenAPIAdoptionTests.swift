import Foundation
import XCTest

final class OpenAPIAdoptionTests: XCTestCase {
    func testPackageDeclaresOpenAPIGeneratorAndRuntimeAgainstVendoredSpec() throws {
        let repository = try repositoryRoot()
        let package = try String(contentsOf: repository.appending(path: "iOS/Package.swift"))
        let spec = repository.appending(path: "iOS/OpenAPI/color-matching.json")

        XCTAssertTrue(package.contains("swift-openapi-generator"))
        XCTAssertTrue(package.contains("swift-openapi-runtime"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: spec.path))
    }

    func testVendoredSpecCoversEveryAppUsedAPIOperation() throws {
        let repository = try repositoryRoot()
        let spec = repository.appending(path: "iOS/OpenAPI/color-matching.json")
        let document = try JSONSerialization.jsonObject(with: Data(contentsOf: spec))
        let paths = try XCTUnwrap((document as? [String: Any])?["paths"] as? [String: Any])

        XCTAssertNotNil(paths["/api/v1/test_sheets/{sheet_id}/manifest"])
        XCTAssertNotNil(paths["/api/v1/test_sheets/recent"])
        XCTAssertNotNil(paths["/api/v1/test_sheets/{sheet_id}/captures"])
        XCTAssertNotNil(paths["/api/v1/captures/{capture_id}/measurements"])
        XCTAssertNotNil(paths["/api/v1/captures/{capture_id}/judgments"])
        XCTAssertNotNil(paths["/api/v1/test_sheets/{sheet_id}/ranked_results"])
    }

    func testAPILayerUsesGeneratedClientInsteadOfHandWrittenWireModels() throws {
        let repository = try repositoryRoot()
        let apiClient = try String(contentsOf: repository.appending(path: "iOS/Sources/ColorMatchingLPSAppCore/APIClient.swift"))

        XCTAssertTrue(apiClient.contains("import ColorMatchingAPIClient"))
        XCTAssertFalse(apiClient.contains("public struct CaptureMetadata"))
        XCTAssertFalse(apiClient.contains("public struct CaptureSessionResponse"))
        XCTAssertFalse(apiClient.contains("public struct RecentSheet"))
        XCTAssertFalse(apiClient.contains("public struct PairJudgment"))
    }

    private func repositoryRoot() throws -> URL {
        let testFile = URL(fileURLWithPath: #filePath)
        let root = testFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        guard FileManager.default.fileExists(atPath: root.appending(path: ".git").path) else {
            throw XCTSkip("Tests must run from a source checkout.")
        }
        return root
    }
}
