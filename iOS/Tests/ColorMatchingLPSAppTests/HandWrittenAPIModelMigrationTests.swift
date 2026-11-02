import Foundation
import XCTest

/// Verifies the API-model migration (issue #5): the hand-written wire envelope
/// types in the app's API layer are replaced by generated OpenAPI types, while
/// purely client-side domain models stay untouched.
final class HandWrittenAPIModelMigrationTests: XCTestCase {
    func testHandWrittenAPIWireModelsAreRemovedFromAppSources() throws {
        let handWrittenWireTypes = [
            "CreateCaptureRequest",
            "MeasurementUploadRequest",
            "MeasurementUpload",
            "MeasurementStatsUpload",
            "JudgmentUploadRequest",
            "RecentSheetsResponse",
        ]

        var offenders: [String] = []
        for (sourceURL, source) in try Self.appSwiftSources() {
            for typeName in handWrittenWireTypes where Self.declares(source, structOrClassNamed: typeName) {
                offenders.append("\(sourceURL.lastPathComponent): \(typeName)")
            }
        }

        XCTAssertTrue(
            offenders.isEmpty,
            "Hand-written API wire types are still declared; their request/response envelopes must come from the generated OpenAPI client instead: \(offenders.joined(separator: ", "))"
        )
    }

    func testClientSideDomainModelsRemainInMeasurementCore() throws {
        let sources = try Self.measurementCoreSources()
        XCTAssertFalse(sources.isEmpty, "Expected MeasurementCore sources under iOS/Sources/MeasurementCore.")

        let clientSideTypes = [
            "RGB", "Point", "Rect", "DetectedMarker", "SampleOverlayRegion", "SheetAnalysis", "ChannelStats",
        ]
        let measurementCore = sources.joined()

        for typeName in clientSideTypes {
            XCTAssertTrue(
                Self.declares(measurementCore, structOrClassNamed: typeName),
                "Purely client-side model \(typeName) should remain declared in the MeasurementCore module; the OpenAPI migration must keep client-side models as-is."
            )
        }
    }
}

private extension HandWrittenAPIModelMigrationTests {
    /// Substring declaration check, tolerant of access modifiers (`public struct
    /// RGB:` contains `struct RGB:`) and trailing conformances.
    static func declares(_ source: String, structOrClassNamed typeName: String) -> Bool {
        source.contains("struct \(typeName):") || source.contains("class \(typeName):")
    }

    /// `<repo>/iOS/Tests/ColorMatchingLPSAppTests/ThisFile.swift` → `<repo>/iOS`.
    static var iOSRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    static func swiftSourceURLs(in directory: URL) throws -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var sources: [URL] = []
        for case let url as URL in enumerator {
            guard url.pathExtension.lowercased() == "swift" else { continue }
            guard try url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true else { continue }
            sources.append(url)
        }
        return sources.sorted { $0.standardizedFileURL.path < $1.standardizedFileURL.path }
    }

    static func appSwiftSources() throws -> [(sourceURL: URL, source: String)] {
        try swiftSourceURLs(in: iOSRoot.appending(path: "Sources"))
            .map { url in (sourceURL: url, source: try String(contentsOf: url, encoding: .utf8)) }
    }

    static func measurementCoreSources() throws -> [String] {
        try swiftSourceURLs(in: iOSRoot.appending(path: "Sources/MeasurementCore"))
            .map { try String(contentsOf: $0, encoding: .utf8) }
    }
}
