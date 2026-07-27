# ColorMatching iOS Companion

Swift/SwiftUI companion app for `viamin/color_matching`.

The Phoenix web app creates palettes and printable color-comparison sheets. This iOS app photographs those sheets under low-pressure sodium lighting, measures patch appearance, ranks color-pair similarity, lets the user label pairs, and uploads observations back to the web app API.

## Setup

```bash
cd iOS
swift test --disable-sandbox
```

Open `iOS/Package.swift` in Xcode and run the `ColorMatchingLPS` executable target on a physical iPhone for camera capture.

## Docs

- `docs/companion-ios-mvp-plan.md`
- `docs/color-matching-api-contract.md`
