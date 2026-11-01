import Foundation
import XCTest

/// Gates the first deliverable of issue #5 (replace the hand-written API
/// layer with a generated OpenAPI Swift client): the published
/// `color_matching` OpenAPI document must be fetched/vendored into the iOS
/// package before `swift-openapi-generator` has anything to generate from.
///
/// `color_matching` serves its spec at runtime (`GET /api/v1/openapi.json`,
/// viamin/color_matching#110 / PR #113) rather than committing a static
/// file, so vendoring requires a run against a live instance. No such
/// instance is reachable from this environment — see
/// docs/openapi-client-migration-notes.md.
///
/// `testOpenAPIDocumentIsVendoredForGeneration` is an expected RED failure
/// until that vendoring step lands.
final class OpenAPISpecVendoringTests: XCTestCase {
    /// swift-openapi-generator convention: the document and its generator
    /// config live beside the target that consumes them.
    private static let candidatePaths = [
        "Sources/ColorMatchingLPSAppCore/openapi.json",
        "Sources/ColorMatchingLPSAppCore/openapi.yaml"
    ]

    private static let requiredEndpointFragments = [
        "manifest",
        "recent",
        "captures",
        "measurements",
        "judgments",
        "ranked_results"
    ]

    func testOpenAPIDocumentIsVendoredForGeneration() throws {
        let candidates = Self.candidatePaths.map { Self.packageRoot.appendingPathComponent($0) }

        XCTAssertTrue(
            candidates.contains { FileManager.default.fileExists(atPath: $0.path) },
            "Expected the published color_matching OpenAPI document (viamin/color_matching#110 / PR #113) " +
            "vendored at one of \(candidates.map(\.path)) so swift-openapi-generator can build the typed " +
            "client. See docs/openapi-client-migration-notes.md for how to fetch it. (issue #5)"
        )
    }

    func testVendoredOpenAPIDocumentCoversUsedEndpoints() throws {
        guard let specURL = Self.vendoredSpecURL() else {
            throw XCTSkip(
                "No vendored OpenAPI document yet; blocked on the vendoring step tracked by " +
                "testOpenAPIDocumentIsVendoredForGeneration above (issue #5)."
            )
        }

        let contents = try String(contentsOf: specURL, encoding: .utf8)

        for fragment in Self.requiredEndpointFragments {
            XCTAssertTrue(contents.contains(fragment), "Vendored OpenAPI document is missing coverage for '\(fragment)'")
        }
    }

    private static func vendoredSpecURL() -> URL? {
        candidatePaths
            .map { packageRoot.appendingPathComponent($0) }
            .first { FileManager.default.fileExists(atPath: $0.path) }
    }

    /// Walks up from this test file (`iOS/Tests/ColorMatchingLPSAppTests/`) to `iOS/`.
    private static var packageRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
