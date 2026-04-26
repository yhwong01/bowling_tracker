# iOS App Shell

## What this adds

The repo now includes a minimal SwiftUI iPhone app shell:

- `BowlingApp.xcodeproj`
- `BowlingIOSApp/`
- `builder.json.example`

This is the piece that turns the repo from a Swift package into something an iOS build system can archive into an `.ipa`.

## Structure

- `BowlingApp.xcodeproj`
  - shared scheme: `BowlingApp`
  - local Swift package dependency: repo root `.` -> product `BowlingTrackingCore`
- `BowlingIOSApp/BowlingAppApp.swift`
  - app entry point
- `BowlingIOSApp/ContentView.swift`
  - sample SwiftUI screen that imports and uses `BowlingTrackingCore`
- `BowlingIOSApp/Info.plist`
  - explicit app metadata
- `BowlingIOSApp/Assets.xcassets`
  - placeholder asset catalog

## What you still need before a real installable build

1. Open the project in Xcode on a macOS builder.
2. Set a real `DEVELOPMENT_TEAM`.
3. Change `PRODUCT_BUNDLE_IDENTIFIER` from `com.example.BowlingApp`.
4. Add signing assets for archive/export if you want a signed `.ipa`.

## ios-builder expectations

For `ios-builder`, the important values are:

- project path: `BowlingApp.xcodeproj`
- scheme: `BowlingApp`
- iOS source path: repo root `.`
- example config: `builder.json.example`

`ios-builder` can then generate the GitHub Actions workflow and archive the app remotely on macOS runners.
