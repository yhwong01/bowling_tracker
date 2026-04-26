import Foundation

public struct SpeedSample: Sendable, Equatable, Codable {
    public var timestamp: TimeInterval
    public var distanceFromFoulLineFeet: Double
    public var mph: Double

    public init(timestamp: TimeInterval, distanceFromFoulLineFeet: Double, mph: Double) {
        self.timestamp = timestamp
        self.distanceFromFoulLineFeet = distanceFromFoulLineFeet
        self.mph = mph
    }
}

public struct BallTrack: Sendable, Equatable, Codable {
    public let observations: [BallObservation]

    public init(observations: [BallObservation]) {
        self.observations = observations.sorted { $0.timestamp < $1.timestamp }
    }

    public var firstObservation: BallObservation? {
        observations.first
    }

    public var lastObservation: BallObservation? {
        observations.last
    }

    public var duration: TimeInterval? {
        guard
            let firstObservation,
            let lastObservation,
            observations.count > 1
        else {
            return nil
        }

        return max(0, lastObservation.timestamp - firstObservation.timestamp)
    }

    public func board(
        atDistanceFeet targetDistance: Double,
        allowExtrapolation: Bool = false
    ) -> Double? {
        guard observations.count >= 2 else {
            return observations.first?.laneCoordinate.board
        }

        let coordinates = observations.map(\.laneCoordinate)

        if let match = coordinates.first(where: { $0.distanceFromFoulLineFeet == targetDistance }) {
            return match.board
        }

        for index in 1..<coordinates.count {
            let previous = coordinates[index - 1]
            let current = coordinates[index]
            let spansTarget =
                (previous.distanceFromFoulLineFeet <= targetDistance && current.distanceFromFoulLineFeet >= targetDistance) ||
                (previous.distanceFromFoulLineFeet >= targetDistance && current.distanceFromFoulLineFeet <= targetDistance)

            if spansTarget {
                let denominator = current.distanceFromFoulLineFeet - previous.distanceFromFoulLineFeet
                guard denominator != 0 else {
                    return current.board
                }

                let progress = (targetDistance - previous.distanceFromFoulLineFeet) / denominator
                return previous.board + ((current.board - previous.board) * progress)
            }
        }

        guard allowExtrapolation else {
            return nil
        }

        if targetDistance < coordinates[0].distanceFromFoulLineFeet {
            return projectBoard(
                targetDistance: targetDistance,
                from: coordinates[0],
                to: coordinates[1]
            )
        }

        if let secondToLast = coordinates.dropLast().last, let last = coordinates.last {
            return projectBoard(
                targetDistance: targetDistance,
                from: secondToLast,
                to: last
            )
        }

        return nil
    }

    public func speedSamples(geometry: LaneGeometry) -> [SpeedSample] {
        guard observations.count >= 2 else {
            return []
        }

        return zip(observations, observations.dropFirst()).compactMap { pair in
            let (previous, current) = pair
            let deltaTime = current.timestamp - previous.timestamp
            guard deltaTime > 0 else {
                return nil
            }

            let distanceFeet = previous.laneCoordinate.planarDistance(
                to: current.laneCoordinate,
                geometry: geometry
            )
            let feetPerSecond = distanceFeet / deltaTime
            let mph = feetPerSecond * 0.681818

            return SpeedSample(
                timestamp: current.timestamp,
                distanceFromFoulLineFeet: current.laneCoordinate.distanceFromFoulLineFeet,
                mph: mph
            )
        }
    }

    public func totalTrackedDistance(geometry: LaneGeometry) -> Double {
        zip(observations, observations.dropFirst()).reduce(0.0) { partialResult, pair in
            let (previous, current) = pair
            return partialResult + previous.laneCoordinate.planarDistance(
                to: current.laneCoordinate,
                geometry: geometry
            )
        }
    }

    private func projectBoard(
        targetDistance: Double,
        from: LaneCoordinate,
        to: LaneCoordinate
    ) -> Double? {
        let denominator = to.distanceFromFoulLineFeet - from.distanceFromFoulLineFeet
        guard denominator != 0 else {
            return nil
        }

        let progress = (targetDistance - from.distanceFromFoulLineFeet) / denominator
        return from.board + ((to.board - from.board) * progress)
    }
}
