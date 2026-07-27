# Companion iOS MVP Plan

## Purpose

`ColorMatching-iOS` is a companion iPhone app for `viamin/color_matching`.

The Phoenix `color_matching` web app is the source of truth for palettes, printable sheets, patch IDs, pair definitions, provenance, uploaded measurements, user judgments, and future prediction/analysis. This iOS app photographs printed sheets from `color_matching` under low-pressure sodium lighting, measures how printed colors appear to the camera, ranks color pairs by similarity, lets the user label pairs, and uploads the observations back to `color_matching`.

The goal is repeatable relative comparison under a controlled setup. Do not claim the iPhone measures absolute 589 nm reflectance.

## Hard Repo Boundary

This repository owns only the iOS companion app and shared API documentation.

Do not add or copy Phoenix application code here:

- No `mix.exs`
- No Phoenix controllers, routes, LiveViews, schemas, or migrations
- No copied `viamin/color_matching` source
- No palette/grid generation logic beyond decoding and trusting the fetched manifest

Any web work belongs in the real `viamin/color_matching` repository as a separate change set. This repo may document the API that web app must expose.

## Current State

Implemented in this repo:

- Swift package at `iOS/`
- `ColorMatchingLPSApp` SwiftUI shell
- `APIClient` scaffold for manifest/capture/measurement/judgment calls
- `CameraController` using AVFoundation with rear wide-angle camera selection and camera-lock path on iOS
- `MeasurementCore` with manifest models, homography mapping, synthetic patch sampling, sRGB-to-linear conversion, reference normalization, quality gates, and `lps-distance-v1` scoring
- Unit tests for geometry, sampling, normalization, quality gates, and scoring
- API contract doc at `docs/color-matching-api-contract.md`

Not yet MVP-ready:

- No real QR or sheet-code scanner
- No recent-sheet picker from the web API
- No real captured-image to linear pixel buffer extraction
- No registration-marker detection from actual camera images
- No live alignment guidance
- No sampled-region debug overlay
- Upload flow exists in code but is not wired end to end through the UI
- No physical iPhone validation
- No LPS lamp validation
- Required `viamin/color_matching` API and printable-sheet support is not implemented here

## iOS Architecture

Minimum supported iOS: 17.0.

Targets:

- `ColorMatchingLPSApp`: SwiftUI app shell, manifest lookup, capture workflow, ranked pair UI, user judgments, uploads.
- `MeasurementCore`: pure Swift domain logic for geometry, sampling, normalization, capture quality, and scoring.

Components:

- `APIClient`: talks to the Phoenix API contract in `docs/color-matching-api-contract.md`.
- `CameraController`: uses AVFoundation, selects `.builtInWideAngleCamera` at `.back`, avoids virtual multi-camera devices, locks focus/exposure duration/ISO/white balance after setup, and captures a high-quality still frame.
- `MeasurementCore`: decodes manifests, maps manifest-space patch rectangles to image-space sample regions, retains raw linear RGB statistics, normalizes via reference patches, rejects bad captures, and scores pairs.
- UI views: manifest lookup, capture guidance, captured-sheet debug overlay, ranked-pair review, judgment labeling, upload status.

## Product Workflow

1. User creates a palette or comparison grid in `viamin/color_matching`.
2. `color_matching` generates a camera-readable printable sheet.
3. User prints the sheet.
4. User takes the sheet to an LPS-lit area.
5. User opens this iOS app.
6. App identifies the sheet by manifest URL, sheet code, QR code, recent-sheet picker, or manual entry.
7. App fetches the manifest from `color_matching`.
8. App guides alignment against the printed sheet.
9. App locks camera settings and captures the sheet.
10. App detects registration markers and maps manifest patch rectangles into image coordinates.
11. App samples safe inset regions for every patch and records robust linear RGB statistics.
12. App normalizes measurements with reference patches.
13. App rejects bad captures when needed.
14. App ranks color pairs by measured similarity.
15. User labels pairs as `match`, `near_match`, or `no_match`.
16. App uploads capture metadata, raw/normalized measurements, scores, and labels to `color_matching`.
17. `color_matching` stores observations and later uses them to improve predictions for future palettes.

## Sheet Identification Strategy

Primary MVP requirement: the app must reliably associate a capture with the correct manifest from `color_matching`.

Acceptable lookup methods:

- Manual manifest URL entry
- Manual short sheet code entry
- Recent sheet picker from the web API
- QR code containing a manifest URL or sheet ID

QR is convenient but not mandatory. Do not frame QR scanning as the only correct mechanism.

Optional fallback:

- OCR the printed color legend to recover colors from old or non-manifest sheets.

OCR is not the primary MVP path because it is less reliable under LPS lighting and does not carry full provenance, patch IDs, coordinates, reference roles, or sheet version. If implemented, OCR-derived captures must be marked lower-confidence and must store that provenance.

## Required `viamin/color_matching` Work

The Phoenix app must provide the controlled target and durable data store:

- Palette/grid remains the source of truth.
- Printable camera-readable sheet with stable sheet ID and schema version.
- Machine-readable or human-enterable manifest reference.
- Unique patch IDs.
- Four corner registration markers.
- Known page dimensions and patch coordinates.
- White, gray, black, and blank-paper reference patches.
- Repeated reference patches in multiple page positions.
- Printer profile, paper, ink, and print settings provenance.
- Versioned manifest endpoint.
- Capture session endpoint.
- Measurement upload endpoint.
- Judgment upload endpoint.
- Ranked results endpoint.
- Stored negative and near-match judgments, not just successful matches.

The API contract expected by iOS is in `docs/color-matching-api-contract.md`.

## MVP Implementation Phases

### Phase 1: Web Contract Dependency

In the real `viamin/color_matching` repo, implement or stub enough API support to let the iOS app fetch a manifest and upload one capture.

Acceptance:

- A printed sheet includes a stable sheet identifier and manifest lookup value.
- `GET /api/v1/test_sheets/:sheet_id/manifest` returns the documented manifest.
- Capture, measurement, score, and judgment endpoints accept the documented payloads.
- A fixture manifest is available for iOS tests/manual development.

### Phase 2: Manifest Lookup In iOS

Wire the SwiftUI app to identify and fetch a real manifest.

Acceptance:

- User can paste a manifest URL.
- User can enter a short sheet code if the API supports it.
- Failed fetches show actionable errors.
- Manifest decoding is covered by tests using a fixture from `color_matching`.

### Phase 3: Real Camera Capture

Complete the device capture path.

Acceptance:

- App requests camera permission.
- App uses one physical rear wide-angle camera.
- App does not use virtual multi-camera devices.
- App lets the image settle, then locks focus, exposure duration, ISO, and white-balance gains.
- Capture metadata records device model, lens, exposure, ISO, focus, white-balance gains, image dimensions, app version, and timestamp.

### Phase 4: Registration And Patch Sampling

Convert real captured images into patch measurements.

Acceptance:

- Detects four corner registration markers or rejects the capture.
- Computes perspective transform from sheet coordinates to image coordinates.
- Samples each manifest patch using its safe inset.
- Retains raw linear RGB median, mean, standard deviation, min, max, sample count, and clipping fraction.
- Includes a synthetic image fixture test for patch extraction without a physical lamp.

### Phase 5: Quality Gates And Debug Overlay

Make bad captures obvious and inspectable.

Acceptance:

- Rejects missing markers, incomplete sheet coverage, clipping, excessive blur, severe glare, and poor reference patches.
- Shows sampled regions overlaid on the captured image.
- Shows rejection reasons and allows recapture.

### Phase 6: Normalization And Scoring

Rank pairs from measured appearance, not display RGB.

Acceptance:

- Normalizes with black/white and repeated reference patches.
- Keeps raw and normalized measurements.
- Scores pairs with a versioned algorithm such as `lps-distance-v1`.
- Ranking UI shows closest pairs first.
- Scoring logic remains isolated for future calibrated weights or learned models.

### Phase 7: Uploads And Labels

Close the loop back to `color_matching`.

Acceptance:

- Creates a capture session.
- Uploads capture metadata, per-patch measurements, and pair scores.
- Lets the user label each pair as `match`, `near_match`, or `no_match`.
- Uploads labels.
- Shows upload success/failure.

### Phase 8: Field Validation

Validate with the actual camera, printer, paper, and lamp.

Acceptance:

- Print one controlled sheet.
- Capture multiple times without moving the setup.
- Capture multiple times after repositioning the phone.
- Label a representative sample of pairs.
- Report within-patch variance, repeated-reference drift, rejection rate, and ranking stability.

## Testing Plan

iOS automated tests:

- Manifest decoding from real fixture JSON.
- Homography/geometry mapping.
- Synthetic patch extraction.
- sRGB or captured-buffer linearization path.
- Reference normalization.
- Quality gates.
- LPS pair scoring.
- API request encoding for capture, measurements, scores, and judgments.

Manual tests:

- Physical iPhone camera permission and camera selection.
- Camera setting lock under LPS lighting.
- Alignment guidance.
- Debug overlay accuracy.
- Uploads against local `color_matching`.
- Repeatability report from multiple captures.

## MVP Definition Of Done

The MVP is ready when:

- `color_matching` can generate and print a manifest-backed test sheet.
- This app can fetch that manifest.
- This app can capture the printed sheet on a physical iPhone under LPS lighting.
- This app can extract and normalize patch measurements from the real capture.
- This app can rank pair similarity from measured linear RGB.
- User can label matches, near matches, and non-matches.
- Results upload back to `color_matching` with sheet, patch, printer, capture, measurement, score, and judgment provenance.
- Automated tests cover core geometry, sampling, normalization, scoring, and API payloads.
- Manual validation reports repeatability and ranking stability.

## Deferred Improvements

- RAW capture.
- Advanced illumination correction.
- Empirical channel-weight calibration.
- Active learning.
- Spectrometer validation.
- OCR legend recovery for old/non-manifest sheets.
- Account-based auth or multi-user collaboration.
