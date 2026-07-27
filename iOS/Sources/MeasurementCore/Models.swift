import Foundation

public struct RGB: Codable, Equatable {
    public var r: Double
    public var g: Double
    public var b: Double

    public init(r: Double, g: Double, b: Double) {
        self.r = r
        self.g = g
        self.b = b
    }
}

public struct Point: Codable, Equatable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

public struct Rect: Codable, Equatable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    public func inset(by amount: Double) -> Rect {
        Rect(x: x + amount, y: y + amount, width: max(0, width - amount * 2), height: max(0, height - amount * 2))
    }

    public var corners: [Point] {
        [
            Point(x: x, y: y),
            Point(x: x + width, y: y),
            Point(x: x + width, y: y + height),
            Point(x: x, y: y + height)
        ]
    }

    public static func bounding(_ points: [Point]) -> Rect? {
        guard let first = points.first else { return nil }

        var minX = first.x
        var maxX = first.x
        var minY = first.y
        var maxY = first.y

        for point in points.dropFirst() {
            minX = Swift.min(minX, point.x)
            maxX = Swift.max(maxX, point.x)
            minY = Swift.min(minY, point.y)
            maxY = Swift.max(maxY, point.y)
        }

        return Rect(x: minX, y: minY, width: Swift.max(0, maxX - minX), height: Swift.max(0, maxY - minY))
    }
}

public struct Page: Codable, Equatable {
    public var units: String
    public var width: Double
    public var height: Double
}

public struct RegistrationMarker: Codable, Equatable {
    public var role: String
    public var shape: String
    public var rect: Rect
}

public struct Patch: Codable, Equatable, Identifiable {
    public var id: String
    public var role: String
    public var pairID: String?
    public var pairSide: String?
    public var referenceRole: String?
    public var sourceColor: String?
    public var safeInsetMM: Double
    public var rect: Rect

    public init(id: String, role: String, pairID: String?, pairSide: String?, referenceRole: String?, sourceColor: String?, safeInsetMM: Double, rect: Rect) {
        self.id = id
        self.role = role
        self.pairID = pairID
        self.pairSide = pairSide
        self.referenceRole = referenceRole
        self.sourceColor = sourceColor
        self.safeInsetMM = safeInsetMM
        self.rect = rect
    }

    enum CodingKeys: String, CodingKey {
        case id, role, rect
        case pairID = "pair_id"
        case pairSide = "pair_side"
        case referenceRole = "reference_role"
        case sourceColor = "source_color"
        case safeInsetMM = "safe_inset_mm"
    }
}

public struct PairManifest: Codable, Equatable, Identifiable {
    public var id: String
    public var gridRow: Int
    public var gridCol: Int
    public var firstPatchID: String
    public var secondPatchID: String
    public var sourceColors: [String]

    public init(id: String, gridRow: Int, gridCol: Int, firstPatchID: String, secondPatchID: String, sourceColors: [String]) {
        self.id = id
        self.gridRow = gridRow
        self.gridCol = gridCol
        self.firstPatchID = firstPatchID
        self.secondPatchID = secondPatchID
        self.sourceColors = sourceColors
    }

    enum CodingKeys: String, CodingKey {
        case id
        case gridRow = "grid_row"
        case gridCol = "grid_col"
        case firstPatchID = "first_patch_id"
        case secondPatchID = "second_patch_id"
        case sourceColors = "source_colors"
    }
}

public struct SheetManifest: Codable, Equatable {
    public var schemaVersion: String
    public var sheetVersion: String
    public var sheetID: String
    public var manifestURL: URL
    public var page: Page
    public var registrationMarkers: [RegistrationMarker]
    public var patches: [Patch]
    public var pairs: [PairManifest]

    enum CodingKeys: String, CodingKey {
        case page, patches, pairs
        case schemaVersion = "schema_version"
        case sheetVersion = "sheet_version"
        case sheetID = "sheet_id"
        case manifestURL = "manifest_url"
        case registrationMarkers = "registration_markers"
    }
}

public struct ChannelStats: Codable, Equatable {
    public var median: RGB
    public var mean: RGB
    public var standardDeviation: RGB
    public var min: RGB
    public var max: RGB
    public var sampleCount: Int
    public var clippingFraction: Double

    public init(median: RGB, mean: RGB, standardDeviation: RGB, min: RGB, max: RGB, sampleCount: Int, clippingFraction: Double) {
        self.median = median
        self.mean = mean
        self.standardDeviation = standardDeviation
        self.min = min
        self.max = max
        self.sampleCount = sampleCount
        self.clippingFraction = clippingFraction
    }

    enum CodingKeys: String, CodingKey {
        case median, mean, min, max
        case standardDeviation = "standard_deviation"
        case sampleCount = "sample_count"
        case clippingFraction = "clipping_fraction"
    }
}

public struct PatchMeasurement: Codable, Equatable, Identifiable {
    public var id: String { patchID }
    public var patchID: String
    public var linearRGBMedian: RGB
    public var normalizedLinearRGBMedian: RGB?
    public var stats: ChannelStats

    public init(patchID: String, linearRGBMedian: RGB, normalizedLinearRGBMedian: RGB? = nil, stats: ChannelStats) {
        self.patchID = patchID
        self.linearRGBMedian = linearRGBMedian
        self.normalizedLinearRGBMedian = normalizedLinearRGBMedian
        self.stats = stats
    }

    enum CodingKeys: String, CodingKey {
        case patchID = "patch_id"
        case linearRGBMedian = "linear_rgb_median"
        case normalizedLinearRGBMedian = "normalized_linear_rgb_median"
        case stats
    }
}

public struct PairScore: Codable, Equatable, Identifiable {
    public var id: String { pairID }
    public var pairID: String
    public var distance: Double
    public var similarity: Double
    public var algorithmVersion: String

    public init(pairID: String, distance: Double, similarity: Double, algorithmVersion: String) {
        self.pairID = pairID
        self.distance = distance
        self.similarity = similarity
        self.algorithmVersion = algorithmVersion
    }

    enum CodingKeys: String, CodingKey {
        case distance, similarity
        case pairID = "pair_id"
        case algorithmVersion = "algorithm_version"
    }
}

public struct DetectedMarker: Codable, Equatable {
    public var role: String
    public var center: Point
    public var bounds: Rect

    public init(role: String, center: Point, bounds: Rect) {
        self.role = role
        self.center = center
        self.bounds = bounds
    }
}

public struct CaptureQuality: Codable, Equatable {
    public var detectedMarkerCount: Int
    public var blurScore: Double
    public var rejections: [CaptureRejection]

    public init(detectedMarkerCount: Int, blurScore: Double, rejections: [CaptureRejection]) {
        self.detectedMarkerCount = detectedMarkerCount
        self.blurScore = blurScore
        self.rejections = rejections
    }

    enum CodingKeys: String, CodingKey {
        case detectedMarkerCount = "detected_marker_count"
        case blurScore = "blur_score"
        case rejections
    }
}

public struct SampleOverlayRegion: Codable, Equatable, Identifiable {
    public var id: String { patchID }
    public var patchID: String
    public var corners: [Point]

    public init(patchID: String, corners: [Point]) {
        self.patchID = patchID
        self.corners = corners
    }
}

public struct SheetAnalysis: Codable, Equatable {
    public var measurements: [PatchMeasurement]
    public var normalizedMeasurements: [PatchMeasurement]
    public var scores: [PairScore]
    public var detectedMarkers: [DetectedMarker]
    public var sampleRegions: [SampleOverlayRegion]
    public var quality: CaptureQuality

    public init(measurements: [PatchMeasurement], normalizedMeasurements: [PatchMeasurement], scores: [PairScore], detectedMarkers: [DetectedMarker], sampleRegions: [SampleOverlayRegion], quality: CaptureQuality) {
        self.measurements = measurements
        self.normalizedMeasurements = normalizedMeasurements
        self.scores = scores
        self.detectedMarkers = detectedMarkers
        self.sampleRegions = sampleRegions
        self.quality = quality
    }
}
