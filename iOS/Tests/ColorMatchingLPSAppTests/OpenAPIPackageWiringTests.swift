import Foundation
import XCTest

final class OpenAPIPackageWiringTests: XCTestCase {
    func testPackageDeclaresOpenAPIGeneratorRuntimeAndPlugin() throws {
        let manifest = try Self.packageManifest()
        XCTAssertTrue(manifest.contains("https://github.com/apple/swift-openapi-generator"), "swift-openapi-generator package is missing")
        XCTAssertTrue(manifest.contains("https://github.com/apple/swift-openapi-runtime"), "swift-openapi-runtime package is missing")
        XCTAssertTrue(manifest.contains("OpenAPIGenerator"), "OpenAPIGenerator build plugin is not applied")
        XCTAssertTrue(manifest.contains("OpenAPIRuntime"), "OpenAPIRuntime product dependency is missing")
    }

    func testGeneratedClientTargetIsCheckedIn() throws {
        let targetDirectory = URL(fileURLWithPath: Self.repoFile("iOS/Sources/ColorMatchingOpenAPI"))
        let contents = try FileManager.default.attributesOfItem(atPath: targetDirectory.path)
        let isDirectory = try XCTUnwrap(contents[.type] as? FileAttributeType) == .typeDirectory
        XCTAssertTrue(isDirectory, "generated client target directory is missing")
        let files = try FileManager.default.contentsOfDirectory(atPath: targetDirectory.path)
        XCTAssertTrue(files.contains { $0.hasSuffix(".swift") }, "generated client sources are missing")
        XCTAssertTrue(files.contains("openapi-generator-config"), "openapi-generator-config is missing")
    }

    func testAppCoreUsesGeneratedClientInsteadOfHandWrittenWireModels() throws {
        let source = try String(contentsOfFile: Self.repoFile("iOS/Sources/ColorMatchingLPSAppCore/APIClient.swift"), encoding: .utf8)
        XCTAssertTrue(source.contains("import ColorMatchingOpenAPI"), "APIClient must be wired to the generated client")
        let handWrittenWireModels = [
            "struct CreateCaptureRequest",
            "struct MeasurementUploadRequest",
            "struct JudgmentUploadRequest",
            "struct RecentSheetsResponse"
        ]
        for wireModel in handWrittenWireModels {
            XCTAssertFalse(source.contains(wireModel), "hand-written wire model \(wireModel) must be replaced by generated types")
        }
    }

    private static func packageManifest() throws -> String {
        try String(contentsOfFile: repoFile("iOS/Package.swift"), encoding: .utf8)
    }

    private static func repoFile(_ relativePath: String) -> String {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(relativePath)
            .path
    }
}
