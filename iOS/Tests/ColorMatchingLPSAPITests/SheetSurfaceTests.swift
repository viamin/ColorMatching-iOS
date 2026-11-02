import XCTest

import ColorMatchingLPSAPI

final class SheetSurfaceTests: GeneratedClientTestCase {
    func testGetTestSheetManifestBuildsContractRequest() async throws {
        let recorder = RequestRecorder()
        let client = makeClient { request, body, _, operationID in
            await recorder.record(request, body: body, operationID: operationID)
            return HTTPResponse.stubbedJSON(.ok, Fixtures.manifest)
        }

        _ = try await client.getTestSheetManifest(.init(path: .init(sheet_id: "sheet_1")))

        let request = try XCTUnwrap(recorder.request("getTestSheetManifest"))
        XCTAssertEqual(request.method, .get)
        XCTAssertEqual(request.path, "/api/v1/test_sheets/sheet_1/manifest")
    }

    func testGetTestSheetManifestDecodesHeaderFields() async throws {
        let manifest = try await fetchManifest()

        XCTAssertEqual(manifest.schema_version, "lps-sheet-manifest/v1")
        XCTAssertEqual(manifest.sheet_version, "lps-letter-grid-v1")
        XCTAssertEqual(manifest.sheet_id, "sheet_1")
        XCTAssertEqual(manifest.manifest_url, "https://example.test/api/v1/test_sheets/sheet_1/manifest")
        XCTAssertEqual(manifest.created_at, Fixtures.manifestCreatedAt)
    }

    func testGetTestSheetManifestDecodesGeometry() async throws {
        let manifest = try await fetchManifest()

        XCTAssertEqual(manifest.page.units, "mm")
        XCTAssertEqual(manifest.page.width, 215.9)
        XCTAssertEqual(manifest.page.height, 279.4)
        XCTAssertEqual(manifest.registration_markers.first?.role, "top_left")
        XCTAssertEqual(manifest.registration_markers.first?.shape, "solid_square")
        XCTAssertEqual(manifest.registration_markers.first?.rect.width, 8)
    }

    func testGetTestSheetManifestDecodesPatches() async throws {
        let patches = try await fetchManifest().patches

        XCTAssertEqual(patches.count, 3)
        assertPairColorPatch(patches[0])
        XCTAssertEqual(patches[1].source_color, "#00FF00")
        XCTAssertEqual(patches[1].pair_side, "second")
        assertReferencePatch(patches[2])
    }

    func testGetTestSheetManifestDecodesPairs() async throws {
        let pairs = try await fetchManifest().pairs

        XCTAssertEqual(pairs.count, 1)
        XCTAssertEqual(pairs[0].id, "pair_1")
        XCTAssertEqual(pairs[0].first_patch_id, "patch_1")
        XCTAssertEqual(pairs[0].second_patch_id, "patch_2")
        XCTAssertEqual(pairs[0].source_colors, ["#FF0000", "#00FF00"])
        XCTAssertEqual(pairs[0].grid_row, 0)
        XCTAssertEqual(pairs[0].grid_col, 1)
    }

    func testUnknownPatchRoleSurfacesAsDecodingError() async throws {
        let client = makeClient { _, _, _, _ in
            HTTPResponse.stubbedJSON(.ok, Fixtures.manifestWithUnknownPatchRole)
        }

        let response = try await client
            .getTestSheetManifest(.init(path: .init(sheet_id: "sheet_1")))

        XCTAssertThrowsError(try response.ok.body.json)
    }

    func testListRecentTestSheetsDecodesTitles() async throws {
        let client = makeClient { _, _, _, _ in
            HTTPResponse.stubbedJSON(.ok, Fixtures.recentSheets)
        }

        let sheets = try await client
            .listRecentTestSheets(.init())
            .ok.body.json.sheets

        XCTAssertEqual(sheets.count, 2)
        XCTAssertEqual(sheets[0].sheet_id, "sheet_1")
        XCTAssertEqual(sheets[0].title, "July LPS comparison sheet")
        XCTAssertEqual(sheets[0].manifest_url, "https://example.test/api/v1/test_sheets/sheet_1/manifest")
        XCTAssertEqual(sheets[1].sheet_id, "sheet_2")
        XCTAssertNil(sheets[1].title)
    }

    func testListRecentTestSheetsBuildsContractRequest() async throws {
        let recorder = RequestRecorder()
        let client = makeClient { request, body, _, operationID in
            await recorder.record(request, body: body, operationID: operationID)
            return HTTPResponse.stubbedJSON(.ok, Fixtures.recentSheets)
        }

        _ = try await client.listRecentTestSheets(.init())

        let request = try XCTUnwrap(recorder.request("listRecentTestSheets"))
        XCTAssertEqual(request.method, .get)
        XCTAssertEqual(request.path, "/api/v1/test_sheets/recent")
    }

    private func fetchManifest() async throws -> Components.Schemas.TestSheetManifest {
        let client = makeClient { _, _, _, _ in
            HTTPResponse.stubbedJSON(.ok, Fixtures.manifest)
        }
        return try await client
            .getTestSheetManifest(.init(path: .init(sheet_id: "sheet_1")))
            .ok.body.json
    }

    private func assertPairColorPatch(_ patch: Components.Schemas.Patch) {
        XCTAssertEqual(patch.id, "patch_1")
        XCTAssertEqual(patch.role, .pair_color)
        XCTAssertEqual(patch.pair_id, "pair_1")
        XCTAssertEqual(patch.pair_side, "first")
        XCTAssertNil(patch.reference_role)
        XCTAssertEqual(patch.source_color, "#FF0000")
        XCTAssertEqual(patch.safe_inset_mm, 1.5)
        XCTAssertEqual(patch.rect.x, 16)
        XCTAssertEqual(patch.rect.y, 38)
    }

    private func assertReferencePatch(_ patch: Components.Schemas.Patch) {
        XCTAssertEqual(patch.id, "patch_3")
        XCTAssertEqual(patch.role, .reference)
        XCTAssertEqual(patch.reference_role, .gray)
        XCTAssertNil(patch.source_color)
        XCTAssertNil(patch.pair_id)
    }
}
