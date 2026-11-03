import Foundation
import XCTest

final class OpenAPIClientMigrationContractTests: XCTestCase {
    func testOpenAPIClientMigrationHasReproducibleGeneratedClientInputsAndBindings() throws {
        let repository = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let package = try String(contentsOf: repository.appending(path: "Package.swift"))
        let apiClient = try String(contentsOf: repository.appending(path: "Sources/ColorMatchingLPSAppCore/APIClient.swift"))
        let specification = repository.appending(path: "OpenAPI/openapi.json")
        var missing = [String]()

        require("swift-openapi-generator", in: package, missing: &missing)
        require("swift-openapi-runtime", in: package, missing: &missing)
        require("OpenAPIGenerator", in: package, missing: &missing)

        guard FileManager.default.fileExists(atPath: specification.path) else {
            missing.append("vendored OpenAPI document at iOS/OpenAPI/openapi.json")
            return assertNoMissingRequirements(missing)
        }

        let document = try Data(contentsOf: specification)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: document) as? [String: Any])
        XCTAssertNotNil(object["openapi"], "The vendored document must be an OpenAPI document.")
        let paths = try XCTUnwrap(object["paths"] as? [String: Any])
        for path in [
            "/api/v1/test_sheets/{sheet_id}/manifest",
            "/api/v1/test_sheets/recent",
            "/api/v1/test_sheets/{sheet_id}/captures",
            "/api/v1/captures/{capture_id}/measurements",
            "/api/v1/captures/{capture_id}/judgments",
            "/api/v1/test_sheets/{sheet_id}/ranked_results"
        ] where paths[path] == nil {
            missing.append("OpenAPI path \\(path)")
        }

        require("import ColorMatchingAPI", in: apiClient, missing: &missing)
        require("fetchRankedResults", in: apiClient, missing: &missing)
        for model in ["CaptureMetadata", "WhiteBalanceGains", "CaptureSessionResponse", "RecentSheet", "PairJudgment"] where apiClient.contains("struct \\(model)") {
            missing.append("replacement of hand-written \\(model) API model")
        }
        assertNoMissingRequirements(missing)
    }

    private func require(_ requirement: String, in source: String, missing: inout [String]) {
        if !source.contains(requirement) { missing.append(requirement) }
    }

    private func assertNoMissingRequirements(_ missing: [String]) {
        if !missing.isEmpty { XCTFail("OpenAPI client migration is incomplete:\\n- " + missing.joined(separator: "\\n- ")) }
    }
}
