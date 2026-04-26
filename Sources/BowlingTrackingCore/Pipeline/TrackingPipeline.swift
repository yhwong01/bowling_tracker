import Foundation

public struct CameraFrameMetadata: Sendable, Equatable {
    public var timestamp: TimeInterval
    public var imageSize: ImageSize

    public init(timestamp: TimeInterval, imageSize: ImageSize) {
        self.timestamp = timestamp
        self.imageSize = imageSize
    }
}

public struct BallDetectionCandidate: Sendable, Equatable {
    public var center: ImagePoint
    public var radiusPixels: Double
    public var confidence: Double

    public init(center: ImagePoint, radiusPixels: Double, confidence: Double) {
        self.center = center
        self.radiusPixels = radiusPixels
        self.confidence = confidence
    }
}

public protocol LaneCalibrating {
    func calibrate(
        imageSize: ImageSize,
        laneCorners: LaneCorners,
        dominantHand: BowlingHand
    ) throws -> LaneCalibration
}

public protocol BallDetecting {
    func detectBall(in frame: CameraFrameMetadata) -> BallDetectionCandidate?
}

public protocol BallProjecting {
    func projectToLane(
        candidate: BallDetectionCandidate,
        frame: CameraFrameMetadata,
        calibration: LaneCalibration
    ) -> LaneCoordinate?
}

public protocol ShotAnalyzing {
    func estimate(from track: BallTrack) -> ShotMetrics
}
