# PC Upload Analysis MVP

## Goal

Create a desktop version of the bowling tracker that analyzes uploaded videos instead of relying on real-time camera capture.

## Core user flow

1. The user opens the desktop app.
2. The user uploads a bowling video from disk.
3. The app asks the user to confirm the lane and optionally trim the clip.
4. If the clip contains multiple bowlers or multiple shots, the app lets the user split the video into shot ranges.
5. The app runs offline analysis on each selected shot.
6. The app returns the same metric family as the iPhone flow:
   - foul line board
   - arrows board
   - launch angle
   - launch speed
   - average speed
   - impact speed
   - breakpoint board
   - breakpoint distance
   - entry board
   - hook boards
   - shot time

## Why desktop upload mode is a good fit

- No tripod setup is required at capture time.
- The user can analyze older practice videos.
- We can support manual corrections that are harder to do during live capture.
- Long videos with many bowlers can be segmented into individual shots after upload.

## Recommended MVP shape

The first desktop release should be offline-first and deterministic:

- one lane per uploaded video
- user-assisted shot trimming
- user-confirmed lane calibration
- analysis after upload, not during playback

## Architecture

### 1. Video ingest

The app accepts a local video file and creates an analysis request.

Request fields should include:

- file path
- mode: single shot or multi-shot session
- handedness
- sampling FPS
- optional trim window
- optional manual shot ranges

### 2. Frame extraction

Offline analysis should extract frames from the uploaded file before tracking.

A practical Windows path is to use FFmpeg for:

- video metadata inspection
- frame extraction
- optional clip trimming

Official FFmpeg documentation:

- https://www.ffmpeg.org/documentation.html
- https://ffmpeg.org/ffmpeg-doc.html

## 3. Shot segmentation

For the desktop MVP, manual shot ranges are completely acceptable and should be supported first.

That means the user can:

- upload a long video
- mark the start and end of each shot
- optionally label the bowler

Automatic multi-shot segmentation can come later.

## 4. Lane calibration

Desktop mode should reuse the same lane calibration concept as the phone version:

- detect or confirm lane boundaries
- project image space into lane coordinates
- compute board and distance values from tracked ball positions

## 5. Ball tracking and metrics

Once a shot is isolated, the downstream metric pipeline is the same as before:

- detect the ball in each relevant frame
- project detections into lane coordinates
- build a `BallTrack`
- run metric estimation

## What this repo now includes

This repo now adds the offline-analysis foundation:

- imported-video request/result models
- offline pipeline protocols
- an analyzer orchestrator
- a Windows CLI target

The CLI is intended as the backend contract for a future desktop UI. The UI can call it after a user uploads a file or edits shot ranges.

## Suggested desktop milestones

1. Upload video and create an analysis request.
2. Support manual shot trimming and multiple shot ranges.
3. Add lane calibration confirmation UI.
4. Add actual frame extraction and ball detection adapters.
5. Save shot results and review them in a session screen.
