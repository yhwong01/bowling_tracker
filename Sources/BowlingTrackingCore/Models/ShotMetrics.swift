import Foundation

public struct ShotMetrics: Sendable, Equatable, Codable {
    public var foulLineBoard: Double?
    public var arrowsBoard: Double?
    public var breakpointBoard: Double?
    public var breakpointDistanceFeet: Double?
    public var entryBoard: Double?
    public var launchAngleDegrees: Double?
    public var impactAngleDegrees: Double?
    public var launchSpeedMph: Double?
    public var averageSpeedMph: Double?
    public var impactSpeedMph: Double?
    public var hookBoards: Double?
    public var shotTimeSeconds: Double?
    public var confidenceFlags: [ConfidenceFlag]

    public init(
        foulLineBoard: Double? = nil,
        arrowsBoard: Double? = nil,
        breakpointBoard: Double? = nil,
        breakpointDistanceFeet: Double? = nil,
        entryBoard: Double? = nil,
        launchAngleDegrees: Double? = nil,
        impactAngleDegrees: Double? = nil,
        launchSpeedMph: Double? = nil,
        averageSpeedMph: Double? = nil,
        impactSpeedMph: Double? = nil,
        hookBoards: Double? = nil,
        shotTimeSeconds: Double? = nil,
        confidenceFlags: [ConfidenceFlag] = []
    ) {
        self.foulLineBoard = foulLineBoard
        self.arrowsBoard = arrowsBoard
        self.breakpointBoard = breakpointBoard
        self.breakpointDistanceFeet = breakpointDistanceFeet
        self.entryBoard = entryBoard
        self.launchAngleDegrees = launchAngleDegrees
        self.impactAngleDegrees = impactAngleDegrees
        self.launchSpeedMph = launchSpeedMph
        self.averageSpeedMph = averageSpeedMph
        self.impactSpeedMph = impactSpeedMph
        self.hookBoards = hookBoards
        self.shotTimeSeconds = shotTimeSeconds
        self.confidenceFlags = confidenceFlags
    }
}
