import Foundation

public struct LinearImage {
    public var width: Int
    public var height: Int
    public var pixels: [RGB]

    public init(width: Int, height: Int, pixels: [RGB]) {
        precondition(pixels.count == width * height)
        self.width = width
        self.height = height
        self.pixels = pixels
    }

    public subscript(x: Int, y: Int) -> RGB {
        pixels[y * width + x]
    }
}

public enum Sampler {
    public static func srgbToLinear(_ value: Double) -> Double {
        if value <= 0.04045 {
            return value / 12.92
        }
        return pow((value + 0.055) / 1.055, 2.4)
    }

    public static func sample(image: LinearImage, rect: Rect, patchID: String) -> PatchMeasurement {
        let minX = max(0, Int(rect.x.rounded(.up)))
        let maxX = min(image.width - 1, Int((rect.x + rect.width).rounded(.down)))
        let minY = max(0, Int(rect.y.rounded(.up)))
        let maxY = min(image.height - 1, Int((rect.y + rect.height).rounded(.down)))
        var samples: [RGB] = []

        if minX <= maxX && minY <= maxY {
            for y in minY...maxY {
                for x in minX...maxX {
                    samples.append(image[x, y])
                }
            }
        }

        let stats = stats(samples)
        return PatchMeasurement(patchID: patchID, linearRGBMedian: stats.median, stats: stats)
    }

    public static func sample(image: LinearImage, polygon: [Point], patchID: String) -> PatchMeasurement {
        guard let bounds = Rect.bounding(polygon) else {
            let stats = stats([])
            return PatchMeasurement(patchID: patchID, linearRGBMedian: stats.median, stats: stats)
        }

        let minX = max(0, Int(bounds.x.rounded(.up)))
        let maxX = min(image.width - 1, Int((bounds.x + bounds.width).rounded(.down)))
        let minY = max(0, Int(bounds.y.rounded(.up)))
        let maxY = min(image.height - 1, Int((bounds.y + bounds.height).rounded(.down)))
        var samples: [RGB] = []

        if minX <= maxX && minY <= maxY {
            for y in minY...maxY {
                for x in minX...maxX where contains(Point(x: Double(x) + 0.5, y: Double(y) + 0.5), in: polygon) {
                    samples.append(image[x, y])
                }
            }
        }

        let stats = stats(samples)
        return PatchMeasurement(patchID: patchID, linearRGBMedian: stats.median, stats: stats)
    }

    private static func stats(_ samples: [RGB]) -> ChannelStats {
        let count = max(samples.count, 1)
        let r = samples.map(\.r).sorted()
        let g = samples.map(\.g).sorted()
        let b = samples.map(\.b).sorted()
        let mean = RGB(r: samples.map(\.r).reduce(0, +) / Double(count),
                       g: samples.map(\.g).reduce(0, +) / Double(count),
                       b: samples.map(\.b).reduce(0, +) / Double(count))
        let median = RGB(r: percentile(r, 0.5), g: percentile(g, 0.5), b: percentile(b, 0.5))
        let min = RGB(r: r.first ?? 0, g: g.first ?? 0, b: b.first ?? 0)
        let max = RGB(r: r.last ?? 0, g: g.last ?? 0, b: b.last ?? 0)
        let clipping = Double(samples.filter { $0.r >= 0.995 || $0.g >= 0.995 || $0.b >= 0.995 || $0.r <= 0.005 || $0.g <= 0.005 || $0.b <= 0.005 }.count) / Double(count)

        return ChannelStats(
            median: median,
            mean: mean,
            standardDeviation: RGB(
                r: standardDeviation(samples.map(\.r), mean: mean.r),
                g: standardDeviation(samples.map(\.g), mean: mean.g),
                b: standardDeviation(samples.map(\.b), mean: mean.b)
            ),
            min: min,
            max: max,
            sampleCount: samples.count,
            clippingFraction: clipping
        )
    }

    private static func percentile(_ sorted: [Double], _ p: Double) -> Double {
        guard !sorted.isEmpty else { return 0 }
        let index = min(sorted.count - 1, max(0, Int((Double(sorted.count - 1) * p).rounded())))
        return sorted[index]
    }

    private static func standardDeviation(_ values: [Double], mean: Double) -> Double {
        guard !values.isEmpty else { return 0 }
        let variance = values.map { pow($0 - mean, 2) }.reduce(0, +) / Double(values.count)
        return sqrt(variance)
    }

    private static func contains(_ point: Point, in polygon: [Point]) -> Bool {
        guard polygon.count >= 3 else { return false }
        var isInside = false
        var previousIndex = polygon.count - 1

        for currentIndex in polygon.indices {
            let current = polygon[currentIndex]
            let previous = polygon[previousIndex]
            let crossesY = (current.y > point.y) != (previous.y > point.y)
            let intersectionX = (previous.x - current.x) * (point.y - current.y) / ((previous.y - current.y) + 1.0e-12) + current.x

            if crossesY && point.x < intersectionX {
                isInside.toggle()
            }
            previousIndex = currentIndex
        }

        return isInside
    }
}
