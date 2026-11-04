import XCTest

final class GeneratedOpenAPIClientTests: XCTestCase {
    func testGeneratedOpenAPIClientModuleIsAvailable() {
        #if canImport(ColorMatchingOpenAPI)
        XCTAssertTrue(true)
        #else
        XCTFail("Add the generated ColorMatchingOpenAPI client target before replacing the hand-written API layer.")
        #endif
    }
}
