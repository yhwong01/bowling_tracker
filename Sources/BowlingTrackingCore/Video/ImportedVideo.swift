import Foundation

public struct ImportedVideo: Sendable, Equatable, Codable {
    public var filePath: String
    public var title: String?
    public var durationSeconds: Double?
    public var frameRate: Double?
    public var frameSize: ImageSize?

    public init(
        filePath: String,
        title: String? = nil,
        durationSeconds: Double? = nil,
        frameRate: Double? = nil,
        frameSize: ImageSize? = nil
    ) {
        self.filePath = filePath
        self.title = title
        self.durationSeconds = durationSeconds
        self.frameRate = frameRate
        self.frameSize = frameSize
    }
}

public enum VideoAnalysisMode: String, Sendable, Equatable, Codable {
    case singleShot
    case multiShotSession
}

public struct ManualShotRange: Sendable, Equatable, Codable {
    public var identifier: String
    public var startTimeSeconds: Double
    public var endTimeSeconds: Double
    public var bowlerName: String?

    public init(
        identifier: String,
        startTimeSeconds: Double,
        endTimeSeconds: Double,
        bowlerName: String? = nil
    ) {
        self.identifier = identifier
        self.startTimeSeconds = startTimeSeconds
        self.endTimeSeconds = endTimeSeconds
        self.bowlerName = bowlerName
    }
}

public struct ImportedVideoAnalysisRequest: Sendable, Equatable, Codable {
    public var video: ImportedVideo
    public var mode: VideoAnalysisMode
    public var dominantHand: BowlingHand
    public var calibration: LaneCalibration?
    public var frameSamplingFPS: Double
    public var trimStartSeconds: Double?
    public var trimEndSeconds: Double?
    public var manualShotRanges: [ManualShotRange]

    public init(
        video: ImportedVideo,
        mode: VideoAnalysisMode,
        dominantHand: BowlingHand,
        calibration: LaneCalibration? = nil,
        frameSamplingFPS: Double = 60.0,
        trimStartSeconds: Double? = nil,
        trimEndSeconds: Double? = nil,
        manualShotRanges: [ManualShotRange] = []
    ) {
        self.video = video
        self.mode = mode
        self.dominantHand = dominantHand
        self.calibration = calibration
        self.frameSamplingFPS = frameSamplingFPS
        self.trimStartSeconds = trimStartSeconds
        self.trimEndSeconds = trimEndSeconds
        self.manualShotRanges = manualShotRanges
    }
}

public struct VideoFrame: Sendable, Equatable, Codable {
    public var index: Int
    public var timestamp: TimeInterval
    public var imagePath: String
    public var imageSize: ImageSize

    public init(index: Int, timestamp: TimeInterval, imagePath: String, imageSize: ImageSize) {
        self.index = index
        self.timestamp = timestamp
        self.imagePath = imagePath
        self.imageSize = imageSize
    }
}

public struct VideoShotSegment: Sendable, Equatable, Codable {
    public var identifier: String
    public var startTimeSeconds: Double
    public var endTimeSeconds: Double
    public var bowlerName: String?
    public var confidence: Double

    public init(
        identifier: String,
        startTimeSeconds: Double,
        endTimeSeconds: Double,
        bowlerName: String? = nil,
        confidence: Double = 1.0
    ) {
        self.identifier = identifier
        self.startTimeSeconds = startTimeSeconds
        self.endTimeSeconds = endTimeSeconds
        self.bowlerName = bowlerName
        self.confidence = confidence
    }
}

public struct ImportedShotAnalysisResult: Sendable, Equatable, Codable {
    public var segment: VideoShotSegment
    public var calibration: LaneCalibration
    public var track: BallTrack
    public var metrics: ShotMetrics
    public var warnings: [String]

    public init(
        segment: VideoShotSegment,
        calibration: LaneCalibration,
        track: BallTrack,
        metrics: ShotMetrics,
        warnings: [String] = []
    ) {
        self.segment = segment
        self.calibration = calibration
        self.track = track
        self.metrics = metrics
        self.warnings = warnings
    }
}

public struct ImportedVideoAnalysisSummary: Sendable, Equatable, Codable {
    public var shotCount: Int
    public var averageLaunchSpeedMph: Double?
    public var averageImpactSpeedMph: Double?
    public var averageHookBoards: Double?

    public init(
        shotCount: Int,
        averageLaunchSpeedMph: Double? = nil,
        averageImpactSpeedMph: Double? = nil,
        averageHookBoards: Double? = nil
    ) {
        self.shotCount = shotCount
        self.averageLaunchSpeedMph = averageLaunchSpeedMph
        self.averageImpactSpeedMph = averageImpactSpeedMph
        self.averageHookBoards = averageHookBoards
    }
}

public struct ImportedVideoAnalysisResult: Sendable, Equatable, Codable {
    public var request: ImportedVideoAnalysisRequest
    public var resolvedVideo: ImportedVideo
    public var shots: [ImportedShotAnalysisResult]
    public var warnings: [String]
    public var summary: ImportedVideoAnalysisSummary

    public init(
        request: ImportedVideoAnalysisRequest,
        resolvedVideo: ImportedVideo,
        shots: [ImportedShotAnalysisResult],
        warnings: [String] = [],
        summary: ImportedVideoAnalysisSummary
    ) {
        self.request = request
        self.resolvedVideo = resolvedVideo
        self.shots = shots
        self.warnings = warnings
        self.summary = summary
    }
}
