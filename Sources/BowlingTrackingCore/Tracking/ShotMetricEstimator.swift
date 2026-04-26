import Foundation

public struct ShotMetricEstimator: Sendable {
    public var geometry: LaneGeometry
    public var launchWindowFeet: Double
    public var impactWindowFeet: Double
    public var breakpointSearchStartFeet: Double
    public var minimumBreakpointOffsetBoards: Double

    public init(
        geometry: LaneGeometry = .regulation,
        launchWindowFeet: Double = 6.0,
        impactWindowFeet: Double = 6.0,
        breakpointSearchStartFeet: Double = 25.0,
        minimumBreakpointOffsetBoards: Double = 0.5
    ) {
        self.geometry = geometry
        self.launchWindowFeet = launchWindowFeet
        self.impactWindowFeet = impactWindowFeet
        self.breakpointSearchStartFeet = breakpointSearchStartFeet
        self.minimumBreakpointOffsetBoards = minimumBreakpointOffsetBoards
    }

    public func estimate(from track: BallTrack) -> ShotMetrics {
        let speeds = track.speedSamples(geometry: geometry)
        let foulLineBoard = track.board(atDistanceFeet: 0.0, allowExtrapolation: true)
        let arrowsBoard = track.board(atDistanceFeet: geometry.arrowDistanceFeet, allowExtrapolation: true)
        let entryBoard = estimateEntryBoard(from: track)
        let breakpoint = estimateBreakpoint(from: track, entryBoard: entryBoard)

        return ShotMetrics(
            foulLineBoard: foulLineBoard.map(geometry.clamp(board:)),
            arrowsBoard: arrowsBoard.map(geometry.clamp(board:)),
            breakpointBoard: breakpoint.map { geometry.clamp(board: $0.board) },
            breakpointDistanceFeet: breakpoint?.distanceFromFoulLineFeet,
            entryBoard: entryBoard.map(geometry.clamp(board:)),
            launchAngleDegrees: estimateLaunchAngle(from: track),
            impactAngleDegrees: estimateImpactAngle(from: track),
            launchSpeedMph: estimateLaunchSpeed(from: speeds),
            averageSpeedMph: estimateAverageSpeed(from: track),
            impactSpeedMph: estimateImpactSpeed(from: speeds),
            hookBoards: estimateHookBoards(entryBoard: entryBoard, breakpoint: breakpoint),
            shotTimeSeconds: track.duration
        )
    }

    private func estimateEntryBoard(from track: BallTrack) -> Double? {
        guard let lastObservation = track.lastObservation else {
            return nil
        }

        let needsLongEnoughTail = geometry.foulLineToHeadPinFeet - 8.0
        guard lastObservation.laneCoordinate.distanceFromFoulLineFeet >= needsLongEnoughTail else {
            return nil
        }

        return track.board(
            atDistanceFeet: geometry.foulLineToHeadPinFeet,
            allowExtrapolation: true
        )
    }

    private func estimateLaunchAngle(from track: BallTrack) -> Double? {
        guard let start = track.firstObservation?.laneCoordinate else {
            return nil
        }

        let targetDistance = start.distanceFromFoulLineFeet + launchWindowFeet
        guard let target = coordinate(in: track, nearestTo: targetDistance) else {
            return nil
        }

        return angleDegrees(from: start, to: target)
    }

    private func estimateImpactAngle(from track: BallTrack) -> Double? {
        guard let end = track.lastObservation?.laneCoordinate else {
            return nil
        }

        let targetDistance = end.distanceFromFoulLineFeet - impactWindowFeet
        guard let start = coordinate(in: track, nearestTo: targetDistance) else {
            return nil
        }

        return angleDegrees(from: start, to: end)
    }

    private func estimateLaunchSpeed(from samples: [SpeedSample]) -> Double? {
        let earlySamples = samples.filter { $0.distanceFromFoulLineFeet <= geometry.arrowDistanceFeet }
        return earlySamples.map(\.mph).max() ?? samples.first?.mph
    }

    private func estimateAverageSpeed(from track: BallTrack) -> Double? {
        guard
            let duration = track.duration,
            duration > 0
        else {
            return nil
        }

        let traveledFeet = track.totalTrackedDistance(geometry: geometry)
        guard traveledFeet > 0 else {
            return nil
        }

        return (traveledFeet / duration) * 0.681818
    }

    private func estimateImpactSpeed(from samples: [SpeedSample]) -> Double? {
        guard let furthestSample = samples.max(by: { $0.distanceFromFoulLineFeet < $1.distanceFromFoulLineFeet }) else {
            return nil
        }

        let lowerBound = furthestSample.distanceFromFoulLineFeet - impactWindowFeet
        let endingSamples = samples.filter { $0.distanceFromFoulLineFeet >= lowerBound }
        guard !endingSamples.isEmpty else {
            return furthestSample.mph
        }

        let total = endingSamples.reduce(0.0) { $0 + $1.mph }
        return total / Double(endingSamples.count)
    }

    private func estimateBreakpoint(from track: BallTrack, entryBoard: Double?) -> LaneCoordinate? {
        guard
            let start = track.firstObservation?.laneCoordinate,
            let endBoard = entryBoard ?? track.lastObservation?.laneCoordinate.board,
            let endDistance = track.lastObservation?.laneCoordinate.distanceFromFoulLineFeet
        else {
            return nil
        }

        let end = LaneCoordinate(distanceFromFoulLineFeet: endDistance, board: endBoard)
        let candidates = track.observations
            .map(\.laneCoordinate)
            .filter {
                $0.distanceFromFoulLineFeet >= breakpointSearchStartFeet &&
                $0.distanceFromFoulLineFeet <= end.distanceFromFoulLineFeet
            }

        guard !candidates.isEmpty else {
            return nil
        }

        let maxCandidate = candidates.max { lhs, rhs in
            lateralOffset(for: lhs, start: start, end: end) < lateralOffset(for: rhs, start: start, end: end)
        }

        guard
            let breakpoint = maxCandidate,
            lateralOffset(for: breakpoint, start: start, end: end) >= minimumBreakpointOffsetBoards
        else {
            return nil
        }

        return breakpoint
    }

    private func estimateHookBoards(entryBoard: Double?, breakpoint: LaneCoordinate?) -> Double? {
        guard let entryBoard, let breakpoint else {
            return nil
        }

        return abs(entryBoard - breakpoint.board)
    }

    private func coordinate(in track: BallTrack, nearestTo distance: Double) -> LaneCoordinate? {
        track.observations
            .map(\.laneCoordinate)
            .min { lhs, rhs in
                abs(lhs.distanceFromFoulLineFeet - distance) < abs(rhs.distanceFromFoulLineFeet - distance)
            }
    }

    private func angleDegrees(from start: LaneCoordinate, to end: LaneCoordinate) -> Double? {
        let longitudinalFeet = end.distanceFromFoulLineFeet - start.distanceFromFoulLineFeet
        guard longitudinalFeet != 0 else {
            return nil
        }

        let lateralFeet = (end.board - start.board) * geometry.feetPerBoard
        return atan2(lateralFeet, longitudinalFeet) * 180.0 / .pi
    }

    private func lateralOffset(for point: LaneCoordinate, start: LaneCoordinate, end: LaneCoordinate) -> Double {
        let denominator = end.distanceFromFoulLineFeet - start.distanceFromFoulLineFeet
        guard denominator != 0 else {
            return 0
        }

        let progress = (point.distanceFromFoulLineFeet - start.distanceFromFoulLineFeet) / denominator
        let expectedBoard = start.board + ((end.board - start.board) * progress)
        return abs(point.board - expectedBoard)
    }
}
