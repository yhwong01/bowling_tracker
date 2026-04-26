# Vision Tracking MVP

## Goal

Build an iPhone feature that tracks a bowling shot from a fixed rear camera and returns useful shot analytics without requiring special hardware.

## Reference product shape

LaneTrax publicly describes an iPhone-based setup that works from a tripod, detects the lane, and exposes metrics such as speed, arrows, breakpoint board, launch angle, and more:

- https://www.lanetrax.app/
- https://docs.lanetrax.app/getting-started
- https://docs.lanetrax.app/ios/newsessions/classic-mode

That is the closest target shape for this feature, but our MVP should stay narrower and focus on accuracy first.

## User flow

1. The user opens a new session.
2. The app shows a camera alignment screen.
3. The user mounts the phone behind the approach with a clear view of the lane and pins.
4. The app detects the lane boundary and asks the user to confirm the overlay.
5. The app waits for a shot.
6. When motion begins, the app tracks the ball until pin impact or tracking loss.
7. The app saves the trajectory and displays the shot metrics.

## Camera placement assumptions

For a single-phone setup, we should guide the user toward these constraints:

- Mount the phone behind the approach and behind the ball return.
- Keep the full lane in frame, with pins near the top of the preview.
- Offset the camera toward the bowler's gutter side so the body does not block the ball path.
- Keep the mount high and stable.
- Avoid including too much of neighboring lanes.

These assumptions match the setup style described in LaneTrax's public docs and materially improve tracking quality.

## MVP metrics

### Metrics we should ship first

- `foulLineBoard`
  - The board where the ball crosses the foul line.
- `arrowsBoard`
  - The board where the ball crosses the arrows, modeled at 15 feet from the foul line.
- `launchAngleDegrees`
  - Initial direction of travel relative to the lane boards.
- `launchSpeedMph`
  - Highest estimated speed near the front part of the lane.
- `averageSpeedMph`
  - Total traveled path divided by travel time.
- `impactSpeedMph`
  - Estimated speed close to the pins.
- `breakpointBoard`
  - The board where the ball reaches maximum outside deviation before moving back toward entry.
- `breakpointDistanceFeet`
  - Distance down-lane where breakpoint occurs.
- `entryBoard`
  - The board where the ball approaches the pocket near the pins.
- `hookBoards`
  - Absolute board change from breakpoint to entry.
- `shotTimeSeconds`
  - Time from first tracked lane contact to the end of the shot.

### Metrics to defer until later

- Rev rate
- Axis tilt
- Axis rotation
- Loft distance
- Exact release position off the hand
- Full foul detection for the bowler's foot

Those are possible follow-ons, but they are not the best starting point for a single fixed camera MVP.

## Architecture

### 1. Camera capture

- `AVCaptureSession`
- 60 fps minimum target
- Prefer 120 fps on supported devices for cleaner speed estimation
- Lock exposure and white balance where possible after setup

### 2. Lane calibration

Convert image space into lane space.

Inputs:

- Lane corners or lane edge lines
- Pin deck landmarks
- Known lane geometry
- Optional manual corner adjustment

Outputs:

- Homography from image coordinates to lane coordinates
- Per-frame mapping from detected ball center to:
  - `distanceFromFoulLineFeet`
  - `board`

Without calibration, any speed or board metric will drift badly across device positions.

### 3. Shot segmentation

Determine when a shot starts and ends.

Signals:

- Motion entering the lane region
- Ball candidate confidence
- Directional consistency toward the pins
- Optional pin-impact event or disappearance at the deck

### 4. Ball detection and tracking

Preferred approach:

- Detect the lane region first.
- Run ball detection only inside the lane ROI.
- Use a detector plus tracker combination:
  - detector for reacquisition
  - temporal tracker for stable frame-to-frame motion

Reasonable implementation path:

- Start with classical heuristics plus Vision tracking for a prototype.
- Move to a small Core ML detector once we gather real lane footage.
- Smooth the track with a Kalman filter or moving-window smoothing before metric extraction.

### 5. Metric estimation

After the ball track is projected into lane coordinates:

- Interpolate board values at fixed distances like the foul line and arrows.
- Compute instantaneous speed from consecutive track samples.
- Compute launch angle from the early segment of the trajectory.
- Compute impact angle from the last visible segment near the deck.
- Estimate breakpoint from the point of largest outside deviation relative to the start-to-entry path.

## Data model

At minimum, every tracked shot should save:

- Session ID
- Lane handedness context
- Device capture metadata
- Lane calibration
- Time-stamped ball observations
- Derived shot metrics
- Confidence flags

## Accuracy risks

The biggest sources of error are:

- Bowler occlusion at release
- Camera shake
- Neighboring lane interference
- Glare and reflections
- Incomplete lane in frame
- Incorrect zoom level
- Weak calibration near the foul line or pin deck
- Ball color blending into the lane environment

## Product constraints worth being honest about

- Single-camera 2D analytics are very feasible.
- True rev-rate estimation from any random house-shot environment is much less reliable.
- We should not market advanced ball-surface metrics until we have enough real footage to validate them.

## MVP acceptance criteria

We should call the first version successful when it can:

- Detect the intended lane and keep a stable overlay
- Track a visible ball from early lane contact to near the pins on common house conditions
- Return stable foul line, arrows, speed, launch angle, and breakpoint values on repeated throws
- Save a shot history that the user can review after each frame

## Next engineering step

Implement the feature in three slices:

1. `TrackingCore`
   - Pure Swift models and metric math
2. `Camera + Calibration`
   - AVFoundation capture and lane mapping
3. `UI`
   - alignment screen, live session, shot card, lane map

This repo now includes the first slice.
