import Foundation
import XCTest

/// Guards the vendored OpenAPI document consumed by the generated client (issue #5).
///
/// The machine-readable spec published by `viamin/color_matching#110` must be
/// vendored into this repository and must keep covering every `/api/v1` surface
/// the app consumes, so server-side drift surfaces as a regeneration diff or a
/// compile error instead of a runtime surprise.
///
/// These tests fail red until the implementation change set vendors the spec.
final class OpenAPISpecArtifactTests: XCTestCase {
    func testVendoredOpenAPIDocumentExists() throws {
        let candidates = try Self.vendoredSpecURLs()

        XCTAssertFalse(
            candidates.isEmpty,
            "No vendored OpenAPI document found. Expected a *.yaml/*.yml/*.json file with 'openapi' in its name inside the repository (outside Tests and build directories), vendored from viamin/color_matching#110."
        )
    }

    func testVendoredSpecDeclaresOpenAPI3Document() throws {
        let candidates = try Self.vendoredSpecURLs()
        let specURL = try XCTUnwrap(
            candidates.first,
            "No vendored OpenAPI document found; cannot assert its document version."
        )
        let text = try String(contentsOf: specURL, encoding: .utf8)

        XCTAssertTrue(
            Self.declaresOpenAPI3(text),
            "Vendored document at \(specURL.path) does not declare an OpenAPI 3.x version."
        )
    }

    func testVendoredSpecCoversEveryAppAPIOperation() throws {
        let candidates = try Self.vendoredSpecURLs()
        let specURL = try XCTUnwrap(
            candidates.first,
            "No vendored OpenAPI document found; cannot assert operation coverage."
        )
        let operations = try Self.operations(in: specURL)
        XCTAssertFalse(operations.isEmpty, "Vendored OpenAPI document declares no path operations.")

        let declared = Set(operations.map { "\($0.method.uppercased()) \(Self.normalized($0.path))" })
        let missing = Self.expectedAppOperations.filter { !declared.contains($0) }

        XCTAssertTrue(
            missing.isEmpty,
            "Vendored OpenAPI document is missing operations the app uses today: \(missing.joined(separator: ", ")). Declared: \(declared.sorted().joined(separator: ", "))."
        )
    }
}

private extension OpenAPISpecArtifactTests {
    /// `<METHOD> <path>` for every `/api/v1` surface the app uses today, in the
    /// normalized form produced by `normalized(_:)`. Path parameters are treated
    /// as opaque and an optional `api/v1` prefix is stripped so server-relative
    /// specs match too; path structure and HTTP method stay pinned.
    static let expectedAppOperations: [String] = [
        "GET test_sheets/{param}/manifest",
        "GET test_sheets/recent",
        "POST test_sheets/{param}/captures",
        "POST captures/{param}/measurements",
        "POST captures/{param}/judgments",
        "GET test_sheets/{param}/ranked_results",
    ]

    static let httpMethods: Set<String> = [
        "get", "put", "post", "delete", "options", "head", "patch", "trace",
    ]

    struct SpecOperation {
        let method: String
        let path: String
    }

    /// `<repo>/iOS/Tests/ColorMatchingLPSAppTests/ThisFile.swift` → repository root.
    static var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    /// OpenAPI documents vendored anywhere in the repository, excluding hidden
    /// build directories and `Tests/` (a spec copied as a test fixture must not
    /// satisfy the vendoring requirement on its own).
    static func vendoredSpecURLs() throws -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: repositoryRoot,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var matches: [URL] = []
        for case let url as URL in enumerator {
            let path = url.path.lowercased()
            guard !path.contains("/tests/"), !path.contains("/deriveddata/") else { continue }

            let fileName = url.lastPathComponent.lowercased()
            let fileExtension = url.pathExtension.lowercased()
            guard fileName.contains("openapi"), ["yaml", "yml", "json"].contains(fileExtension) else { continue }
            guard try url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true else { continue }

            matches.append(url)
        }
        return matches.sorted { $0.standardizedFileURL.path < $1.standardizedFileURL.path }
    }

    static func operations(in specURL: URL) throws -> [SpecOperation] {
        let data = try Data(contentsOf: specURL)
        if specURL.pathExtension.lowercased() == "json" {
            return try jsonOperations(in: data)
        }
        return yamlOperations(in: String(decoding: data, as: UTF8.self))
    }

    static func jsonOperations(in data: Data) throws -> [SpecOperation] {
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any],
            "Vendored OpenAPI JSON document did not parse as a JSON object."
        )
        let paths = try XCTUnwrap(
            object["paths"] as? [String: Any],
            "Vendored OpenAPI JSON document has no 'paths' object."
        )

        var operations: [SpecOperation] = []
        for (path, pathItem) in paths {
            guard let methods = pathItem as? [String: Any] else { continue }
            for method in methods.keys where httpMethods.contains(method) {
                operations.append(SpecOperation(method: method, path: path))
            }
        }
        return operations
    }

    /// Minimal line-oriented extraction of the top-level `paths:` section used
    /// for YAML documents: path keys are indented one level (2 spaces) and
    /// operations one level deeper. Avoids a YAML dependency in tests.
    static func yamlOperations(in text: String) -> [SpecOperation] {
        var operations: [SpecOperation] = []
        var inPathsSection = false
        var currentPath: String?

        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(rawLine)
            let indentation = line.count - line.drop(while: { $0 == " " }).count
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)

            if indentation == 0 {
                inPathsSection = trimmed.hasPrefix("paths:")
                currentPath = nil
                continue
            }
            guard inPathsSection, !trimmed.isEmpty else { continue }

            if indentation == 2, trimmed.hasSuffix(":") {
                currentPath = trimmed
                    .dropLast()
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\"' "))
            } else if indentation > 2, let currentPath {
                for method in httpMethods where trimmed.hasPrefix("\(method):") {
                    operations.append(SpecOperation(method: method, path: currentPath))
                }
            }
        }
        return operations
    }

    static func declaresOpenAPI3(_ text: String) -> Bool {
        if let object = try? JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any],
           let version = object["openapi"] as? String {
            return version.hasPrefix("3")
        }
        return text.split(separator: "\n").contains { line in
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.hasPrefix("openapi:") else { return false }
            return trimmed
                .dropFirst("openapi:".count)
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .hasPrefix("3")
        }
    }

    /// Compares path structure independent of cosmetic deltas: parameter names
    /// (`{sheet_id}`, `{id}`, `:sheet_id`) collapse to `{param}` and a leading
    /// `api/v1` prefix is optional.
    static func normalized(_ path: String) -> String {
        var segments = path.split(separator: "/").map(String.init)
        if segments.count >= 2, segments[0] == "api", segments[1] == "v1" {
            segments.removeFirst(2)
        }
        return segments
            .map { segment in
                segment.hasPrefix("{") || segment.hasPrefix(":") ? "{param}" : segment
            }
            .joined(separator: "/")
    }
}
