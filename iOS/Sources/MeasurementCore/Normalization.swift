import Foundation

public enum Normalizer {
    public static func normalize(_ measurements: [PatchMeasurement], patches: [Patch]) -> [PatchMeasurement] {
        let byID = Dictionary(uniqueKeysWithValues: patches.map { ($0.id, $0) })
        let refs = measurements.filter { byID[$0.patchID]?.role == "reference" }
        let black = average(refs, patches: byID, referenceRole: "black") ?? RGB(r: 0, g: 0, b: 0)
        let white = average(refs, patches: byID, referenceRole: "white") ?? RGB(r: 1, g: 1, b: 1)

        return measurements.map { measurement in
            var copy = measurement
            copy.normalizedLinearRGBMedian = normalize(measurement.linearRGBMedian, black: black, white: white)
            return copy
        }
    }

    private static func normalize(_ rgb: RGB, black: RGB, white: RGB) -> RGB {
        RGB(
            r: scale(rgb.r, black: black.r, white: white.r),
            g: scale(rgb.g, black: black.g, white: white.g),
            b: scale(rgb.b, black: black.b, white: white.b)
        )
    }

    private static func scale(_ value: Double, black: Double, white: Double) -> Double {
        let denominator = max(white - black, 1.0e-6)
        return min(1, max(0, (value - black) / denominator))
    }

    private static func average(_ measurements: [PatchMeasurement], patches: [String: Patch], referenceRole: String) -> RGB? {
        let selected = measurements.filter { patches[$0.patchID]?.referenceRole == referenceRole }
        guard !selected.isEmpty else { return nil }
        return RGB(
            r: selected.map(\.linearRGBMedian.r).reduce(0, +) / Double(selected.count),
            g: selected.map(\.linearRGBMedian.g).reduce(0, +) / Double(selected.count),
            b: selected.map(\.linearRGBMedian.b).reduce(0, +) / Double(selected.count)
        )
    }
}
