import Foundation
import XCTest

final class OpenAPISpecVendoringTests: XCTestCase {
    private static let specURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("Sources/ColorMatchingOpenAPI/openapi.yaml")

    func testVendoredSpecExistsAndDeclaresOpenAPI3() throws {
        let yaml = try Self.specContents()
        XCTAssertTrue(
            yaml.contains("openapi: 3"),
            "vendored spec must declare OpenAPI 3.x"
        )
    }

    func testVendoredSpecCoversEveryAppSurface() throws {
        let operations = Self.parseOperations(from: try Self.specContents())
        let expected: [(path: String, method: String, operationID: String)] = [
            ("/api/v1/test_sheets/{sheet_id}/manifest", "get", "getTestSheetManifest"),
            ("/api/v1/test_sheets/recent", "get", "getRecentSheets"),
            ("/api/v1/test_sheets/{sheet_id}/ranked_results", "get", "getRankedResults"),
            ("/api/v1/test_sheets/{sheet_id}/captures", "post", "createCapture"),
            ("/api/v1/captures/{capture_id}/measurements", "post", "uploadMeasurements"),
            ("/api/v1/captures/{capture_id}/judgments", "post", "uploadJudgments")
        ]

        for surface in expected {
            let match = operations.first { $0.path == surface.path && $0.method == surface.method }
            XCTAssertNotNil(
                match,
                "vendored spec must document \(surface.method.uppercased()) \(surface.path)"
            )
            XCTAssertEqual(
                match?.operationID,
                surface.operationID,
                "\(surface.path) must carry operationId \(surface.operationID)"
            )
        }
    }

    func testVendoredSpecDocumentsBearerAuth() throws {
        let yaml = try Self.specContents()
        XCTAssertTrue(
            yaml.contains("bearerAuth"),
            "vendored spec must keep the published bearerAuth security scheme"
        )
    }

    func testVendoredSpecTypesTheFieldsTheAppConsumes() throws {
        let yaml = try Self.specContents()
        let requiredFields = [
            "lps-sheet-manifest/v1",
            "sheet_version",
            "manifest_url",
            "registration_markers",
            "patches",
            "pairs",
            "units",
            "safe_inset_mm",
            "grid_row",
            "first_patch_id",
            "second_patch_id",
            "source_colors",
            "sample_count",
            "clipping_fraction",
            "standard_deviation",
            "lps-ranked-results/v1"
        ]

        for field in requiredFields {
            XCTAssertTrue(
                yaml.contains(field),
                "vendored spec must type \(field); the published spec from viamin/color_matching#110 omits it (see docs/openapi-generated-client-plan.md deltas D1, D2, D5)"
            )
        }
    }

    private static func specContents(file: StaticString = #filePath, line: UInt = #line) throws -> String {
        let url = specURL
        guard FileManager.default.fileExists(atPath: url.path) else {
            XCTFail(
                "OpenAPI document is not vendored at iOS/Sources/ColorMatchingOpenAPI/openapi.yaml — fetch it from viamin/color_matching#110 (GET /api/v1/openapi.json)",
                file: file,
                line: line
            )
            throw NSError(
                domain: "OpenAPISpecVendoringTests", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "missing vendored spec at \(url.path)"]
            )
        }
        return try String(contentsOf: url, encoding: .utf8)
    }
}

private extension OpenAPISpecVendoringTests {
    struct SpecOperation {
        let path: String
        let method: String
        let operationID: String?
    }

    static let httpMethods: Set<String> = [
        "get", "put", "post", "delete", "options", "head", "patch", "trace"
    ]

    static func parseOperations(from yaml: String) -> [SpecOperation] {
        let lines = yaml.split(separator: "\n").map(String.init)
        guard let pathsIndex = lines.firstIndex(where: { $0.trimmingCharacters(in: .whitespaces) == "paths:" }) else {
            return []
        }

        let pathsIndent = indentation(of: lines[pathsIndex])
        var operations: [SpecOperation] = []
        var path: String?
        var pathIndent = Int.max
        var method: String?
        var operationID: String?

        func flushOperation() {
            if let path, let method {
                operations.append(SpecOperation(path: path, method: method, operationID: operationID))
            }
            method = nil
            operationID = nil
        }

        for line in lines[(pathsIndex + 1)...] {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }
            let indent = indentation(of: line)
            if indent <= pathsIndent { break }

            if trimmed.hasPrefix("/") || trimmed.hasPrefix("\"/") {
                flushOperation()
                path = pathKey(from: trimmed)
                pathIndent = indent
            } else if method == nil, indent > pathIndent, trimmed.hasSuffix(":"),
                httpMethods.contains(keyName(from: trimmed))
            {
                method = keyName(from: trimmed)
            } else if trimmed.hasPrefix("operationId:"), method != nil {
                operationID = value(of: trimmed)
            }
        }
        flushOperation()
        return operations
    }

    static func indentation(of line: String) -> Int {
        line.prefix(while: { $0 == " " }).count
    }

    static func pathKey(from line: String) -> String {
        var key = stripColon(line)
        if key.hasPrefix("\"") && key.hasSuffix("\"") {
            key.removeFirst()
            key.removeLast()
        }
        return key
    }

    static func keyName(from line: String) -> String {
        stripColon(line)
    }

    static func stripColon(_ line: String) -> String {
        var key = line
        if key.hasSuffix(":") { key.removeLast() }
        return key.trimmingCharacters(in: .whitespaces)
    }

    static func value(of line: String) -> String {
        guard let separator = line.firstIndex(of: ":") else { return "" }
        var value = String(line[line.index(after: separator)...])
            .trimmingCharacters(in: .whitespaces)
        if value.hasPrefix("\"") && value.hasSuffix("\""), value.count >= 2 {
            value.removeFirst()
            value.removeLast()
        }
        return value
    }
}
