import XCTest

/// Tracks acceptance criteria from #5 ("Replace hand-written API layer with a
/// generated OpenAPI Swift client") that cannot be exercised yet because the
/// generated client does not exist in this test-writing run: adding
/// swift-openapi-generator/-runtime and vendoring the spec requires editing
/// `Package.swift`, which is an implementation change out of scope here. Each
/// test is a tracked placeholder, not a false pass, until the implementation
/// run wires in the generated client.
final class GeneratedClientMigrationTests: XCTestCase {
    func testFetchRankedResultsAgainstGeneratedClient() async throws {
        throw XCTSkip("APIClient has no ranked-results method yet; blocked on generated OpenAPI client wiring, see #5")
    }

    func testStructuredErrorResponseIsSurfacedByGeneratedClient() async throws {
        throw XCTSkip("Non-2xx responses only surface APIError.badStatus with no body today; typed ApiErrorResponse decoding is blocked on generated OpenAPI client wiring, see #5")
    }
}
