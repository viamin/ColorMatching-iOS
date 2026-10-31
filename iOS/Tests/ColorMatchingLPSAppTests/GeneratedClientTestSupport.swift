import ColorMatchingOpenAPI
import Foundation
import OpenAPIRuntime
import XCTest

enum SpecFixtures {
    static let baseURL = URL(string: "https://example.test")!

    static func data(_ json: String) -> Data {
        Data(json.utf8)
    }

    static let manifestJSON = """
    {
      "schema_version": "lps-sheet-manifest/v1",
      "sheet_version": "lps-letter-grid-v1",
      "sheet_id": "sheet_123",
      "manifest_url": "https://example.test/api/v1/test_sheets/sheet_123/manifest",
      "created_at": "2026-07-25T12:00:00Z",
      "page": {"units": "mm", "width": 215.9, "height": 279.4},
      "registration_markers": [
        {"role": "top_left", "shape": "solid_square", "rect": {"x": 12, "y": 12, "width": 8, "height": 8}}
      ],
      "printer_profile": {
        "printer_make_model": "Canon PIXMA",
        "paper_type": "Plain",
        "ink_type": "Dye",
        "icc_profile": null,
        "print_settings": {},
        "driver_name": null,
        "driver_version": null,
        "calibration_date": null,
        "calibration_version": null,
        "notes": null
      },
      "capture_profile": {
        "expected_illuminant": "low_pressure_sodium",
        "preferred_camera": "built_in_wide_angle_rear",
        "scoring_algorithm_version": "lps-distance-v1"
      },
      "patches": [
        {
          "id": "pair_1#first",
          "role": "pair_color",
          "pair_id": "pair_1",
          "pair_side": "first",
          "reference_role": null,
          "source_color": "#FF0000",
          "safe_inset_mm": 1.5,
          "rect": {"x": 16, "y": 38, "width": 16, "height": 10}
        }
      ],
      "pairs": [
        {
          "id": "pair_1",
          "first_patch_id": "pair_1#first",
          "second_patch_id": "pair_1#second",
          "source_colors": ["#FF0000", "#00FF00"],
          "grid_row": 0,
          "grid_col": 1
        }
      ]
    }
    """

    static let recentSheetsJSON = """
    {
      "sheets": [
        {
          "sheet_id": "sheet_123",
          "manifest_url": "https://example.test/api/v1/test_sheets/sheet_123/manifest",
          "title": null
        }
      ]
    }
    """

    static let rankedResultsJSON = """
    {
      "schema_version": "lps-ranked-results/v1",
      "sheet_id": "sheet_123",
      "printer_profile": {
        "printer_make_model": "Canon PIXMA",
        "paper_type": "Plain",
        "ink_type": "Dye",
        "icc_profile": null,
        "print_settings": {},
        "driver_name": null,
        "driver_version": null,
        "calibration_date": null,
        "calibration_version": null,
        "notes": null
      },
      "capture_count": 2,
      "latest_capture_at": "2026-07-25T12:30:00Z",
      "earliest_capture_at": "2026-07-25T12:00:00Z",
      "scoring_algorithm_versions": ["lps-distance-v1"],
      "results": [
        {
          "rank": 1,
          "pair_id": "pair_1",
          "scoring_algorithm_version": "lps-distance-v1",
          "row": 0,
          "col": 1,
          "source_colors": {"color_a_hex": "#FF0000", "color_b_hex": "#00FF00"},
          "score": {
            "average": 0.965,
            "latest": 0.96,
            "minimum": 0.95,
            "maximum": 0.97,
            "capture_count": 2,
            "sample_count": 4,
            "algorithm_versions": ["lps-distance-v1"]
          },
          "current_judgment": "near_match",
          "current_judgment_observed_at": "2026-07-25T12:35:00Z",
          "observation_count": 1,
          "latest_observation": {"judgment": "near_match", "observed_at": "2026-07-25T12:35:00Z"},
          "capture_count": 2,
          "latest_capture_at": "2026-07-25T12:30:00Z",
          "earliest_capture_at": "2026-07-25T12:00:00Z"
        }
      ]
    }
    """

    static let captureCreatedJSON = """
    {"capture_id": "12"}
    """

    static let measurementUploadJSON = """
    {"capture_id": "12", "measurement_count": 1, "pair_score_count": 1}
    """

    static let judgmentUploadJSON = """
    {"capture_id": "12", "judgment_count": 1}
    """

    static let sheetNotFoundJSON = """
    {"errors": {"detail": "Sheet not found"}}
    """
}

enum FixedDates {
    static let july25Noon = iso8601("2026-07-25T12:00:00Z")

    private static func iso8601(_ string: String) -> Date {
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: string)!
    }
}

struct RecordedRequest {
    var method: String
    var path: String?
    var operationID: String
    var authorization: String?
    var contentType: String?
    var body: Data?
}

final class RecordingTransport: ClientTransport, @unchecked Sendable {
    private let lock = NSLock()
    private var recordedRequests: [RecordedRequest] = []
    private let status: HTTPResponse.Status
    private let body: Data?

    init(status: HTTPResponse.Status = .ok, body: Data? = nil) {
        self.status = status
        self.body = body
    }

    var requests: [RecordedRequest] {
        lock.lock()
        defer { lock.unlock() }
        return recordedRequests
    }

    func send(_ request: HTTPRequest, body: HTTPBody?, baseURL: URL, operationID: String) async throws -> (HTTPResponse, HTTPBody?) {
        let collectedBody: Data?
        if let body {
            collectedBody = try await Data(collecting: body, upTo: 1 << 20)
        } else {
            collectedBody = nil
        }
        record(
            RecordedRequest(
                method: request.method.rawValue,
                path: request.path,
                operationID: operationID,
                authorization: request.headerFields[.authorization],
                contentType: request.headerFields[.contentType],
                body: collectedBody
            )
        )
        return (response, self.body.map { HTTPBody($0) })
    }

    private var response: HTTPResponse {
        var response = HTTPResponse(status: status)
        if body != nil {
            response.headerFields = ["content-type": "application/json"]
        }
        return response
    }

    private func record(_ request: RecordedRequest) {
        lock.lock()
        defer { lock.unlock() }
        recordedRequests.append(request)
    }
}

final class StubURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        do {
            let (response, data) = try Self.handler.map { try $0(request) } ?? (
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

enum StubbedHTTP {
    static func response(url: URL, status: Int, json: String) -> (HTTPURLResponse, Data) {
        (
            HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!,
            SpecFixtures.data(json)
        )
    }

    static func emptyResponse(url: URL, status: Int) -> (HTTPURLResponse, Data) {
        (HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil)!, Data())
    }

    static func jsonObject(from data: Data?) throws -> Any {
        try JSONSerialization.jsonObject(with: XCTUnwrap(data))
    }

    static func readBody(of request: URLRequest) -> Data {
        if let body = request.httpBody {
            return body
        }
        guard let stream = request.httpBodyStream else {
            return Data()
        }
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            if count > 0 {
                data.append(buffer, count: count)
            } else {
                break
            }
        }
        return data
    }
}

extension XCTestCase {
    func assertFullManifestDecoded(_ manifest: ColorMatchingOpenAPI.Components.Schemas.TestSheetManifest) {
        XCTAssertEqual(manifest.schemaVersion.rawValue, "lps-sheet-manifest/v1")
        XCTAssertEqual(manifest.sheetId, "sheet_123")
        XCTAssertEqual(manifest.sheetVersion, "lps-letter-grid-v1")
        XCTAssertEqual(manifest.manifestUrl, "https://example.test/api/v1/test_sheets/sheet_123/manifest")
        XCTAssertEqual(manifest.createdAt, FixedDates.july25Noon)
        XCTAssertEqual(manifest.page.units, "mm")
        XCTAssertEqual(manifest.page.width, 215.9, accuracy: 0.0001)
        XCTAssertEqual(manifest.registrationMarkers.first?.role, "top_left")
        XCTAssertEqual(manifest.registrationMarkers.first?.shape, "solid_square")
        let patch = manifest.patches.first
        XCTAssertEqual(patch?.id, "pair_1#first")
        XCTAssertEqual(patch?.role, "pair_color")
        XCTAssertEqual(patch?.pairId, "pair_1")
        XCTAssertEqual(patch?.pairSide, "first")
        XCTAssertNil(patch?.referenceRole)
        XCTAssertEqual(patch?.sourceColor, "#FF0000")
        XCTAssertEqual(patch?.safeInsetMm, 1.5, accuracy: 0.0001)
        XCTAssertEqual(patch?.rect.x, 16, accuracy: 0.0001)
        XCTAssertEqual(patch?.rect.width, 16, accuracy: 0.0001)
        let pair = manifest.pairs.first
        XCTAssertEqual(pair?.id, "pair_1")
        XCTAssertEqual(pair?.firstPatchId, "pair_1#first")
        XCTAssertEqual(pair?.secondPatchId, "pair_1#second")
        XCTAssertEqual(pair?.sourceColors, ["#FF0000", "#00FF00"])
        XCTAssertEqual(pair?.gridRow, 0)
        XCTAssertEqual(pair?.gridCol, 1)
        XCTAssertEqual(manifest.printerProfile.printerMakeModel, "Canon PIXMA")
        XCTAssertEqual(manifest.captureProfile.scoringAlgorithmVersion.rawValue, "lps-distance-v1")
    }
}
