import Foundation

public struct LaneCoordinate: Sendable, Equatable, Codable {
    public var distanceFromFoulLineFeet: Double
    public var board: Double

    public init(distanceFromFoulLineFeet: Double, board: Double) {
        self.distanceFromFoulLineFeet = distanceFromFoulLineFeet
        self.board = board
    }

    public func planarDistance(to other: LaneCoordinate, geometry: LaneGeometry) -> Double {
        let longitudinalFeet = other.distanceFromFoulLineFeet - distanceFromFoulLineFeet
        let lateralFeet = (other.board - board) * geometry.feetPerBoard
        return hypot(longitudinalFeet, lateralFeet)
    }
}
