# Issue #5: generated OpenAPI client

## Criterion verification plan

| Criterion | Smallest credible verification | Status in this test-writing PR |
| --- | --- | --- |
| Generated dependency and vendored API description | Focused Swift test checks the package dependencies and the vendored OpenAPI document includes every app surface. | Red: implementation pending. |
| Manifest, recent sheets, capture creation, measurement upload, and judgment upload | Permanent `URLProtocol`-stubbed Swift tests exercise the public app client without a live server. | Manifest and recent-sheets coverage added; existing tests cover the three write calls. |
| Ranked results | Permanent stubbed Swift test of the public wrapper once its generated operation is exposed. | Red: the current wrapper has no ranked-results operation. |
| Replace hand-written wire models | Code review of the generated-client integration and compilation after regeneration. | Human/external evidence required. |
| Contract deltas and endpoint gaps | This note, updated in the implementation PR description with the pinned OpenAPI revision. | Recorded below. |

## Contract deltas found against `color_matching` #110 / PR #113

- The published `Manifest` schema requires only `schema_version`, `sheet_id`, and `capture_profile.scoring_algorithm_version`; the prose contract describes many additional manifest, geometry, printer-profile, and capture-profile fields that the app currently decodes.
- `RankedResults` similarly requires only `schema_version` and `sheet_id`, although the server renderer returns rankings, score aggregates, provenance, source colors, and judgments. A generated client cannot strongly type those omitted response fields until the upstream schema is expanded.
- The server's capture schema accepts both the prose contract's nested `metadata`/`quality` payload and a legacy flattened shape. Within nested metadata, image width, image height, app version, and timestamp are required; the prose contract presents several capture fields as optional without documenting the server's requirements.
- The OpenAPI measurement-upload schema requires a normalized RGB value for each measurement, supports RGB arrays, objects, or JSON strings, and does not describe the prose contract's `stats` object or a top-level `scoring_algorithm_version`.
- Measurement and judgment uploads return JSON count responses in the published schema, whereas the current iOS client treats them as empty successful responses.
- Recent-sheet `title` is required-but-nullable in the published schema, matching the prose contract's nullable title.

## Endpoint gaps

- The current iOS wrapper has no ranked-results operation despite the documented endpoint. Add it before claiming all generated surfaces are wired.
- The upstream spec's response schemas for manifest and ranked results must be expanded before the app can replace all hand-written response models without losing typed fields it consumes.
