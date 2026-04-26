# Bowling App

An iOS-first tenpin bowling tracking app focused on single-phone shot analytics.

## First feature: single-camera shot tracking

The first feature targets the setup you described:

- The bowler mounts an iPhone on a stand or tripod behind the approach.
- The rear camera captures the lane and the shot.
- The app detects the lane, tracks the ball, and computes bowling metrics from the ball path.

The initial metrics we should optimize for are:

- Foul line board
- Arrows board
- Launch angle
- Launch speed
- Average speed
- Impact speed
- Breakpoint board
- Breakpoint distance
- Entry board
- Hook boards
- Shot time

## PC version: uploaded video analysis

The PC version should not depend on live capture. Instead, the user should:

- upload a bowling video from disk
- optionally trim the clip or mark multiple shots
- run offline frame-by-frame analysis
- receive the same shot metrics as the phone workflow

That desktop flow is a good fit for:

- longer videos with multiple bowlers
- re-analysis of saved practice sessions
- manual correction steps like lane alignment, shot trimming, and breakpoint review

## Important product note

With one fixed phone camera, the strongest MVP is a calibrated 2D lane-tracking system. That is enough for trajectory and speed-derived metrics. Metrics like true rev rate, axis tilt, or exact 3D release details are harder and should be treated as later phases unless we require:

- High frame rate capture
- Clear ball markings
- More robust ball-surface tracking
- Potentially additional sensors or stronger model support

## Recommended stack

- `SwiftUI` for app UI
- `AVFoundation` for camera capture
- `Vision` for frame-level detections and tracking support
- `Core ML` for custom ball and lane detection models
- A pure-Swift tracking core for metric estimation and testability

## Repo layout

- [docs/vision-tracking-mvp.md](/c:/bowling_app/docs/vision-tracking-mvp.md) explains the feature scope, user flow, metrics, risks, and rollout plan.
- [docs/pc-upload-analysis-mvp.md](/c:/bowling_app/docs/pc-upload-analysis-mvp.md) explains the desktop upload-video workflow and offline analysis architecture.
- [docs/ios-app-shell.md](/c:/bowling_app/docs/ios-app-shell.md) explains the minimal iPhone app shell and what is still required before archiving an `.ipa`.
- [BowlingApp.xcodeproj](/c:/bowling_app/BowlingApp.xcodeproj) is the iOS project shell that remote macOS builders can archive.
- [builder.json.example](/c:/bowling_app/builder.json.example) is a starter `ios-builder` config for this repo layout.
- [Package.swift](/c:/bowling_app/Package.swift) defines a reusable `BowlingTrackingCore` Swift package.
- [Sources/BowlingTrackingCore](/c:/bowling_app/Sources/BowlingTrackingCore) contains domain models and metric estimation logic.
- [Sources/BowlingVideoAnalyzerCLI](/c:/bowling_app/Sources/BowlingVideoAnalyzerCLI) contains a Windows-friendly CLI entry point for offline workflows.
- [BowlingIOSApp](/c:/bowling_app/BowlingIOSApp) contains the SwiftUI iPhone app shell.
- [Tests/BowlingTrackingCoreTests/ShotMetricEstimatorTests.swift](/c:/bowling_app/Tests/BowlingTrackingCoreTests/ShotMetricEstimatorTests.swift) covers the first core calculations.

## Suggested milestone order

1. Build lane calibration and confirm the lane overlay is accurate.
2. Track the ball center over time in lane coordinates.
3. Ship reliable metrics for foul line, arrows, speeds, launch angle, breakpoint, and entry board.
4. Add session history, lane maps, and trend views.
5. Add advanced metrics like rev rate only after data quality is proven.

## Windows build helpers

If Swift is installed through the official Windows installer, you can use:

- `.\scripts\build.ps1`
- `.\scripts\test.ps1`

These scripts:

- find the installed Swift toolchain and runtime
- set `SDKROOT` to the installed Windows Swift SDK
- enter the Visual Studio 2022 x64 developer environment
- run `swift build` or `swift test`

The package now also includes a CLI target for offline desktop workflows:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build.ps1
.\.build\x86_64-unknown-windows-msvc\debug\BowlingVideoAnalyzerCLI.exe help
```

## iPhone app shell

This repo now includes a minimal iPhone app target that imports `BowlingTrackingCore`.

- Xcode project: `BowlingApp.xcodeproj`
- shared scheme: `BowlingApp`
- app source: `BowlingIOSApp/`

Before creating a real installable IPA, you still need to set:

- your Apple team ID
- a real bundle identifier
- signing credentials or provisioning flow

For remote builds from Windows, that is the app shell a tool like `ios-builder` can point at.
