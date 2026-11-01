import Foundation
import MeasurementCore
import XCTest

/// Pins the real `color_matching` response shapes discovered while scoping #5
/// (see `docs/color-matching-api-contract-deltas.md`), using local fixtures
/// since no live server is available in CI. These decode into test-local
/// types today because the generated client doesn't exist yet; once it does,
/// a future pass should decode these same fixtures through the generated
/// types instead and delete the test-local duplicates below.
final class RealServerContractFixtureTests: XCTestCase {
    func testSheetManifestDecodesExistingFieldsFromTheRealShape() throws {
        let manifest = try JSONDecoder().decode(SheetManifest.self, from: Self.realManifestFixtureJSON)

        XCTAssertEqual(manifest.schemaVersion, "lps-sheet-manifest/v1")
        XCTAssertEqual(manifest.sheetVersion, "lps-letter-grid-v1")
        XCTAssertEqual(manifest.sheetID, "sheet_123")
        XCTAssertEqual(manifest.manifestURL, URL(string: "https://example.test/api/v1/test_sheets/sheet_123/manifest"))
        XCTAssertEqual(manifest.patches.count, 2)
        XCTAssertEqual(manifest.pairs.count, 1)
    }

    /// The real manifest response includes `printer_profile` and
    /// `capture_profile` (see deltas #1-#2); `SheetManifest` has no fields for
    /// either, so this data is silently dropped on decode today. This is
    /// expected to fail until `SheetManifest` (or its generated replacement)
    /// decodes both fields — that failure is the signal to delete this test.
    func testSheetManifestModelDoesNotYetExposePrinterOrCaptureProfile() throws {
        let manifest = try JSONDecoder().decode(SheetManifest.self, from: Self.realManifestFixtureJSON)
        let propertyLabels = Set(Mirror(reflecting: manifest).children.compactMap { $0.label })

        XCTAssertTrue(propertyLabels.contains("printerProfile"), "SheetManifest should decode the server's printer_profile (see contract delta #1)")
        XCTAssertTrue(propertyLabels.contains("captureProfile"), "SheetManifest should decode the server's capture_profile (see contract delta #2)")
    }

    func testPrinterProfileFixtureMatchesTheRealRenderedShape() throws {
        let profile = try JSONDecoder().decode(PrinterProfileFixture.self, from: Self.realPrinterProfileFixtureJSON)

        XCTAssertEqual(profile.printerMakeModel, "Epson Workforce Pro WF-7840")
        XCTAssertEqual(profile.paperType, "Matte photo paper")
        XCTAssertEqual(profile.inkType, "Pigment")
        XCTAssertEqual(profile.iccProfile, "sRGB IEC61966-2.1")
        XCTAssertEqual(profile.printSettings, ["quality": "photo"])
        XCTAssertEqual(profile.calibrationDate, "2026-05-01")
    }

    func testMeasurementUploadResponseFixtureMatchesTheRealShape() throws {
        let json = Data(#"{"capture_id": "42", "measurement_count": 2, "pair_score_count": 1}"#.utf8)
        let response = try JSONDecoder().decode(MeasurementUploadResponseFixture.self, from: json)

        XCTAssertEqual(response.captureID, "42")
        XCTAssertEqual(response.measurementCount, 2)
        XCTAssertEqual(response.pairScoreCount, 1)
    }

    func testJudgmentUploadResponseFixtureMatchesTheRealShape() throws {
        let json = Data(#"{"capture_id": "42", "judgment_count": 1}"#.utf8)
        let response = try JSONDecoder().decode(JudgmentUploadResponseFixture.self, from: json)

        XCTAssertEqual(response.captureID, "42")
        XCTAssertEqual(response.judgmentCount, 1)
    }

    func testRankedResultsFixtureMatchesTheRealShape() throws {
        let results = try JSONDecoder().decode(RankedResultsFixture.self, from: Self.realRankedResultsFixtureJSON)

        XCTAssertEqual(results.schemaVersion, "lps-ranked-results/v1")
        XCTAssertEqual(results.sheetID, "sheet_123")
        XCTAssertEqual(results.captureCount, 3)
        XCTAssertEqual(results.scoringAlgorithmVersions, ["lps-distance-v1"])
        XCTAssertEqual(results.results.count, 2)

        let judged = results.results[0]
        XCTAssertEqual(judged.rank, 1)
        XCTAssertEqual(judged.pairID, "pair_1")
        XCTAssertEqual(judged.sourceColors.colorAHex, "#FF0000")
        XCTAssertEqual(judged.score.average, 0.035)
        XCTAssertEqual(judged.currentJudgment, "near_match")
        XCTAssertEqual(judged.latestObservation?.judgment, "near_match")

        let unjudged = results.results[1]
        XCTAssertNil(unjudged.currentJudgment)
        XCTAssertNil(unjudged.latestObservation)
        XCTAssertEqual(unjudged.observationCount, 0)
    }

    func testErrorResponseFixtureDecodesTheDetailObjectVariant() throws {
        let json = Data(#"{"errors": {"detail": "Sheet not found"}}"#.utf8)
        let response = try JSONDecoder().decode(ErrorResponseFixture.self, from: json)

        guard case .detail(let detail) = response.errors else {
            return XCTFail("expected the object variant of errors")
        }
        XCTAssertEqual(detail, "Sheet not found")
    }

    func testErrorResponseFixtureDecodesTheValidationArrayVariant() throws {
        let json = Data(#"{"errors": [{"detail": "can't be blank", "source": {"pointer": "/data/attributes/pair_id"}}]}"#.utf8)
        let response = try JSONDecoder().decode(ErrorResponseFixture.self, from: json)

        guard case .issues(let issues) = response.errors else {
            return XCTFail("expected the array variant of errors")
        }
        XCTAssertEqual(issues.first?.detail, "can't be blank")
        XCTAssertEqual(issues.first?.source.pointer, "/data/attributes/pair_id")
    }

    private static let realPrinterProfileFixtureJSON = Data("""
    {
      "printer_make_model": "Epson Workforce Pro WF-7840",
      "paper_type": "Matte photo paper",
      "ink_type": "Pigment",
      "icc_profile": "sRGB IEC61966-2.1",
      "print_settings": {"quality": "photo"},
      "driver_name": "Epson Printer Driver",
      "driver_version": "9.3.1",
      "calibration_date": "2026-05-01",
      "calibration_version": "cal-v2",
      "notes": "Calibrated under D50 booth lighting"
    }
    """.utf8)

    private static let realManifestFixtureJSON = Data("""
    {
      "schema_version": "lps-sheet-manifest/v1",
      "sheet_id": "sheet_123",
      "sheet_version": "lps-letter-grid-v1",
      "manifest_url": "https://example.test/api/v1/test_sheets/sheet_123/manifest",
      "created_at": "2026-07-25T12:00:00Z",
      "page": {"units": "mm", "width": 215.9, "height": 279.4},
      "registration_markers": [
        {"role": "top_left", "shape": "solid_square", "rect": {"x": 12, "y": 12, "width": 8, "height": 8}}
      ],
      "printer_profile": {
        "printer_make_model": "Epson Workforce Pro WF-7840",
        "paper_type": "Matte photo paper",
        "ink_type": "Pigment",
        "icc_profile": "sRGB IEC61966-2.1",
        "print_settings": {"quality": "photo"},
        "driver_name": "Epson Printer Driver",
        "driver_version": "9.3.1",
        "calibration_date": "2026-05-01",
        "calibration_version": "cal-v2",
        "notes": "Calibrated under D50 booth lighting"
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
        },
        {
          "id": "pair_1#second",
          "role": "pair_color",
          "pair_id": "pair_1",
          "pair_side": "second",
          "reference_role": null,
          "source_color": "#00FF00",
          "safe_inset_mm": 1.5,
          "rect": {"x": 36, "y": 38, "width": 16, "height": 10}
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
    """.utf8)

    private static let realRankedResultsFixtureJSON = Data("""
    {
      "schema_version": "lps-ranked-results/v1",
      "sheet_id": "sheet_123",
      "printer_profile": {
        "printer_make_model": "Epson Workforce Pro WF-7840",
        "paper_type": "Matte photo paper",
        "ink_type": "Pigment",
        "icc_profile": "sRGB IEC61966-2.1",
        "print_settings": {"quality": "photo"},
        "driver_name": "Epson Printer Driver",
        "driver_version": "9.3.1",
        "calibration_date": "2026-05-01",
        "calibration_version": "cal-v2",
        "notes": "Calibrated under D50 booth lighting"
      },
      "capture_count": 3,
      "latest_capture_at": "2026-07-25T12:00:00Z",
      "earliest_capture_at": "2026-07-20T09:00:00Z",
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
            "average": 0.035,
            "latest": 0.03,
            "minimum": 0.02,
            "maximum": 0.05,
            "capture_count": 3,
            "sample_count": 3,
            "algorithm_versions": ["lps-distance-v1"]
          },
          "current_judgment": "near_match",
          "current_judgment_observed_at": "2026-07-25T12:05:00Z",
          "observation_count": 1,
          "latest_observation": {"judgment": "near_match", "observed_at": "2026-07-25T12:05:00Z"},
          "capture_count": 3,
          "latest_capture_at": "2026-07-25T12:00:00Z",
          "earliest_capture_at": "2026-07-20T09:00:00Z"
        },
        {
          "rank": 2,
          "pair_id": "pair_2",
          "scoring_algorithm_version": "lps-distance-v1",
          "row": 0,
          "col": 2,
          "source_colors": {"color_a_hex": "#0000FF", "color_b_hex": "#000080"},
          "score": {
            "average": 0.1,
            "latest": 0.1,
            "minimum": 0.1,
            "maximum": 0.1,
            "capture_count": 1,
            "sample_count": 1,
            "algorithm_versions": ["lps-distance-v1"]
          },
          "current_judgment": null,
          "current_judgment_observed_at": null,
          "observation_count": 0,
          "latest_observation": null,
          "capture_count": 1,
          "latest_capture_at": "2026-07-20T09:00:00Z",
          "earliest_capture_at": "2026-07-20T09:00:00Z"
        }
      ]
    }
    """.utf8)
}

private struct PrinterProfileFixture: Decodable, Equatable {
    var printerMakeModel: String
    var paperType: String
    var inkType: String
    var iccProfile: String?
    var printSettings: [String: String]?
    var driverName: String?
    var driverVersion: String?
    var calibrationDate: String?
    var calibrationVersion: String?
    var notes: String?

    enum CodingKeys: String, CodingKey {
        case printerMakeModel = "printer_make_model"
        case paperType = "paper_type"
        case inkType = "ink_type"
        case iccProfile = "icc_profile"
        case printSettings = "print_settings"
        case driverName = "driver_name"
        case driverVersion = "driver_version"
        case calibrationDate = "calibration_date"
        case calibrationVersion = "calibration_version"
        case notes
    }
}

private struct MeasurementUploadResponseFixture: Decodable, Equatable {
    var captureID: String
    var measurementCount: Int
    var pairScoreCount: Int

    enum CodingKeys: String, CodingKey {
        case captureID = "capture_id"
        case measurementCount = "measurement_count"
        case pairScoreCount = "pair_score_count"
    }
}

private struct JudgmentUploadResponseFixture: Decodable, Equatable {
    var captureID: String
    var judgmentCount: Int

    enum CodingKeys: String, CodingKey {
        case captureID = "capture_id"
        case judgmentCount = "judgment_count"
    }
}

private struct SourceColorsFixture: Decodable, Equatable {
    var colorAHex: String
    var colorBHex: String

    enum CodingKeys: String, CodingKey {
        case colorAHex = "color_a_hex"
        case colorBHex = "color_b_hex"
    }
}

private struct ScoreFixture: Decodable, Equatable {
    var average: Double?
    var latest: Double?
    var minimum: Double?
    var maximum: Double?
    var captureCount: Int
    var sampleCount: Int
    var algorithmVersions: [String]

    enum CodingKeys: String, CodingKey {
        case average, latest, minimum, maximum
        case captureCount = "capture_count"
        case sampleCount = "sample_count"
        case algorithmVersions = "algorithm_versions"
    }
}

private struct LatestObservationFixture: Decodable, Equatable {
    var judgment: String
    var observedAt: String

    enum CodingKeys: String, CodingKey {
        case judgment
        case observedAt = "observed_at"
    }
}

private struct RankedResultFixture: Decodable, Equatable {
    var rank: Int
    var pairID: String
    var scoringAlgorithmVersion: String?
    var row: Int?
    var col: Int?
    var sourceColors: SourceColorsFixture
    var score: ScoreFixture
    var currentJudgment: String?
    var currentJudgmentObservedAt: String?
    var observationCount: Int
    var latestObservation: LatestObservationFixture?
    var captureCount: Int
    var latestCaptureAt: String?
    var earliestCaptureAt: String?

    enum CodingKeys: String, CodingKey {
        case rank
        case pairID = "pair_id"
        case scoringAlgorithmVersion = "scoring_algorithm_version"
        case row, col
        case sourceColors = "source_colors"
        case score
        case currentJudgment = "current_judgment"
        case currentJudgmentObservedAt = "current_judgment_observed_at"
        case observationCount = "observation_count"
        case latestObservation = "latest_observation"
        case captureCount = "capture_count"
        case latestCaptureAt = "latest_capture_at"
        case earliestCaptureAt = "earliest_capture_at"
    }
}

private struct RankedResultsFixture: Decodable, Equatable {
    var schemaVersion: String
    var sheetID: String
    var printerProfile: PrinterProfileFixture
    var captureCount: Int
    var latestCaptureAt: String?
    var earliestCaptureAt: String?
    var scoringAlgorithmVersions: [String]
    var results: [RankedResultFixture]

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case sheetID = "sheet_id"
        case printerProfile = "printer_profile"
        case captureCount = "capture_count"
        case latestCaptureAt = "latest_capture_at"
        case earliestCaptureAt = "earliest_capture_at"
        case scoringAlgorithmVersions = "scoring_algorithm_versions"
        case results
    }
}

/// Mirrors the real `ErrorResponse` schema's `errors` field, which is
/// `oneOf` a generic object (e.g. `{"detail": "..."}`) or an array of
/// `{detail, source: {pointer}}` validation issues (see contract delta #8).
private enum ErrorsPayloadFixture: Decodable, Equatable {
    case detail(String)
    case issues([IssueFixture])

    struct IssueFixture: Decodable, Equatable {
        var detail: String
        var source: SourceFixture

        struct SourceFixture: Decodable, Equatable {
            var pointer: String
        }
    }

    private struct DetailObjectFixture: Decodable {
        var detail: String
    }

    init(from decoder: Decoder) throws {
        if let issues = try? [IssueFixture](from: decoder) {
            self = .issues(issues)
            return
        }
        self = .detail(try DetailObjectFixture(from: decoder).detail)
    }
}

private struct ErrorResponseFixture: Decodable, Equatable {
    var errors: ErrorsPayloadFixture
}
