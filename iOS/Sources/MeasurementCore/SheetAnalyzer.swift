import Foundation

public enum SheetAnalyzer {
    public static func analyze(image: LinearImage, manifest: SheetManifest) -> SheetAnalysis {
        let markers = MarkerDetector.detectMarkers(in: image)
        guard markers.count >= manifest.registrationMarkers.count,
              let homography = homography(for: manifest, detectedMarkers: markers) else {
            let blurScore = BlurEstimator.score(image: image)
            let quality = CaptureQuality(
                detectedMarkerCount: markers.count,
                blurScore: blurScore,
                rejections: QualityGate.rejections(
                    measurements: [],
                    expectedMarkerCount: manifest.registrationMarkers.count,
                    detectedMarkerCount: markers.count,
                    blurScore: blurScore
                )
            )
            return SheetAnalysis(
                measurements: [],
                normalizedMeasurements: [],
                scores: [],
                detectedMarkers: markers,
                sampleRegions: [],
                quality: quality
            )
        }

        var regions: [SampleOverlayRegion] = []
        let measurements = manifest.patches.map { patch in
            let sampleRect = patch.rect.inset(by: patch.safeInsetMM)
            let corners = homography.map(sampleRect)
            regions.append(SampleOverlayRegion(patchID: patch.id, corners: corners))
            return Sampler.sample(image: image, polygon: corners, patchID: patch.id)
        }

        let normalized = Normalizer.normalize(measurements, patches: manifest.patches)
        let scores = LPSScorer.score(pairs: manifest.pairs, measurements: normalized)
        let blurScore = BlurEstimator.score(image: image)
        let rejections = QualityGate.rejections(
            measurements: normalized,
            patches: manifest.patches,
            sampleRegions: regions,
            image: image,
            expectedMarkerCount: manifest.registrationMarkers.count,
            detectedMarkerCount: markers.count,
            blurScore: blurScore
        )

        return SheetAnalysis(
            measurements: measurements,
            normalizedMeasurements: normalized,
            scores: scores,
            detectedMarkers: markers,
            sampleRegions: regions,
            quality: CaptureQuality(detectedMarkerCount: markers.count, blurScore: blurScore, rejections: rejections)
        )
    }

    private static func homography(for manifest: SheetManifest, detectedMarkers: [DetectedMarker]) -> Homography? {
        let expectedByRole = Dictionary(uniqueKeysWithValues: manifest.registrationMarkers.map { ($0.role, center(of: $0.rect)) })
        let detectedByRole = Dictionary(uniqueKeysWithValues: detectedMarkers.map { ($0.role, $0.center) })

        let pagePoints = MarkerRoles.ordered.compactMap { expectedByRole[$0] }
        let imagePoints = MarkerRoles.ordered.compactMap { detectedByRole[$0] }
        guard pagePoints.count == 4, imagePoints.count == 4 else { return nil }

        return Homography(page: pagePoints, image: imagePoints)
    }

    private static func center(of rect: Rect) -> Point {
        Point(x: rect.x + rect.width / 2, y: rect.y + rect.height / 2)
    }

}

private enum MarkerRoles {
    static let ordered = ["top_left", "top_right", "bottom_right", "bottom_left"]
}

enum MarkerDetector {
    static func detectMarkers(in image: LinearImage) -> [DetectedMarker] {
        var visited = Array(repeating: false, count: image.width * image.height)
        var components: [(center: Point, bounds: Rect, area: Int)] = []

        for y in 0..<image.height {
            for x in 0..<image.width {
                let index = y * image.width + x
                guard !visited[index], isMarkerPixel(image[x, y]) else { continue }
                let component = floodFill(fromX: x, y: y, image: image, visited: &visited)
                if component.area >= max(16, (image.width * image.height) / 8_000) {
                    components.append(component)
                }
            }
        }

        return MarkerRoles.ordered
            .compactMap { role in
                components
                    .min { distance($0.center, toCorner: role, image: image) < distance($1.center, toCorner: role, image: image) }
                    .map { DetectedMarker(role: role, center: $0.center, bounds: $0.bounds) }
            }
            .filter { marker in
                isNearCorner(marker.center, role: marker.role, image: image)
            }
    }

    private static func distance(_ point: Point, toCorner role: String, image: LinearImage) -> Double {
        let corner: Point
        switch role {
        case "top_left":
            corner = Point(x: 0, y: 0)
        case "top_right":
            corner = Point(x: Double(image.width - 1), y: 0)
        case "bottom_right":
            corner = Point(x: Double(image.width - 1), y: Double(image.height - 1))
        case "bottom_left":
            corner = Point(x: 0, y: Double(image.height - 1))
        default:
            corner = point
        }
        return pow(point.x - corner.x, 2) + pow(point.y - corner.y, 2)
    }

    private static func isNearCorner(_ point: Point, role: String, image: LinearImage) -> Bool {
        let xThreshold = Double(image.width) * 0.4
        let yThreshold = Double(image.height) * 0.4

        switch role {
        case "top_left":
            return point.x < xThreshold && point.y < yThreshold
        case "top_right":
            return point.x > Double(image.width) - xThreshold && point.y < yThreshold
        case "bottom_right":
            return point.x > Double(image.width) - xThreshold && point.y > Double(image.height) - yThreshold
        case "bottom_left":
            return point.x < xThreshold && point.y > Double(image.height) - yThreshold
        default:
            return false
        }
    }

    private static func floodFill(fromX startX: Int, y startY: Int, image: LinearImage, visited: inout [Bool]) -> (center: Point, bounds: Rect, area: Int) {
        var stack = [(startX, startY)]
        var area = 0
        var sumX = 0
        var sumY = 0
        var minX = startX
        var maxX = startX
        var minY = startY
        var maxY = startY

        while let (x, y) = stack.popLast() {
            guard x >= 0, y >= 0, x < image.width, y < image.height else { continue }
            let index = y * image.width + x
            guard !visited[index] else { continue }
            visited[index] = true
            guard isMarkerPixel(image[x, y]) else { continue }

            area += 1
            sumX += x
            sumY += y
            minX = min(minX, x)
            maxX = max(maxX, x)
            minY = min(minY, y)
            maxY = max(maxY, y)

            stack.append((x + 1, y))
            stack.append((x - 1, y))
            stack.append((x, y + 1))
            stack.append((x, y - 1))
        }

        let count = max(area, 1)
        return (
            center: Point(x: Double(sumX) / Double(count), y: Double(sumY) / Double(count)),
            bounds: Rect(x: Double(minX), y: Double(minY), width: Double(maxX - minX + 1), height: Double(maxY - minY + 1)),
            area: area
        )
    }

    private static func isMarkerPixel(_ rgb: RGB) -> Bool {
        (rgb.r + rgb.g + rgb.b) / 3 < 0.12
    }

}

enum BlurEstimator {
    static func score(image: LinearImage) -> Double {
        guard image.width > 2, image.height > 2 else { return 0 }
        var total = 0.0
        var count = 0

        for y in 1..<(image.height - 1) {
            for x in 1..<(image.width - 1) {
                let center = luminance(image[x, y]) * 4
                let laplacian = abs(center - luminance(image[x - 1, y]) - luminance(image[x + 1, y]) - luminance(image[x, y - 1]) - luminance(image[x, y + 1]))
                total += laplacian
                count += 1
            }
        }

        return min(1, total / Double(max(count, 1)) * 12)
    }

    private static func luminance(_ rgb: RGB) -> Double {
        0.2126 * rgb.r + 0.7152 * rgb.g + 0.0722 * rgb.b
    }
}
