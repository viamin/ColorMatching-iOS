import XCTest
import ColorMatchingAPI

final class GeneratedTypesCodingTests: XCTestCase {
    func testDecodesFullSheetManifestFromWirePayload() throws {
        let manifest = try JSONDecoder().decode(Types.Schemas.TestSheetManifest.self, from: OpenAPIFixtures.jsonData(OpenAPIFixtures.manifest))

        XCTAssertEqual(manifest.schema_version, "lps-sheet-manifest/v1")
        XCTAssertEqual(manifest.sheet_id, "sheet_1")
        XCTAssertEqual(manifest.page?.units, "mm")
        XCTAssertEqual(manifest.page?.width ?? 0, 215.9, accuracy: 0.0001)
        XCTAssertEqual(manifest.registration_markers?.first?.role, "top_left")
        XCTAssertEqual(manifest.printer_profile?.printer_make_model, "Research printer")
        XCTAssertEqual(manifest.printer_profile?.paper_type, "Plain A4")
        XCTAssertEqual(manifest.capture_profile?.scoring_algorithm_version, "lps-distance-v1")
        XCTAssertEqual(manifest.patches?.count, 2)
        XCTAssertEqual(manifest.patches?.first?.id, "pair_1#first")
        XCTAssertEqual(manifest.patches?.first?.source_color, "#FF0000")
        XCTAssertEqual(manifest.patches?.first?.rect?.width ?? 0, 16, accuracy: 0.0001)
        XCTAssertEqual(manifest.pairs?.first?.first_patch_id, "pair_1#first")
        XCTAssertEqual(manifest.pairs?.first?.grid_col, 1)
    }

    func testDecodesRecentSheetsWithNullableTitle() throws {
        let payload = try JSONDecoder().decode(Types.Schemas.RecentSheetsResponse.self, from: OpenAPIFixtures.jsonData(OpenAPIFixtures.recentSheets))

        XCTAssertEqual(payload.sheets.count, 2)
        XCTAssertEqual(payload.sheets.first?.sheet_id, "sheet_1")
        XCTAssertNil(payload.sheets.first?.title)
        XCTAssertEqual(payload.sheets.last?.title, "July LPS comparison sheet")
    }

    func testDecodesCaptureCreatedResponse() throws {
        let payload = try JSONDecoder().decode(Types.Schemas.CaptureCreatedResponse.self, from: OpenAPIFixtures.jsonData(OpenAPIFixtures.captureCreated))

        XCTAssertEqual(payload.capture_id, "42")
    }

    func testDecodesMeasurementAndJudgmentUploadResponses() throws {
        let measurements = try JSONDecoder().decode(Types.Schemas.MeasurementUploadResponse.self, from: OpenAPIFixtures.jsonData(OpenAPIFixtures.measurementUploadResponse))
        XCTAssertEqual(measurements.measurement_count, 2)
        XCTAssertEqual(measurements.pair_score_count, 1)

        let judgments = try JSONDecoder().decode(Types.Schemas.JudgmentUploadResponse.self, from: OpenAPIFixtures.jsonData(OpenAPIFixtures.judgmentUploadResponse))
        XCTAssertEqual(judgments.judgment_count, 1)
    }

    func testDecodesRankedResultsFromWirePayload() throws {
        let payload = try JSONDecoder().decode(Types.Schemas.RankedResults.self, from: OpenAPIFixtures.jsonData(OpenAPIFixtures.rankedResults))

        XCTAssertEqual(payload.schema_version, "lps-ranked-results/v1")
        XCTAssertEqual(payload.sheet_id, "sheet_1")
        XCTAssertEqual(payload.scoring_algorithm_versions?.count, 1)

        let first = try XCTUnwrap(payload.results?.first)
        XCTAssertEqual(first.rank, 1)
        XCTAssertEqual(first.pair_id, "pair_1")
        XCTAssertEqual(first.current_judgment, "near_match")
        XCTAssertEqual(first.source_colors?.color_a_hex, "#FF0000")
        XCTAssertEqual(first.source_colors?.color_b_hex, "#00FF00")
        XCTAssertEqual(first.score?.capture_count, 2)
        XCTAssertEqual(first.score?.sample_count, 4)
        XCTAssertEqual(first.latest_observation?.judgment, "near_match")
    }

    func testDecodesErrorResponse() throws {
        let payload = try JSONDecoder().decode(Types.Schemas.ApiErrorResponse.self, from: OpenAPIFixtures.jsonData(OpenAPIFixtures.errorResponse))

        XCTAssertNotNil(payload.errors)
    }

    func testEncodesCaptureMetadataWithSnakeCaseWireKeys() throws {
        let timestamp = Date(timeIntervalSince1970: 1_784_980_800)
        let metadata = Types.Schemas.CaptureMetadata(
            device_model: "iPhone",
            lens: "built_in_wide_angle",
            image_width: 4032,
            image_height: 3024,
            app_version: "0.1.0",
            timestamp: timestamp
        )

        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(metadata)) as? [String: Any])
        XCTAssertEqual(json["device_model"] as? String, "iPhone")
        XCTAssertEqual(json["lens"] as? String, "built_in_wide_angle")
        XCTAssertEqual(json["image_width"] as? Int, 4032)
        XCTAssertEqual(json["image_height"] as? Int, 3024)
        XCTAssertEqual(json["app_version"] as? String, "0.1.0")
        XCTAssertNotNil(json["timestamp"])

        let decoded = try JSONDecoder().decode(Types.Schemas.CaptureMetadata.self, from: JSONEncoder().encode(metadata))
        XCTAssertEqual(decoded.timestamp.timeIntervalSince1970, timestamp.timeIntervalSince1970, accuracy: 1.0)
    }
}
