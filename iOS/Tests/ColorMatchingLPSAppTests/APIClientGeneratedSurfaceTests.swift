import XCTest
import MeasurementCore
@testable import ColorMatchingLPSAppCore

final class APIClientGeneratedSurfaceTests: XCTestCase {
    private let baseURL = URL(string: "https://example.test")!

    override func tearDown() {
        APIStubURLProtocol.handler = nil
        super.tearDown()
    }

    func testFetchManifestDecodesSpecShapedManifest() async throws {
        stub(200, OpenAPIFixtures.manifest)

        let manifest = try await client().fetchManifest(baseURL: baseURL, sheetCode: "sheet_1")

        XCTAssertEqual(manifest.schemaVersion, "lps-sheet-manifest/v1")
        XCTAssertEqual(manifest.sheetID, "sheet_1")
        XCTAssertEqual(manifest.patches.map(\.id), ["pair_1#first", "pair_1#second"])
        XCTAssertEqual(manifest.pairs.first?.firstPatchID, "pair_1#first")
    }

    func testFetchRecentSheetsDecodesNullableTitles() async throws {
        stub(200, OpenAPIFixtures.recentSheets)

        let sheets = try await client().fetchRecentSheets(baseURL: baseURL)

        XCTAssertEqual(sheets.map(\.sheetID), ["sheet_1", "sheet_2"])
        XCTAssertNil(sheets.first?.title)
        XCTAssertEqual(sheets.last?.title, "July LPS comparison sheet")
    }

    func testCreateCaptureDecodesIntegerStringCaptureID() async throws {
        var capturedRequest: URLRequest?
        stub(201, OpenAPIFixtures.captureCreated) { capturedRequest = $0 }

        let response = try await client().createCapture(
            sheetID: "sheet_1",
            baseURL: baseURL,
            metadata: OpenAPIFixtures.makeMetadata(),
            quality: CaptureQuality(detectedMarkerCount: 4, blurScore: 0.82, rejections: [])
        )

        XCTAssertEqual(response.captureID, "42")
        XCTAssertEqual(capturedRequest?.url?.path, "/api/v1/test_sheets/sheet_1/captures")
    }

    func testUploadMeasurementsReturnsSpecReceipt() async throws {
        stub(200, OpenAPIFixtures.measurementUploadResponse)

        let receipt = try await client().uploadMeasurements(
            captureID: "42",
            baseURL: baseURL,
            measurements: [OpenAPIFixtures.makeMeasurement()],
            scores: [PairScore(pairID: "pair_1", distance: 0.035, similarity: 0.965, algorithmVersion: LPSScorer.algorithmVersion)]
        )

        XCTAssertEqual(receipt, MeasurementUploadReceipt(captureID: "42", measurementCount: 2, pairScoreCount: 1))
    }

    func testUploadJudgmentsReturnsSpecReceipt() async throws {
        stub(200, OpenAPIFixtures.judgmentUploadResponse)

        let receipt = try await client().uploadJudgments(
            captureID: "42",
            baseURL: baseURL,
            judgments: [PairJudgment(pairID: "pair_1", judgment: "near_match")]
        )

        XCTAssertEqual(receipt, JudgmentUploadReceipt(captureID: "42", judgmentCount: 1))
    }

    func testFetchRankedResultsDecodesSpecPayload() async throws {
        var capturedRequest: URLRequest?
        stub(200, OpenAPIFixtures.rankedResults) { capturedRequest = $0 }

        let results = try await client().fetchRankedResults(sheetID: "sheet_1", baseURL: baseURL)

        XCTAssertEqual(capturedRequest?.url?.path, "/api/v1/test_sheets/sheet_1/ranked_results")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.pairID, "pair_1")
        XCTAssertEqual(results.first?.rank, 1)
        XCTAssertEqual(results.first?.colorAHex, "#FF0000")
        XCTAssertEqual(results.first?.colorBHex, "#00FF00")
        XCTAssertEqual(results.first?.currentJudgment, "near_match")
        XCTAssertEqual(results.first?.averageScore ?? 0, 0.04, accuracy: 0.0001)
    }

    func testUnauthorizedSurfacesTypedError() async {
        stub(401, OpenAPIFixtures.errorResponse)

        await assertThrows(APIError.unauthorized) {
            _ = try await self.client().fetchRecentSheets(baseURL: self.baseURL)
        }
    }

    func testNotFoundSurfacesTypedError() async {
        stub(404, OpenAPIFixtures.errorResponse)

        await assertThrows(APIError.notFound) {
            _ = try await self.client().fetchManifest(baseURL: self.baseURL, sheetCode: "missing")
        }
    }

    func testValidationErrorSurfacesTypedError() async {
        stub(422, OpenAPIFixtures.errorResponse)

        await assertThrows(APIError.validationFailed) {
            _ = try await self.client().createCapture(
                sheetID: "sheet_1",
                baseURL: self.baseURL,
                metadata: OpenAPIFixtures.makeMetadata(),
                quality: CaptureQuality(detectedMarkerCount: 0, blurScore: 0, rejections: ["excessiveBlur"])
            )
        }
    }
}

private extension APIClientGeneratedSurfaceTests {
    func client() -> APIClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [APIStubURLProtocol.self]
        return APIClient(token: "token", session: URLSession(configuration: configuration))
    }

    func stub(_ status: Int, _ fixture: String, capture: @escaping (URLRequest) -> Void = { _ in }) {
        APIStubURLProtocol.handler = { request in
            capture(request)
            return (
                HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!,
                OpenAPIFixtures.jsonData(fixture)
            )
        }
    }

    func assertThrows(_ expected: APIError, _ operation: () async throws -> Void) async {
        do {
            try await operation()
            XCTFail("expected \(expected)")
        } catch {
            guard let actual = error as? APIError, actual == expected else {
                return XCTFail("expected \(expected), got \(error)")
            }
        }
    }
}

private final class APIStubURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        do {
            let (response, data) = try Self.handler?(request) ?? (
                HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!,
                Data()
            )
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
