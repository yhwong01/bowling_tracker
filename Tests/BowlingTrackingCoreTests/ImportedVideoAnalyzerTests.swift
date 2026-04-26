import Foundation
import XCTest
@testable import BowlingTrackingCore

final class ImportedVideoAnalyzerTests: XCTestCase {
    func testAnalyzesMultipleManualShotRanges() throws {
        let analyzer = ImportedVideoAnalyzer(
            metadataReader: PassthroughVideoMetadataReader(),
            frameExtractor: StubFrameExtractor(),
            shotSegmenter: ManualOrWholeVideoShotSegmenter(),
            laneCalibrator: StubLaneCalibrator(),
            ballTracker: StubBallTracker()
        )

        let request = ImportedVideoAnalysisRequest(
            video: ImportedVideo(filePath: "practice-session.mp4", durationSeconds: 18.0, frameRate: 60.0),
            mode: .multiShotSession,
            dominantHand: .right,
            frameSamplingFPS: 60.0,
            manualShotRanges: [
                ManualShotRange(identifier: "shot-1", startTimeSeconds: 1.0, endTimeSeconds: 4.0, bowlerName: "Alex"),
                ManualShotRange(identifier: "shot-2", startTimeSeconds: 8.0, endTimeSeconds: 11.0, bowlerName: "Jordan")
            ]
        )

        let result = try analyzer.analyze(request)

        XCTAssertEqual(result.shots.count, 2)
        XCTAssertEqual(result.summary.shotCount, 2)
        XCTAssertEqual(result.shots[0].segment.identifier, "shot-1")
        XCTAssertEqual(result.shots[1].segment.identifier, "shot-2")
        XCTAssertNotNil(result.summary.averageLaunchSpeedMph)
    }

    func testRejectsInvalidManualShotRange() {
        let analyzer = ImportedVideoAnalyzer(
            metadataReader: PassthroughVideoMetadataReader(),
            frameExtractor: StubFrameExtractor(),
            shotSegmenter: ManualOrWholeVideoShotSegmenter(),
            laneCalibrator: StubLaneCalibrator(),
            ballTracker: StubBallTracker()
        )

        let request = ImportedVideoAnalysisRequest(
            video: ImportedVideo(filePath: "practice-session.mp4"),
            mode: .multiShotSession,
            dominantHand: .right,
            manualShotRanges: [
                ManualShotRange(identifier: "broken-shot", startTimeSeconds: 5.0, endTimeSeconds: 2.0)
            ]
        )

        XCTAssertThrowsError(try analyzer.analyze(request)) { error in
            XCTAssertEqual(
                error as? VideoAnalysisError,
                .invalidManualShotRange(identifier: "broken-shot", start: 5.0, end: 2.0)
            )
        }
    }
}

private struct StubFrameExtractor: VideoFrameExtracting {
    func extractFrames(from request: ImportedVideoAnalysisRequest) throws -> [VideoFrame] {
        [
            VideoFrame(index: 0, timestamp: 0.0, imagePath: "frame_0000.png", imageSize: ImageSize(width: 1920, height: 1080)),
            VideoFrame(index: 1, timestamp: 4.0, imagePath: "frame_0001.png", imageSize: ImageSize(width: 1920, height: 1080)),
            VideoFrame(index: 2, timestamp: 8.0, imagePath: "frame_0002.png", imageSize: ImageSize(width: 1920, height: 1080)),
            VideoFrame(index: 3, timestamp: 12.0, imagePath: "frame_0003.png", imageSize: ImageSize(width: 1920, height: 1080))
        ]
    }
}

private struct StubLaneCalibrator: VideoLaneCalibrating {
    func calibration(
        for frames: [VideoFrame],
        request: ImportedVideoAnalysisRequest,
        segment: VideoShotSegment
    ) throws -> LaneCalibration {
        LaneCalibration(
            imageSize: ImageSize(width: 1920, height: 1080),
            laneCorners: LaneCorners(
                foulLineLeft: ImagePoint(x: 0, y: 1000),
                foulLineRight: ImagePoint(x: 1920, y: 1000),
                pinDeckLeft: ImagePoint(x: 700, y: 100),
                pinDeckRight: ImagePoint(x: 1220, y: 100)
            ),
            dominantHand: request.dominantHand,
            confidence: 0.95
        )
    }
}

private struct StubBallTracker: OfflineBallTracking {
    func trackBall(
        in frames: [VideoFrame],
        request: ImportedVideoAnalysisRequest,
        segment: VideoShotSegment,
        calibration: LaneCalibration
    ) throws -> BallTrack {
        let offset = segment.identifier == "shot-2" ? 1.0 : 0.0

        return BallTrack(observations: [
            observation(time: segment.startTimeSeconds + 0.00, distance: 0.0, board: 24.0 - offset),
            observation(time: segment.startTimeSeconds + 0.25, distance: 15.0, board: 18.0 - offset),
            observation(time: segment.startTimeSeconds + 0.80, distance: 42.0, board: 8.0 - offset),
            observation(time: segment.startTimeSeconds + 1.15, distance: 60.0, board: 17.5)
        ])
    }
}

private func observation(time: TimeInterval, distance: Double, board: Double) -> BallObservation {
    BallObservation(
        timestamp: time,
        imageCenter: ImagePoint(x: 0, y: 0),
        laneCoordinate: LaneCoordinate(distanceFromFoulLineFeet: distance, board: board),
        radiusPixels: 24,
        confidence: 0.95
    )
}
