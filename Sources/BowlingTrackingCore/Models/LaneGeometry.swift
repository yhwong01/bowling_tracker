import Foundation

public struct LaneGeometry: Sendable, Equatable, Codable {
    public let boardCount: Int
    public let laneWidthInches: Double
    public let foulLineToHeadPinFeet: Double
    public let arrowDistanceFeet: Double
    public let pinDeckDepthFeet: Double

    public init(
        boardCount: Int,
        laneWidthInches: Double,
        foulLineToHeadPinFeet: Double,
        arrowDistanceFeet: Double,
        pinDeckDepthFeet: Double
    ) {
        self.boardCount = boardCount
        self.laneWidthInches = laneWidthInches
        self.foulLineToHeadPinFeet = foulLineToHeadPinFeet
        self.arrowDistanceFeet = arrowDistanceFeet
        self.pinDeckDepthFeet = pinDeckDepthFeet
    }

    public static let regulation = LaneGeometry(
        boardCount: 39,
        laneWidthInches: 41.5,
        foulLineToHeadPinFeet: 60.0,
        arrowDistanceFeet: 15.0,
        pinDeckDepthFeet: 2.83
    )

    public var inchesPerBoard: Double {
        laneWidthInches / Double(boardCount)
    }

    public var feetPerBoard: Double {
        inchesPerBoard / 12.0
    }

    public func clamp(board: Double) -> Double {
        min(max(board, 1.0), Double(boardCount))
    }
}
