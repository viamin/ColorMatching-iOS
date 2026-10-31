import Foundation
import XCTest
@testable import ColorMatchingLPSAppCore

/// Exercises `CaptureMetadata` against the shape required by the published
/// `color_matching` OpenAPI spec (`ColorMatchingWeb.ApiSchemas.CaptureMetadata`,
/// viamin/color_matching#113), not just the hand-written prose contract.
/// See `docs/openapi-contract-deltas.md`.
final class CaptureMetadataContractTests: XCTestCase {
    /// The real spec requires `image_width` and `image_height` on every
    /// capture, but `CaptureMetadata` models them as `Int?`. Swift's
    /// synthesized `Encodable` omits a nil `Optional` key entirely, so a
    /// capture recorded without image dimensions currently encodes a
    /// request the real API would reject as missing required fields.
    func testEncodingWithoutImageDimensionsOmitsFieldsRequiredByRealSchema() throws {
        let metadata = CaptureMetadata(
            deviceModel: "iPhone",
            lens: "built_in_wide_angle",
            exposureDurationSeconds: nil,
            iso: nil,
            focusLensPosition: nil,
            whiteBalanceGains: nil,
            imageWidth: nil,
            imageHeight: nil,
            appVersion: "0.1.0",
            timestamp: Date(timeIntervalSince1970: 0)
        )

        let data = try JSONEncoder().encode(metadata)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertNotNil(json["image_width"], "color_matching's published spec requires image_width on every capture")
        XCTAssertNotNil(json["image_height"], "color_matching's published spec requires image_height on every capture")
    }
}
