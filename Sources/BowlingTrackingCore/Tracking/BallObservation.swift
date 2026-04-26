import Foundation

public struct BallObservation: Sendable, Equatable, Codable {
    public var timestamp: TimeInterval
    public var imageCenter: ImagePoint
    public var laneCoordinate: LaneCoordinate
    public var radiusPixels: Double
    public var confidence: Double

    public init(
        timestamp: TimeInterval,
        imageCenter: ImagePoint,
        laneCoordinate: LaneCoordinate,
        radiusPixels: Double,
        confidence: Double
    ) {
        self.timestamp = timestamp
        self.imageCenter = imageCenter
        self.laneCoordinate = laneCoordinate
        self.radiusPixels = radiusPixels
        self.confidence = confidence
    }
}
