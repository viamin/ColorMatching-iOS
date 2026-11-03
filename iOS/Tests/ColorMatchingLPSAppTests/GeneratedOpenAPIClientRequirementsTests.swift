import Foundation
import XCTest

final class GeneratedOpenAPIClientRequirementsTests: XCTestCase {
    func testPackageDeclaresGeneratedOpenAPIClientAndVendoredSpecification() throws {
        let package = try String(contentsOf: repositoryRoot.appending(path: "iOS/Package.swift"))

        XCTAssertTrue(package.contains("swift-openapi-generator"))
        XCTAssertTrue(package.contains("swift-openapi-runtime"))
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: repositoryRoot.appending(path: "iOS/OpenAPI/color-matching-api-v1.json").path),
            "Vendor the document served by color_matching at /api/v1/openapi.json so client generation is reproducible."
        )
    }

    func testAPILayerContainsNoHandWrittenServerDTOsOrTransport() throws {
        let apiLayer = try String(contentsOf: repositoryRoot.appending(path: "iOS/Sources/ColorMatchingLPSAppCore/APIClient.swift"))

        XCTAssertFalse(apiLayer.contains("URLSession"))
        XCTAssertFalse(apiLayer.contains("CaptureMetadata"))
        XCTAssertFalse(apiLayer.contains("CaptureSessionResponse"))
        XCTAssertFalse(apiLayer.contains("RecentSheet"))
        XCTAssertFalse(apiLayer.contains("PairJudgment"))
    }

    func testAPILayerExposesRankedResultsOperation() throws {
        let apiLayer = try String(contentsOf: repositoryRoot.appending(path: "iOS/Sources/ColorMatchingLPSAppCore/APIClient.swift"))

        XCTAssertTrue(apiLayer.contains("ranked_results"))
    }

    private var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
