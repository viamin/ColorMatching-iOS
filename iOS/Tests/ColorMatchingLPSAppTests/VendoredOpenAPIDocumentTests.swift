import XCTest

final class VendoredOpenAPIDocumentTests: XCTestCase {
    func testVendoredDocumentCoversAppSurfaces() throws {
        let documentURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/ColorMatchingAPI/openapi.yaml")

        let document = try String(contentsOf: documentURL, encoding: .utf8)

        XCTAssertGreaterThanOrEqual(document.count, 1000)
        for marker in Self.requiredMarkers {
            XCTAssertTrue(document.contains(marker), "Vendored OpenAPI document is missing: \(marker)")
        }
    }

    private static let requiredMarkers: [String] = [
        "/api/v1/test_sheets/recent",
        "/api/v1/test_sheets/{sheet_id}/manifest",
        "/api/v1/test_sheets/{sheet_id}/ranked_results",
        "/api/v1/test_sheets/{sheet_id}/captures",
        "/api/v1/captures/{capture_id}/measurements",
        "/api/v1/captures/{capture_id}/judgments",
        "operationId: listRecentTestSheets",
        "operationId: getTestSheetManifest",
        "operationId: getRankedResults",
        "operationId: createCapture",
        "operationId: uploadMeasurements",
        "operationId: uploadJudgments",
        "TestSheetManifest:",
        "RecentSheetsResponse:",
        "CaptureRequest:",
        "CaptureCreatedResponse:",
        "MeasurementUploadRequest:",
        "MeasurementUploadResponse:",
        "JudgmentUploadRequest:",
        "JudgmentUploadResponse:",
        "RankedResultsResponse:",
        "bearerAuth:"
    ]
}
