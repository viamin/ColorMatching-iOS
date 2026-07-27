import Foundation

public enum CaptureRejection: String, Codable, Equatable {
    case missingRegistrationMarks
    case incompleteSheetCoverage
    case clipping
    case excessiveBlur
    case glare
    case poorReferencePatch
}

public enum QualityGate {
    public static func rejections(measurements: [PatchMeasurement], expectedMarkerCount: Int, detectedMarkerCount: Int, blurScore: Double) -> [CaptureRejection] {
        var reasons = registrationRejections(
            expectedMarkerCount: expectedMarkerCount,
            detectedMarkerCount: detectedMarkerCount,
            blurScore: blurScore
        )
        appendMeasurementRejections(measurements: measurements, to: &reasons)
        return reasons
    }

    public static func rejections(measurements: [PatchMeasurement], patches: [Patch], sampleRegions: [SampleOverlayRegion], image: LinearImage?, expectedMarkerCount: Int, detectedMarkerCount: Int, blurScore: Double) -> [CaptureRejection] {
        var reasons = registrationRejections(
            expectedMarkerCount: expectedMarkerCount,
            detectedMarkerCount: detectedMarkerCount,
            blurScore: blurScore
        )
        appendMeasurementRejections(measurements: measurements, to: &reasons)
        if let image, sampleRegions.contains(where: { !contains($0.corners, in: image) }) {
            reasons.append(.incompleteSheetCoverage)
        }
        if hasPoorReferencePatch(measurements: measurements, patches: patches) {
            reasons.append(.poorReferencePatch)
        }
        return reasons
    }

    public static func registrationRejections(expectedMarkerCount: Int, detectedMarkerCount: Int, blurScore: Double) -> [CaptureRejection] {
        var reasons: [CaptureRejection] = []
        if detectedMarkerCount < expectedMarkerCount { reasons.append(.missingRegistrationMarks) }
        if blurScore < 0.18 { reasons.append(.excessiveBlur) }
        return reasons
    }

    private static func appendMeasurementRejections(measurements: [PatchMeasurement], to reasons: inout [CaptureRejection]) {
        if measurements.contains(where: { $0.stats.clippingFraction > 0.02 }) { reasons.append(.clipping) }
        if measurements.contains(where: { $0.stats.standardDeviation.r + $0.stats.standardDeviation.g + $0.stats.standardDeviation.b > 0.45 }) {
            reasons.append(.glare)
        }
    }

    private static func contains(_ points: [Point], in image: LinearImage) -> Bool {
        points.allSatisfy { point in
            point.x >= 0 && point.y >= 0 && point.x < Double(image.width) && point.y < Double(image.height)
        }
    }

    private static func hasPoorReferencePatch(measurements: [PatchMeasurement], patches: [Patch]) -> Bool {
        guard !patches.isEmpty else { return false }
        let byID = Dictionary(uniqueKeysWithValues: patches.map { ($0.id, $0) })
        let references = measurements.filter { byID[$0.patchID]?.role == "reference" }
        guard !references.isEmpty else { return true }

        return references.contains { measurement in
            let spread = measurement.stats.standardDeviation.r + measurement.stats.standardDeviation.g + measurement.stats.standardDeviation.b
            return measurement.stats.sampleCount == 0 || spread > 0.3
        }
    }
}

public enum LPSScorer {
    public static let algorithmVersion = "lps-distance-v1"

    public static func score(pairs: [PairManifest], measurements: [PatchMeasurement]) -> [PairScore] {
        let byPatch = Dictionary(uniqueKeysWithValues: measurements.map { ($0.patchID, $0) })

        return pairs.compactMap { pair in
            guard let first = byPatch[pair.firstPatchID],
                  let second = byPatch[pair.secondPatchID] else { return nil }

            let distance = self.distance(first.normalizedLinearRGBMedian ?? first.linearRGBMedian,
                                         second.normalizedLinearRGBMedian ?? second.linearRGBMedian)
            return PairScore(pairID: pair.id, distance: distance, similarity: max(0, 1 - distance), algorithmVersion: algorithmVersion)
        }
        .sorted { $0.distance < $1.distance }
    }

    private static func distance(_ a: RGB, _ b: RGB) -> Double {
        sqrt(0.34 * pow(a.r - b.r, 2) + 0.58 * pow(a.g - b.g, 2) + 0.08 * pow(a.b - b.b, 2))
    }
}
