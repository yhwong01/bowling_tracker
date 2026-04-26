import Foundation
import XCTest
@testable import BowlingTrackingCore

final class ShotMetricEstimatorTests: XCTestCase {
    func testInterpolatesBoardsAtReferenceDistances() {
        let track = BallTrack(observations: [
            observation(time: 0.00, distance: 3.0, board: 24.0),
            observation(time: 0.30, distance: 15.0, board: 18.0),
            observation(time: 0.80, distance: 40.0, board: 8.0),
            observation(time: 1.20, distance: 60.0, board: 17.5)
        ])

        let metrics = ShotMetricEstimator().estimate(from: track)

        XCTAssertNotNil(metrics.arrowsBoard)
        XCTAssertNotNil(metrics.entryBoard)
        XCTAssertEqual(metrics.arrowsBoard ?? .zero, 18.0, accuracy: 0.001)
        XCTAssertEqual(metrics.entryBoard ?? .zero, 17.5, accuracy: 0.001)
    }

    func testComputesLaunchAngleAndHookBoards() {
        let track = BallTrack(observations: [
            observation(time: 0.00, distance: 1.0, board: 25.0),
            observation(time: 0.10, distance: 7.0, board: 23.0),
            observation(time: 0.40, distance: 30.0, board: 7.0),
            observation(time: 0.90, distance: 58.0, board: 17.0),
            observation(time: 1.00, distance: 60.0, board: 17.5)
        ])

        let metrics = ShotMetricEstimator().estimate(from: track)

        XCTAssertNotNil(metrics.launchAngleDegrees)
        XCTAssertNotNil(metrics.breakpointBoard)
        XCTAssertNotNil(metrics.hookBoards)
        XCTAssertEqual(metrics.breakpointBoard ?? .zero, 7.0, accuracy: 0.001)
        XCTAssertEqual(metrics.hookBoards ?? .zero, 10.5, accuracy: 0.001)
    }

    func testComputesAverageSpeedFromLanePath() {
        let track = BallTrack(observations: [
            observation(time: 0.00, distance: 0.0, board: 20.0),
            observation(time: 1.50, distance: 60.0, board: 20.0)
        ])

        let metrics = ShotMetricEstimator().estimate(from: track)

        XCTAssertNotNil(metrics.averageSpeedMph)
        XCTAssertGreaterThan(metrics.averageSpeedMph ?? 0, 27.0)
        XCTAssertLessThan(metrics.averageSpeedMph ?? 0, 27.5)
    }

    private func observation(
        time: TimeInterval,
        distance: Double,
        board: Double
    ) -> BallObservation {
        BallObservation(
            timestamp: time,
            imageCenter: ImagePoint(x: 0, y: 0),
            laneCoordinate: LaneCoordinate(distanceFromFoulLineFeet: distance, board: board),
            radiusPixels: 20,
            confidence: 0.95
        )
    }
}
