import Foundation
import MeasurementCore

public struct APIClient {
    public var token: String?
    public var session: URLSession

    public init(token: String? = nil, session: URLSession = .shared) {
        self.token = token
        self.session = session
    }

    public func fetchManifest(from url: URL) async throws -> SheetManifest {
        try await decodedResponse(SheetManifest.self, for: authorizedRequest(url: url))
    }

    public func fetchManifest(baseURL: URL, sheetCode: String) async throws -> SheetManifest {
        let url = baseURL.appending(path: "api/v1/test_sheets/\(sheetCode)/manifest")
        return try await fetchManifest(from: url)
    }

    public func fetchRecentSheets(baseURL: URL) async throws -> [RecentSheet] {
        let url = baseURL.appending(path: "api/v1/test_sheets/recent")
        return try await decodedResponse(RecentSheetsResponse.self, for: authorizedRequest(url: url)).sheets
    }

    public func createCapture(sheetID: String, baseURL: URL, metadata: CaptureMetadata, quality: CaptureQuality) async throws -> CaptureSessionResponse {
        let url = baseURL.appending(path: "api/v1/test_sheets/\(sheetID)/captures")
        let request = try authorizedRequest(url: url, method: "POST", body: CreateCaptureRequest(metadata: metadata, quality: quality))
        return try await decodedResponse(CaptureSessionResponse.self, for: request)
    }

    public func uploadMeasurements(captureID: String, baseURL: URL, measurements: [PatchMeasurement], scores: [PairScore]) async throws {
        let url = baseURL.appending(path: "api/v1/captures/\(captureID)/measurements")
        let request = try authorizedRequest(
            url: url,
            method: "POST",
            body: MeasurementUploadRequest(scoringAlgorithmVersion: LPSScorer.algorithmVersion, measurements: measurements.map(MeasurementUpload.init), pairScores: scores)
        )
        try await send(request)
    }

    public func uploadJudgments(captureID: String, baseURL: URL, judgments: [PairJudgment]) async throws {
        let url = baseURL.appending(path: "api/v1/captures/\(captureID)/judgments")
        let request = try authorizedRequest(url: url, method: "POST", body: JudgmentUploadRequest(judgments: judgments))
        try await send(request)
    }

    private func authorizedRequest(url: URL, method: String = "GET") -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        authorize(&request)
        return request
    }

    private func authorizedRequest<Body: Encodable>(url: URL, method: String, body: Body) throws -> URLRequest {
        var request = authorizedRequest(url: url, method: method)
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder.snakeCase.encode(body)
        return request
    }

    private func decodedResponse<T: Decodable>(_ type: T.Type, for request: URLRequest) async throws -> T {
        let (data, response) = try await session.data(for: request)
        try validate(response)
        return try JSONDecoder.snakeCase.decode(type, from: data)
    }

    private func send(_ request: URLRequest) async throws {
        let (_, response) = try await session.data(for: request)
        try validate(response)
    }

    private func authorize(_ request: inout URLRequest) {
        if let token, !token.isEmpty {
            request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
    }

    private func validate(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw APIError.badStatus
        }
    }
}

public struct CaptureMetadata: Codable {
    public var deviceModel: String
    public var lens: String
    public var exposureDurationSeconds: Double?
    public var iso: Float?
    public var focusLensPosition: Float?
    public var whiteBalanceGains: WhiteBalanceGains?
    public var imageWidth: Int?
    public var imageHeight: Int?
    public var appVersion: String
    public var timestamp: Date

    public init(
        deviceModel: String,
        lens: String,
        exposureDurationSeconds: Double?,
        iso: Float?,
        focusLensPosition: Float?,
        whiteBalanceGains: WhiteBalanceGains?,
        imageWidth: Int?,
        imageHeight: Int?,
        appVersion: String,
        timestamp: Date
    ) {
        self.deviceModel = deviceModel
        self.lens = lens
        self.exposureDurationSeconds = exposureDurationSeconds
        self.iso = iso
        self.focusLensPosition = focusLensPosition
        self.whiteBalanceGains = whiteBalanceGains
        self.imageWidth = imageWidth
        self.imageHeight = imageHeight
        self.appVersion = appVersion
        self.timestamp = timestamp
    }

    enum CodingKeys: String, CodingKey {
        case deviceModel = "device_model"
        case lens
        case exposureDurationSeconds = "exposure_duration_seconds"
        case iso
        case focusLensPosition = "focus_lens_position"
        case whiteBalanceGains = "white_balance_gains"
        case imageWidth = "image_width"
        case imageHeight = "image_height"
        case appVersion = "app_version"
        case timestamp
    }
}

public struct WhiteBalanceGains: Codable {
    public var red: Float
    public var green: Float
    public var blue: Float

    public init(red: Float, green: Float, blue: Float) {
        self.red = red
        self.green = green
        self.blue = blue
    }
}

public struct CaptureSessionResponse: Codable {
    public var captureID: String
    enum CodingKeys: String, CodingKey { case captureID = "capture_id" }
}

public struct RecentSheet: Codable, Identifiable {
    public var id: String { sheetID }
    public var sheetID: String
    public var manifestURL: URL
    public var title: String?

    enum CodingKeys: String, CodingKey {
        case sheetID = "sheet_id"
        case manifestURL = "manifest_url"
        case title
    }
}

private struct RecentSheetsResponse: Codable {
    var sheets: [RecentSheet]
}

private struct CreateCaptureRequest: Codable {
    var metadata: CaptureMetadata
    var quality: CaptureQuality
}

private struct MeasurementUploadRequest: Codable {
    var scoringAlgorithmVersion: String
    var measurements: [MeasurementUpload]
    var pairScores: [PairScore]

    enum CodingKeys: String, CodingKey {
        case scoringAlgorithmVersion = "scoring_algorithm_version"
        case measurements
        case pairScores = "pair_scores"
    }
}

private struct MeasurementUpload: Codable {
    var patchID: String
    var linearRGBMedian: RGB
    var normalizedLinearRGBMedian: RGB?
    var stats: MeasurementStatsUpload

    init(_ measurement: PatchMeasurement) {
        patchID = measurement.patchID
        linearRGBMedian = measurement.linearRGBMedian
        normalizedLinearRGBMedian = measurement.normalizedLinearRGBMedian
        stats = MeasurementStatsUpload(measurement.stats)
    }

    enum CodingKeys: String, CodingKey {
        case patchID = "patch_id"
        case linearRGBMedian = "linear_rgb_median"
        case normalizedLinearRGBMedian = "normalized_linear_rgb_median"
        case stats
    }
}

private struct MeasurementStatsUpload: Codable {
    var sampleCount: Int
    var clippingFraction: Double
    var mean: RGB
    var standardDeviation: RGB

    init(_ stats: ChannelStats) {
        sampleCount = stats.sampleCount
        clippingFraction = stats.clippingFraction
        mean = stats.mean
        standardDeviation = stats.standardDeviation
    }

    enum CodingKeys: String, CodingKey {
        case sampleCount = "sample_count"
        case clippingFraction = "clipping_fraction"
        case mean
        case standardDeviation = "standard_deviation"
    }
}

private struct JudgmentUploadRequest: Codable {
    var judgments: [PairJudgment]
}

public struct PairJudgment: Codable, Identifiable {
    public var id: String { pairID }
    public var pairID: String
    public var judgment: String

    public init(pairID: String, judgment: String) {
        self.pairID = pairID
        self.judgment = judgment
    }

    enum CodingKeys: String, CodingKey { case pairID = "pair_id"; case judgment }
}

public enum APIError: Error {
    case badStatus
}

private extension JSONDecoder {
    static var snakeCase: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

private extension JSONEncoder {
    static var snakeCase: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}
