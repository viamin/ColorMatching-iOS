import Foundation
import XCTest

final class OpenAPIGeneratorWiringTests: XCTestCase {
    private static let packageRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    private func packageManifestSource() throws -> String {
        let url = Self.packageRoot.appending(path: "Package.swift")
        return try String(contentsOf: url, encoding: .utf8)
    }

    private func squeezed(_ text: String) -> String {
        String(text.filter { !$0.isWhitespace })
    }

    private func assertMatches(
        _ pattern: String,
        in squeezedText: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let regex = try NSRegularExpression(pattern: pattern)
        let range = NSRange(squeezedText.startIndex..., in: squeezedText)
        XCTAssertTrue(
            regex.firstMatch(in: squeezedText, range: range) != nil,
            "expected package manifest to match: \(pattern)",
            file: file,
            line: line
        )
    }

    func testPackageDeclaresOpenAPIGeneratorAndRuntime() throws {
        let squeezedManifest = squeezed(try packageManifestSource())
        XCTAssertTrue(squeezedManifest.contains("https://github.com/apple/swift-openapi-generator"))
        XCTAssertTrue(squeezedManifest.contains("https://github.com/apple/swift-openapi-runtime"))
        XCTAssertTrue(squeezedManifest.contains(".plugin(name:\"OpenAPIGenerator\",package:\"swift-openapi-generator\")"))
        XCTAssertTrue(squeezedManifest.contains(".product(name:\"OpenAPIRuntime\",package:\"swift-openapi-runtime\")"))
    }

    func testGeneratedColorMatchingAPITargetIsDeclared() throws {
        let squeezedManifest = squeezed(try packageManifestSource())
        XCTAssertTrue(
            squeezedManifest.contains("name:\"ColorMatchingAPI\""),
            "expected a ColorMatchingAPI target declared in Package.swift"
        )
    }

    func testAppCoreDependsOnGeneratedTarget() throws {
        let squeezedManifest = squeezed(try packageManifestSource())
        try assertMatches("name:\"ColorMatchingLPSAppCore\"[^\\]]*\"ColorMatchingAPI\"", in: squeezedManifest)
    }

    func testAppTestTargetDependsOnGeneratedTarget() throws {
        let squeezedManifest = squeezed(try packageManifestSource())
        try assertMatches("name:\"ColorMatchingLPSAppTests\"[^\\]]*\"ColorMatchingAPI\"", in: squeezedManifest)
    }

    func testVendoredSpecAndGeneratorConfigAreCheckedIn() throws {
        let targetRoot = Self.packageRoot.appending(path: "Sources/ColorMatchingAPI")
        let specURL = targetRoot.appending(path: "openapi.json")
        let configURL = targetRoot.appending(path: "openapi-generator-config.yaml")
        let manager = FileManager.default
        XCTAssertTrue(manager.fileExists(atPath: specURL.path), "missing vendored OpenAPI document at \(specURL.path)")
        XCTAssertTrue(manager.fileExists(atPath: configURL.path), "missing generator config at \(configURL.path)")
        XCTAssertFalse(try String(contentsOf: configURL, encoding: .utf8).isEmpty)
    }

    func testHandwrittenTransportDTOsAreRemovedFromAppSources() throws {
        let sourcesRoot = Self.packageRoot.appending(path: "Sources")
        let manager = FileManager.default
        let enumerator = manager.enumerator(at: sourcesRoot, includingPropertiesForKeys: nil)
        var offenders: [String] = []
        let removedDTOs = [
            "struct CreateCaptureRequest",
            "struct MeasurementUploadRequest",
            "struct JudgmentUploadRequest",
        ]
        while let item = enumerator?.nextObject() as? URL {
            guard item.pathExtension == "swift" else { continue }
            guard !item.path.contains("/ColorMatchingAPI/") else { continue }
            let contents = try String(contentsOf: item, encoding: .utf8)
            for dto in removedDTOs where contents.contains(dto) {
                offenders.append("\(item.lastPathComponent): \(dto)")
            }
        }
        XCTAssertTrue(
            offenders.isEmpty,
            "hand-written transport DTOs should be replaced by generated types: \(offenders)"
        )
    }
}
