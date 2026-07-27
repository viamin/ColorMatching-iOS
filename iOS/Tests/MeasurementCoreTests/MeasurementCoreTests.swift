import XCTest
@testable import MeasurementCore

final class MeasurementCoreTests: XCTestCase {
    func testHomographyMapsPageRectIntoImageCoordinates() {
        let h = Homography(
            page: [
                Point(x: 0, y: 0),
                Point(x: 100, y: 0),
                Point(x: 100, y: 100),
                Point(x: 0, y: 100)
            ],
            image: [
                Point(x: 10, y: 20),
                Point(x: 210, y: 20),
                Point(x: 210, y: 220),
                Point(x: 10, y: 220)
            ]
        )

        let center = h.map(Point(x: 50, y: 50))

        XCTAssertEqual(center.x, 110, accuracy: 0.0001)
        XCTAssertEqual(center.y, 120, accuracy: 0.0001)
    }

    func testSamplesSyntheticPatchAndComputesMedianLinearRGB() {
        let pixels = Array(repeating: RGB(r: 0.1, g: 0.2, b: 0.3), count: 100)
        let image = LinearImage(width: 10, height: 10, pixels: pixels)

        let measurement = Sampler.sample(
            image: image,
            rect: Rect(x: 2, y: 2, width: 4, height: 4),
            patchID: "patch-1"
        )

        XCTAssertEqual(measurement.patchID, "patch-1")
        XCTAssertEqual(measurement.linearRGBMedian, RGB(r: 0.1, g: 0.2, b: 0.3))
        XCTAssertEqual(measurement.stats.sampleCount, 25)
    }

    func testSamplesOnlyPixelsInsideProjectedPolygon() {
        let target = RGB(r: 0.2, g: 0.4, b: 0.6)
        let background = RGB(r: 0.9, g: 0.1, b: 0.1)
        var pixels = Array(repeating: background, count: 12 * 12)

        for y in 3...8 {
            for x in 3...8 where x >= y - 1 && x <= y + 3 {
                pixels[y * 12 + x] = target
            }
        }

        let image = LinearImage(width: 12, height: 12, pixels: pixels)
        let polygon = [
            Point(x: 4, y: 3),
            Point(x: 7, y: 4),
            Point(x: 8, y: 8),
            Point(x: 3, y: 7)
        ]

        let measurement = Sampler.sample(image: image, polygon: polygon, patchID: "skewed")

        XCTAssertEqual(measurement.linearRGBMedian, target)
        XCTAssertLessThan(measurement.stats.sampleCount, Sampler.sample(image: image, rect: Rect(x: 3, y: 3, width: 5, height: 5), patchID: "bbox").stats.sampleCount)
    }

    func testNormalizerUsesBlackAndWhiteReferencePatches() {
        let patches = [
            Patch(id: "black", role: "reference", pairID: nil, pairSide: nil, referenceRole: "black", sourceColor: "#000000", safeInsetMM: 1, rect: Rect(x: 0, y: 0, width: 1, height: 1)),
            Patch(id: "white", role: "reference", pairID: nil, pairSide: nil, referenceRole: "white", sourceColor: "#FFFFFF", safeInsetMM: 1, rect: Rect(x: 0, y: 0, width: 1, height: 1)),
            Patch(id: "sample", role: "pair_color", pairID: "pair", pairSide: "first", referenceRole: nil, sourceColor: "#808080", safeInsetMM: 1, rect: Rect(x: 0, y: 0, width: 1, height: 1))
        ]

        let measurements = [
            measurement("black", RGB(r: 0.1, g: 0.1, b: 0.1)),
            measurement("white", RGB(r: 0.9, g: 0.9, b: 0.9)),
            measurement("sample", RGB(r: 0.5, g: 0.3, b: 0.1))
        ]

        let normalized = Normalizer.normalize(measurements, patches: patches)
        let sample = normalized.first { $0.patchID == "sample" }!

        XCTAssertEqual(sample.normalizedLinearRGBMedian!.r, 0.5, accuracy: 0.0001)
        XCTAssertEqual(sample.normalizedLinearRGBMedian!.g, 0.25, accuracy: 0.0001)
        XCTAssertEqual(sample.normalizedLinearRGBMedian!.b, 0.0, accuracy: 0.0001)
    }

    func testQualityGateRejectsMissingMarkersBlurAndClipping() {
        let clipped = measurement("patch", RGB(r: 1, g: 0.2, b: 0.2), clipping: 0.05)

        let rejections = QualityGate.rejections(
            measurements: [clipped],
            expectedMarkerCount: 4,
            detectedMarkerCount: 3,
            blurScore: 0.1
        )

        XCTAssertTrue(rejections.contains(.missingRegistrationMarks))
        XCTAssertTrue(rejections.contains(.excessiveBlur))
        XCTAssertTrue(rejections.contains(.clipping))
    }

    func testQualityGateRejectsCoverageGlareAndPoorReferences() {
        let noisy = PatchMeasurement(
            patchID: "white",
            linearRGBMedian: RGB(r: 0.8, g: 0.8, b: 0.8),
            stats: ChannelStats(
                median: RGB(r: 0.8, g: 0.8, b: 0.8),
                mean: RGB(r: 0.8, g: 0.8, b: 0.8),
                standardDeviation: RGB(r: 0.2, g: 0.2, b: 0.2),
                min: RGB(r: 0.1, g: 0.1, b: 0.1),
                max: RGB(r: 1, g: 1, b: 1),
                sampleCount: 0,
                clippingFraction: 0
            )
        )

        let rejections = QualityGate.rejections(
            measurements: [noisy],
            patches: [Patch(id: "white", role: "reference", pairID: nil, pairSide: nil, referenceRole: "white", sourceColor: "#FFFFFF", safeInsetMM: 1, rect: Rect(x: 0, y: 0, width: 1, height: 1))],
            sampleRegions: [SampleOverlayRegion(patchID: "white", corners: [Point(x: -1, y: 0), Point(x: 1, y: 0), Point(x: 1, y: 1), Point(x: -1, y: 1)])],
            image: LinearImage(width: 10, height: 10, pixels: Array(repeating: RGB(r: 0.5, g: 0.5, b: 0.5), count: 100)),
            expectedMarkerCount: 4,
            detectedMarkerCount: 4,
            blurScore: 0.5
        )

        XCTAssertTrue(rejections.contains(.incompleteSheetCoverage))
        XCTAssertTrue(rejections.contains(.glare))
        XCTAssertTrue(rejections.contains(.poorReferencePatch))
    }

    func testLPSScorerRanksNearestPairFirst() {
        let pairs = [
            PairManifest(id: "near", gridRow: 0, gridCol: 0, firstPatchID: "a", secondPatchID: "b", sourceColors: ["#111111", "#121212"]),
            PairManifest(id: "far", gridRow: 0, gridCol: 1, firstPatchID: "a", secondPatchID: "c", sourceColors: ["#111111", "#EEEEEE"])
        ]

        let scores = LPSScorer.score(
            pairs: pairs,
            measurements: [
                measurement("a", RGB(r: 0.2, g: 0.2, b: 0.2)),
                measurement("b", RGB(r: 0.21, g: 0.2, b: 0.2)),
                measurement("c", RGB(r: 0.8, g: 0.8, b: 0.8))
            ]
        )

        XCTAssertEqual(scores.first?.pairID, "near")
        XCTAssertEqual(scores.first?.algorithmVersion, "lps-distance-v1")
    }

    func testSheetAnalyzerDetectsMarkersSamplesAndRanksSyntheticSheet() throws {
        let manifest = syntheticManifest()
        let image = syntheticSheetImage(manifest: manifest)

        let analysis = SheetAnalyzer.analyze(image: image, manifest: manifest)

        XCTAssertEqual(analysis.detectedMarkers.count, 4)
        XCTAssertTrue(analysis.quality.rejections.isEmpty)
        XCTAssertEqual(analysis.measurements.count, manifest.patches.count)
        XCTAssertEqual(analysis.sampleRegions.count, manifest.patches.count)
        XCTAssertEqual(analysis.scores.first?.pairID, "near")
    }

    func testSheetAnalyzerRejectsMissingRegistrationMarkers() {
        let manifest = syntheticManifest()
        let image = LinearImage(width: 120, height: 120, pixels: Array(repeating: RGB(r: 0.8, g: 0.8, b: 0.8), count: 120 * 120))

        let analysis = SheetAnalyzer.analyze(image: image, manifest: manifest)

        XCTAssertEqual(analysis.detectedMarkers.count, 0)
        XCTAssertTrue(analysis.quality.rejections.contains(.missingRegistrationMarks))
        XCTAssertTrue(analysis.measurements.isEmpty)
        XCTAssertTrue(analysis.scores.isEmpty)
    }

    private func measurement(_ patchID: String, _ rgb: RGB, clipping: Double = 0) -> PatchMeasurement {
        PatchMeasurement(
            patchID: patchID,
            linearRGBMedian: rgb,
            stats: ChannelStats(
                median: rgb,
                mean: rgb,
                standardDeviation: RGB(r: 0.01, g: 0.01, b: 0.01),
                min: rgb,
                max: rgb,
                sampleCount: 9,
                clippingFraction: clipping
            )
        )
    }

    private func syntheticManifest() -> SheetManifest {
        SheetManifest(
            schemaVersion: "lps-sheet-manifest/v1",
            sheetVersion: "lps-letter-grid-v1",
            sheetID: "sheet-test",
            manifestURL: URL(string: "https://example.test/api/v1/test_sheets/sheet-test/manifest")!,
            page: Page(units: "mm", width: 100, height: 100),
            registrationMarkers: [
                RegistrationMarker(role: "top_left", shape: "solid_square", rect: Rect(x: 5, y: 5, width: 10, height: 10)),
                RegistrationMarker(role: "top_right", shape: "solid_square", rect: Rect(x: 85, y: 5, width: 10, height: 10)),
                RegistrationMarker(role: "bottom_right", shape: "solid_square", rect: Rect(x: 85, y: 85, width: 10, height: 10)),
                RegistrationMarker(role: "bottom_left", shape: "solid_square", rect: Rect(x: 5, y: 85, width: 10, height: 10))
            ],
            patches: [
                Patch(id: "black", role: "reference", pairID: nil, pairSide: nil, referenceRole: "black", sourceColor: "#000000", safeInsetMM: 1, rect: Rect(x: 20, y: 20, width: 10, height: 10)),
                Patch(id: "white", role: "reference", pairID: nil, pairSide: nil, referenceRole: "white", sourceColor: "#FFFFFF", safeInsetMM: 1, rect: Rect(x: 35, y: 20, width: 10, height: 10)),
                Patch(id: "a", role: "pair_color", pairID: "near", pairSide: "first", referenceRole: nil, sourceColor: "#333333", safeInsetMM: 1, rect: Rect(x: 20, y: 40, width: 10, height: 10)),
                Patch(id: "b", role: "pair_color", pairID: "near", pairSide: "second", referenceRole: nil, sourceColor: "#343333", safeInsetMM: 1, rect: Rect(x: 35, y: 40, width: 10, height: 10)),
                Patch(id: "c", role: "pair_color", pairID: "far", pairSide: "second", referenceRole: nil, sourceColor: "#DDDDDD", safeInsetMM: 1, rect: Rect(x: 50, y: 40, width: 10, height: 10))
            ],
            pairs: [
                PairManifest(id: "far", gridRow: 0, gridCol: 0, firstPatchID: "a", secondPatchID: "c", sourceColors: ["#333333", "#DDDDDD"]),
                PairManifest(id: "near", gridRow: 0, gridCol: 1, firstPatchID: "a", secondPatchID: "b", sourceColors: ["#333333", "#343333"])
            ]
        )
    }

    private func syntheticSheetImage(manifest: SheetManifest) -> LinearImage {
        let width = 120
        let height = 120
        var pixels = Array(repeating: RGB(r: 0.8, g: 0.8, b: 0.8), count: width * height)

        func fill(_ rect: Rect, color: RGB) {
            let minX = max(0, Int(rect.x.rounded(.down)))
            let maxX = min(width - 1, Int((rect.x + rect.width).rounded(.up)))
            let minY = max(0, Int(rect.y.rounded(.down)))
            let maxY = min(height - 1, Int((rect.y + rect.height).rounded(.up)))
            for y in minY...maxY {
                for x in minX...maxX {
                    pixels[y * width + x] = color
                }
            }
        }

        for marker in manifest.registrationMarkers {
            fill(marker.rect, color: RGB(r: 0, g: 0, b: 0))
        }

        for patch in manifest.patches {
            let color: RGB
            switch patch.id {
            case "black": color = RGB(r: 0.05, g: 0.05, b: 0.05)
            case "white": color = RGB(r: 0.95, g: 0.95, b: 0.95)
            case "a": color = RGB(r: 0.25, g: 0.2, b: 0.18)
            case "b": color = RGB(r: 0.26, g: 0.2, b: 0.18)
            default: color = RGB(r: 0.75, g: 0.7, b: 0.65)
            }
            fill(patch.rect, color: color)
        }

        return LinearImage(width: width, height: height, pixels: pixels)
    }
}
