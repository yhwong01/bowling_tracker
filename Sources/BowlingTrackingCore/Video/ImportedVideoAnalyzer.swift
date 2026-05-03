import Foundation

public enum VideoAnalysisError: Error, Equatable, CustomStringConvertible {
    case invalidSamplingFPS(Double)
    case invalidTrimRange(start: Double, end: Double)
    case invalidManualShotRange(identifier: String, start: Double, end: Double)
    case noFramesExtracted
    case noShotSegmentsDetected
    case trackTooShort(identifier: String)
    case missingExternalTool(String)
    case externalToolFailed(tool: String, message: String)
    case missingTrackFile(identifier: String)

    public var description: String {
        switch self {
        case .invalidSamplingFPS(let fps):
            return "Invalid frame sampling FPS: \(fps)."
        case .invalidTrimRange(let start, let end):
            return "Invalid trim range: start \(start) must be less than end \(end)."
        case .invalidManualShotRange(let identifier, let start, let end):
            return "Invalid manual shot range '\(identifier)': start \(start) must be less than end \(end)."
        case .noFramesExtracted:
            return "No frames were extracted from the imported video."
        case .noShotSegmentsDetected:
            return "No shot segments were detected for the imported video."
        case .trackTooShort(let identifier):
            return "The tracked ball path for shot '\(identifier)' is too short to compute metrics."
        case .missingExternalTool(let tool):
            return "Missing required external tool: \(tool)."
        case .externalToolFailed(let tool, let message):
            return "External tool '\(tool)' failed: \(message)"
        case .missingTrackFile(let identifier):
            return "No precomputed track was found for shot '\(identifier)'."
        }
    }
}

public protocol VideoMetadataReading {
    func resolveVideo(for video: ImportedVideo) throws -> ImportedVideo
}

public protocol VideoFrameExtracting {
    func extractFrames(from request: ImportedVideoAnalysisRequest) throws -> [VideoFrame]
}

public protocol VideoShotSegmenting {
    func detectShotSegments(
        in frames: [VideoFrame],
        request: ImportedVideoAnalysisRequest
    ) throws -> [VideoShotSegment]
}

public protocol VideoLaneCalibrating {
    func calibration(
        for frames: [VideoFrame],
        request: ImportedVideoAnalysisRequest,
        segment: VideoShotSegment
    ) throws -> LaneCalibration
}

public protocol OfflineBallTracking {
    func trackBall(
        in frames: [VideoFrame],
        request: ImportedVideoAnalysisRequest,
        segment: VideoShotSegment,
        calibration: LaneCalibration
    ) throws -> BallTrack
}

public struct PassthroughVideoMetadataReader: VideoMetadataReading {
    public init() {}

    public func resolveVideo(for video: ImportedVideo) throws -> ImportedVideo {
        video
    }
}

public struct ManualOrWholeVideoShotSegmenter: VideoShotSegmenting {
    public init() {}

    public func detectShotSegments(
        in frames: [VideoFrame],
        request: ImportedVideoAnalysisRequest
    ) throws -> [VideoShotSegment] {
        guard let firstFrame = frames.first, let lastFrame = frames.last else {
            throw VideoAnalysisError.noFramesExtracted
        }

        if !request.manualShotRanges.isEmpty {
            return request.manualShotRanges.map {
                VideoShotSegment(
                    identifier: $0.identifier,
                    startTimeSeconds: $0.startTimeSeconds,
                    endTimeSeconds: $0.endTimeSeconds,
                    bowlerName: $0.bowlerName
                )
            }
        }

        let startTime = request.trimStartSeconds ?? firstFrame.timestamp
        let endTime = request.trimEndSeconds ?? lastFrame.timestamp

        guard startTime < endTime else {
            throw VideoAnalysisError.invalidTrimRange(start: startTime, end: endTime)
        }

        return [
            VideoShotSegment(
                identifier: "shot-1",
                startTimeSeconds: startTime,
                endTimeSeconds: endTime
            )
        ]
    }
}

public struct ImportedVideoAnalyzer {
    public var metadataReader: any VideoMetadataReading
    public var frameExtractor: any VideoFrameExtracting
    public var shotSegmenter: any VideoShotSegmenting
    public var laneCalibrator: any VideoLaneCalibrating
    public var ballTracker: any OfflineBallTracking
    public var metricEstimator: ShotMetricEstimator

    public init(
        metadataReader: any VideoMetadataReading,
        frameExtractor: any VideoFrameExtracting,
        shotSegmenter: any VideoShotSegmenting,
        laneCalibrator: any VideoLaneCalibrating,
        ballTracker: any OfflineBallTracking,
        metricEstimator: ShotMetricEstimator = ShotMetricEstimator()
    ) {
        self.metadataReader = metadataReader
        self.frameExtractor = frameExtractor
        self.shotSegmenter = shotSegmenter
        self.laneCalibrator = laneCalibrator
        self.ballTracker = ballTracker
        self.metricEstimator = metricEstimator
    }

    public func analyze(_ request: ImportedVideoAnalysisRequest) throws -> ImportedVideoAnalysisResult {
        try validate(request: request)

        let resolvedVideo = try metadataReader.resolveVideo(for: request.video)
        var resolvedRequest = request
        resolvedRequest.video = resolvedVideo

        let frames = try frameExtractor.extractFrames(from: resolvedRequest)
        guard !frames.isEmpty else {
            throw VideoAnalysisError.noFramesExtracted
        }

        let segments = try shotSegmenter.detectShotSegments(in: frames, request: resolvedRequest)
        guard !segments.isEmpty else {
            throw VideoAnalysisError.noShotSegmentsDetected
        }

        let shotResults = try segments.map { segment in
            let calibration: LaneCalibration
            if let providedCalibration = resolvedRequest.calibration {
                calibration = providedCalibration
            } else {
                calibration = try laneCalibrator.calibration(
                    for: frames,
                    request: resolvedRequest,
                    segment: segment
                )
            }

            let track = try ballTracker.trackBall(
                in: frames,
                request: resolvedRequest,
                segment: segment,
                calibration: calibration
            )

            guard track.observations.count >= 2 else {
                throw VideoAnalysisError.trackTooShort(identifier: segment.identifier)
            }

            let metrics = metricEstimator.estimate(from: track)
            return ImportedShotAnalysisResult(
                segment: segment,
                calibration: calibration,
                track: track,
                metrics: metrics
            )
        }

        return ImportedVideoAnalysisResult(
            request: resolvedRequest,
            resolvedVideo: resolvedVideo,
            shots: shotResults,
            summary: summary(from: shotResults)
        )
    }

    private func validate(request: ImportedVideoAnalysisRequest) throws {
        guard request.frameSamplingFPS > 0 else {
            throw VideoAnalysisError.invalidSamplingFPS(request.frameSamplingFPS)
        }

        if let trimStartSeconds = request.trimStartSeconds, let trimEndSeconds = request.trimEndSeconds {
            guard trimStartSeconds < trimEndSeconds else {
                throw VideoAnalysisError.invalidTrimRange(start: trimStartSeconds, end: trimEndSeconds)
            }
        }

        for manualShotRange in request.manualShotRanges {
            guard manualShotRange.startTimeSeconds < manualShotRange.endTimeSeconds else {
                throw VideoAnalysisError.invalidManualShotRange(
                    identifier: manualShotRange.identifier,
                    start: manualShotRange.startTimeSeconds,
                    end: manualShotRange.endTimeSeconds
                )
            }
        }
    }

    private func summary(from shots: [ImportedShotAnalysisResult]) -> ImportedVideoAnalysisSummary {
        ImportedVideoAnalysisSummary(
            shotCount: shots.count,
            averageLaunchSpeedMph: average(of: shots.compactMap(\.metrics.launchSpeedMph)),
            averageImpactSpeedMph: average(of: shots.compactMap(\.metrics.impactSpeedMph)),
            averageHookBoards: average(of: shots.compactMap(\.metrics.hookBoards))
        )
    }

    private func average(of values: [Double]) -> Double? {
        guard !values.isEmpty else {
            return nil
        }

        let total = values.reduce(0.0, +)
        return total / Double(values.count)
    }
}
