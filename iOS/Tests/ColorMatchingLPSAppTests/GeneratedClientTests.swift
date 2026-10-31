#if canImport(ColorMatchingOpenAPI)
import Foundation
import XCTest
import ColorMatchingOpenAPI
import OpenAPIURLSession

final class GeneratedClientTests: XCTestCase {
    override func tearDown() {
        GeneratedClientStubURLProtocol.handler = nil
        super.tearDown()
    }

    func testManifestFetchPerformsGetAndDecodesOKBody() async throws {
        var capturedRequest: URLRequest?
        GeneratedClientStubURLProtocol.handler = { request in
            capturedRequest = request
            return Self.jsonResponse(request, 200, Self.manifestJSON)
        }

        let output = try await Self.makeClient().ColorMatchingWeb_TestSheetController_manifest(
            .init(path: .init(sheet_id: "sheet_1"))
        )

        let recorded = try XCTUnwrap(capturedRequest)
        XCTAssertEqual(recorded.httpMethod, "GET")
        XCTAssertEqual(recorded.url?.path, "/api/v1/test_sheets/sheet_1/manifest")

        guard case .ok(let okBody) = output else {
            XCTFail("expected .ok for manifest fetch, got \(output)")
            return
        }
        let manifest = try okBody.body.json
        XCTAssertEqual(manifest.sheet_id, "sheet_1")
        XCTAssertEqual(manifest.schema_version, .lps_sheet_manifest_v1)
        XCTAssertEqual(manifest.capture_profile.scoring_algorithm_version, .lps_distance_v1)
    }

    func testManifestFetchMapsNotFoundResponse() async throws {
        GeneratedClientStubURLProtocol.handler = { request in
            Self.jsonResponse(request, 404, #"{"errors":{"detail":"Sheet not found"}}"#)
        }

        let output = try await Self.makeClient().ColorMatchingWeb_TestSheetController_manifest(
            .init(path: .init(sheet_id: "missing"))
        )

        guard case .notFound = output else {
            XCTFail("expected .notFound for missing sheet, got \(output)")
            return
        }
    }

    func testRecentSheetsDecodesNullableTitle() async throws {
        let payload = #"""
        {"sheets":[
          {"sheet_id":"sheet_1","manifest_url":"https://example.test/api/v1/test_sheets/sheet_1/manifest","title":null},
          {"sheet_id":"sheet_2","manifest_url":"https://example.test/api/v1/test_sheets/sheet_2/manifest","title":"July LPS comparison sheet"}
        ]}
        """#
        GeneratedClientStubURLProtocol.handler = { request in
            Self.jsonResponse(request, 200, payload)
        }

        let output = try await Self.makeClient().ColorMatchingWeb_TestSheetController_recent(.init())

        guard case .ok(let okBody) = output else {
            XCTFail("expected .ok for recent sheets, got \(output)")
            return
        }
        let sheets = try okBody.body.json.sheets
        XCTAssertEqual(sheets.count, 2)
        XCTAssertEqual(sheets.first?.sheet_id, "sheet_1")
        XCTAssertNil(sheets.first?.title)
        XCTAssertEqual(sheets.last?.title, "July LPS comparison sheet")
    }

    func testCreateCapturePostsToCapturePathAndDecodesCreatedBody() async throws {
        var capturedRequest: URLRequest?
        GeneratedClientStubURLProtocol.handler = { request in
            capturedRequest = request
            return Self.jsonResponse(request, 201, #"{"capture_id":"capture_123"}"#)
        }

        let output = try await Self.makeClient().ColorMatchingWeb_CaptureController_create(
            .init(path: .init(sheet_id: "sheet_1"))
        )

        let recorded = try XCTUnwrap(capturedRequest)
        XCTAssertEqual(recorded.httpMethod, "POST")
        XCTAssertEqual(recorded.url?.path, "/api/v1/test_sheets/sheet_1/captures")

        guard case .created(let createdBody) = output else {
            XCTFail("expected .created for capture creation, got \(output)")
            return
        }
        XCTAssertEqual(try createdBody.body.json.capture_id, "capture_123")
    }

    func testUploadMeasurementsEncodesRgbArrayFormAndDecodesCounts() async throws {
        var capturedRequest: URLRequest?
        var capturedBody: Data?
        GeneratedClientStubURLProtocol.handler = { request in
            capturedRequest = request
            capturedBody = request.httpBodyStream.flatMap(Self.readBody) ?? request.httpBody
            return Self.jsonResponse(
                request, 200,
                #"{"capture_id":"capture_123","measurement_count":1,"pair_score_count":0}"#
            )
        }

        let output = try await Self.makeClient().ColorMatchingWeb_CaptureController_upload_measurements(
            .init(
                path: .init(capture_id: "capture_123"),
                body: .json(
                    .init(measurements: [
                        .init(
                            linear_rgb_median: .init(value1: [0.12, 0.1, 0.02]),
                            normalized_linear_rgb_median: .init(value1: [0.15, 0.12, 0.02]),
                            patch_id: "patch_1"
                        )
                    ])
                )
            )
        )

        let recorded = try XCTUnwrap(capturedRequest)
        XCTAssertEqual(recorded.httpMethod, "POST")
        XCTAssertEqual(recorded.url?.path, "/api/v1/captures/capture_123/measurements")
        XCTAssertEqual(recorded.value(forHTTPHeaderField: "Content-Type"), "application/json")

        let json = try XCTUnwrap(Self.jsonObject(from: capturedBody) as? [String: Any])
        let measurements = try XCTUnwrap(json["measurements"] as? [[String: Any]])
        XCTAssertEqual(measurements.first?["patch_id"] as? String, "patch_1")
        XCTAssertEqual(measurements.first?["linear_rgb_median"] as? [Double], [0.12, 0.1, 0.02])
        XCTAssertEqual(measurements.first?["normalized_linear_rgb_median"] as? [Double], [0.15, 0.12, 0.02])

        guard case .ok(let okBody) = output else {
            XCTFail("expected .ok for measurement upload, got \(output)")
            return
        }
        let accepted = try okBody.body.json
        XCTAssertEqual(accepted.capture_id, "capture_123")
        XCTAssertEqual(accepted.measurement_count, 1)
        XCTAssertEqual(accepted.pair_score_count, 0)
    }

    func testUploadJudgmentsEncodesPayloadAndDecodesCount() async throws {
        var capturedRequest: URLRequest?
        var capturedBody: Data?
        GeneratedClientStubURLProtocol.handler = { request in
            capturedRequest = request
            capturedBody = request.httpBodyStream.flatMap(Self.readBody) ?? request.httpBody
            return Self.jsonResponse(request, 200, #"{"capture_id":"capture_123","judgment_count":1}"#)
        }

        let output = try await Self.makeClient().ColorMatchingWeb_CaptureController_upload_judgments(
            .init(
                path: .init(capture_id: "capture_123"),
                body: .json(
                    .init(judgments: [.init(judgment: "near_match", pair_id: "pair_1")])
                )
            )
        )

        let recorded = try XCTUnwrap(capturedRequest)
        XCTAssertEqual(recorded.httpMethod, "POST")
        XCTAssertEqual(recorded.url?.path, "/api/v1/captures/capture_123/judgments")

        let json = try XCTUnwrap(Self.jsonObject(from: capturedBody) as? [String: Any])
        let judgments = try XCTUnwrap(json["judgments"] as? [[String: Any]])
        XCTAssertEqual(judgments.first?["pair_id"] as? String, "pair_1")
        XCTAssertEqual(judgments.first?["judgment"] as? String, "near_match")

        guard case .ok(let okBody) = output else {
            XCTFail("expected .ok for judgment upload, got \(output)")
            return
        }
        XCTAssertEqual(try okBody.body.json.judgment_count, 1)
    }

    func testRankedResultsDecodesSchemaVersion() async throws {
        GeneratedClientStubURLProtocol.handler = { request in
            Self.jsonResponse(request, 200, #"{"schema_version":"lps-ranked-results/v1","sheet_id":"sheet_1"}"#)
        }

        let output = try await Self.makeClient().ColorMatchingWeb_TestSheetController_ranked_results(
            .init(path: .init(sheet_id: "sheet_1"))
        )

        guard case .ok(let okBody) = output else {
            XCTFail("expected .ok for ranked results, got \(output)")
            return
        }
        let ranked = try okBody.body.json
        XCTAssertEqual(ranked.sheet_id, "sheet_1")
        XCTAssertEqual(ranked.schema_version, .lps_ranked_results_v1)
    }

    private static func makeClient() -> Client {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [GeneratedClientStubURLProtocol.self]
        return Client(
            serverURL: URL(string: "https://example.test")!,
            transport: URLSessionTransport(
                configuration: .init(session: URLSession(configuration: configuration))
            )
        )
    }

    private static let manifestJSON = #"""
    {"schema_version":"lps-sheet-manifest/v1","sheet_version":"lps-letter-grid-v1","sheet_id":"sheet_1","manifest_url":"https://example.test/api/v1/test_sheets/sheet_1/manifest","page":{"units":"mm","width":215.9,"height":279.4},"registration_markers":[{"role":"top_left","shape":"solid_square","rect":{"x":12,"y":12,"width":8,"height":8}}],"patches":[{"id":"patch_1","role":"pair_color","pair_id":"pair_1","pair_side":"first","reference_role":null,"source_color":"#FF0000","safe_inset_mm":1.5,"rect":{"x":16,"y":38,"width":16,"height":10}}],"pairs":[{"id":"pair_1","first_patch_id":"patch_1","second_patch_id":"patch_2","source_colors":["#FF0000","#00FF00"],"grid_row":0,"grid_col":1}],"capture_profile":{"scoring_algorithm_version":"lps-distance-v1"}}
    """#

    private static func jsonResponse(_ request: URLRequest, _ status: Int, _ body: String) -> (HTTPURLResponse, Data) {
        (
            HTTPURLResponse(
                url: request.url!,
                statusCode: status,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!,
            Data(body.utf8)
        )
    }

    private static func jsonObject(from data: Data?) throws -> Any {
        try JSONSerialization.jsonObject(with: XCTUnwrap(data))
    }

    private static func readBody(_ stream: InputStream) -> Data {
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 1024)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            if count > 0 {
                data.append(buffer, count)
            } else {
                break
            }
        }
        return data
    }
}

private final class GeneratedClientStubURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        do {
            let (response, data) = try Self.handler!(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
#else
import XCTest

final class GeneratedClientTests: XCTestCase {
    func testGeneratedClientModuleIsAvailable() {
        XCTFail(
            "ColorMatchingOpenAPI module is not generated yet; wire swift-openapi-generator per docs/openapi-client-migration.md"
        )
    }
}
#endif
