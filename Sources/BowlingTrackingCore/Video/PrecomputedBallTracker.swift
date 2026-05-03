import Foundation

public struct PrecomputedBallTracker: OfflineBallTracking {
    public var trackDirectory: URL
    public var fileExtension: String

    public init(trackDirectory: URL, fileExtension: String = "json") {
        self.trackDirectory = trackDirectory
        self.fileExtension = fileExtension
    }

    public func trackBall(
        in frames: [VideoFrame],
        request: ImportedVideoAnalysisRequest,
        segment: VideoShotSegment,
        calibration: LaneCalibration
    ) throws -> BallTrack {
        let fileURL = trackDirectory.appendingPathComponent("\(segment.identifier).\(fileExtension)")
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw VideoAnalysisError.missingTrackFile(identifier: segment.identifier)
        }

        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode(BallTrack.self, from: data)
    }
}
