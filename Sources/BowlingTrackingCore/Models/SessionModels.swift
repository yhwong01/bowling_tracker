import Foundation

public struct ConfidenceFlag: Sendable, Equatable, Codable {
    public var code: String
    public var message: String?

    public init(code: String, message: String? = nil) {
        self.code = code
        self.message = message
    }
}

public struct SessionContext: Sendable, Equatable, Codable {
    public var id: UUID
    public var startedAt: Date
    public var title: String?
    public var laneName: String?
    public var notes: String?
    public var dominantHand: BowlingHand

    public init(
        id: UUID = UUID(),
        startedAt: Date = Date(),
        title: String? = nil,
        laneName: String? = nil,
        notes: String? = nil,
        dominantHand: BowlingHand
    ) {
        self.id = id
        self.startedAt = startedAt
        self.title = title
        self.laneName = laneName
        self.notes = notes
        self.dominantHand = dominantHand
    }
}

public struct DeviceCaptureMetadata: Sendable, Equatable, Codable {
    public var deviceModel: String
    public var systemName: String
    public var systemVersion: String
    public var appVersion: String
    public var captureFps: Double
    public var captureResolution: ImageSize

    public init(
        deviceModel: String,
        systemName: String,
        systemVersion: String,
        appVersion: String,
        captureFps: Double,
        captureResolution: ImageSize
    ) {
        self.deviceModel = deviceModel
        self.systemName = systemName
        self.systemVersion = systemVersion
        self.appVersion = appVersion
        self.captureFps = captureFps
        self.captureResolution = captureResolution
    }
}

public struct ShotRecord: Sendable, Equatable, Codable {
    public var id: UUID
    public var startedAt: Date
    public var endedAt: Date
    public var calibration: LaneCalibration
    public var track: BallTrack
    public var metrics: ShotMetrics
    public var warnings: [String]

    public init(
        id: UUID = UUID(),
        startedAt: Date,
        endedAt: Date,
        calibration: LaneCalibration,
        track: BallTrack,
        metrics: ShotMetrics,
        warnings: [String] = []
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.calibration = calibration
        self.track = track
        self.metrics = metrics
        self.warnings = warnings
    }
}

public struct SessionRecord: Sendable, Equatable, Codable {
    public var id: UUID
    public var context: SessionContext
    public var deviceMetadata: DeviceCaptureMetadata
    public var calibration: LaneCalibration
    public var shots: [ShotRecord]
    public var endedAt: Date?

    public init(
        id: UUID = UUID(),
        context: SessionContext,
        deviceMetadata: DeviceCaptureMetadata,
        calibration: LaneCalibration,
        shots: [ShotRecord] = [],
        endedAt: Date? = nil
    ) {
        self.id = id
        self.context = context
        self.deviceMetadata = deviceMetadata
        self.calibration = calibration
        self.shots = shots
        self.endedAt = endedAt
    }
}
