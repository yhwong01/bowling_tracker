import Foundation

public enum BowlingHand: String, Sendable, Equatable, Codable {
    case left
    case right
}

public struct LaneCorners: Sendable, Equatable, Codable {
    public var foulLineLeft: ImagePoint
    public var foulLineRight: ImagePoint
    public var pinDeckLeft: ImagePoint
    public var pinDeckRight: ImagePoint

    public init(
        foulLineLeft: ImagePoint,
        foulLineRight: ImagePoint,
        pinDeckLeft: ImagePoint,
        pinDeckRight: ImagePoint
    ) {
        self.foulLineLeft = foulLineLeft
        self.foulLineRight = foulLineRight
        self.pinDeckLeft = pinDeckLeft
        self.pinDeckRight = pinDeckRight
    }
}

public struct LaneCalibration: Sendable, Equatable, Codable {
    public var imageSize: ImageSize
    public var laneCorners: LaneCorners
    public var dominantHand: BowlingHand
    public var geometry: LaneGeometry
    public var confidence: Double

    public init(
        imageSize: ImageSize,
        laneCorners: LaneCorners,
        dominantHand: BowlingHand,
        geometry: LaneGeometry = .regulation,
        confidence: Double
    ) {
        self.imageSize = imageSize
        self.laneCorners = laneCorners
        self.dominantHand = dominantHand
        self.geometry = geometry
        self.confidence = confidence
    }
}
