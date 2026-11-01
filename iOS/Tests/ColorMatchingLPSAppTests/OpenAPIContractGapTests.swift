import Foundation
import MeasurementCore
import XCTest

/// Characterizes a gap between the hand-written `RGB` Codable model and the
/// real `color_matching` API, discovered by reading the published
/// `RgbPayload` OpenApiSpex schema (viamin/color_matching, PR #113): the
/// server accepts `linear_rgb_median` / `normalized_linear_rgb_median` as an
/// object (`{"r":...}`), a flat 3-number array, or a JSON-encoded string —
/// not only the object form `RGB` currently decodes.
///
/// These are expected RED failures (issue #5): they document a concrete
/// decoding gap the generated/replacement client must close, not a
/// regression in existing behavior. See
/// docs/openapi-client-migration-notes.md for the full research trail.
final class OpenAPIContractGapTests: XCTestCase {
    func testLinearRGBMedianDecodesArrayForm() throws {
        let json = Data(#"[0.12, 0.10, 0.02]"#.utf8)

        let rgb = try JSONDecoder().decode(RGB.self, from: json)

        XCTAssertEqual(rgb, RGB(r: 0.12, g: 0.10, b: 0.02))
    }

    func testLinearRGBMedianDecodesJSONEncodedStringForm() throws {
        let json = Data(#""[0.12, 0.10, 0.02]""#.utf8)

        let rgb = try JSONDecoder().decode(RGB.self, from: json)

        XCTAssertEqual(rgb, RGB(r: 0.12, g: 0.10, b: 0.02))
    }
}
