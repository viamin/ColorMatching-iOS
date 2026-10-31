import Foundation
import XCTest

/// Pins the deliverables of issue #5 ("Replace hand-written API layer with a
/// generated OpenAPI Swift client") that cannot be exercised through the
/// public Swift API yet because the implementation does not exist. These
/// assertions read package/source text directly so they compile and run
/// today, fail for the right reason (missing deliverable, not a build
/// break), and will flip green once the generated client lands.
///
/// Blocked on viamin/color_matching#110: this sandbox's GitHub API proxy
/// only reaches this repo (`viamin/ColorMatching-iOS`), so the published
/// OpenAPI document cannot be fetched or vendored from here. See
/// docs/openapi-client-migration-notes.md.
final class OpenAPIMigrationReadinessTests: XCTestCase {
    private var packageRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // ColorMatchingLPSAppTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // iOS
    }

    func testPackageDeclaresSwiftOpenAPIDependencies() throws {
        let packageSwift = try String(contentsOf: packageRoot.appendingPathComponent("Package.swift"), encoding: .utf8)

        XCTAssertTrue(
            packageSwift.contains("swift-openapi-generator"),
            "Package.swift should depend on swift-openapi-generator so client code can be generated from the published OpenAPI document (viamin/color_matching#110)."
        )
        XCTAssertTrue(
            packageSwift.contains("swift-openapi-runtime"),
            "Package.swift should depend on swift-openapi-runtime to support the generated client at runtime."
        )
    }

    func testOpenAPIDocumentIsVendoredSomewhereInThePackage() throws {
        let fm = FileManager.default
        let candidates = try fm.subpathsOfDirectory(atPath: packageRoot.path)
            .filter { $0.hasSuffix(".yaml") || $0.hasSuffix(".yml") || $0.hasSuffix(".json") }
            .filter { $0.lowercased().contains("openapi") }

        XCTAssertFalse(
            candidates.isEmpty,
            "Expected an OpenAPI document vendored under iOS/ (fetched from viamin/color_matching#110) for swift-openapi-generator to consume at build time."
        )
    }

    func testAPIClientSourceExposesRankedResultsSurface() throws {
        let apiClientSource = try String(
            contentsOf: packageRoot.appendingPathComponent("Sources/ColorMatchingLPSAppCore/APIClient.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(
            apiClientSource.contains("ranked_results"),
            "docs/color-matching-api-contract.md documents GET /api/v1/test_sheets/:sheet_id/ranked_results, but APIClient.swift has no call for it yet. The generated client must cover this surface, not just the four surfaces implemented today."
        )
    }
}
