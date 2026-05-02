import BowlingTrackingCore
import CoreGraphics
import Foundation

struct DetectedLane: Equatable {
    var imageSize: ImageSize
    var corners: LaneCorners
    var confidence: Double
    var detectedAt: Date

    var polygonPoints: [ImagePoint] {
        [
            corners.foulLineLeft,
            corners.foulLineRight,
            corners.pinDeckRight,
            corners.pinDeckLeft
        ]
    }

    var boundingBox: CGRect {
        let points = polygonPoints
        let minX = points.map(\.x).min() ?? 0
        let maxX = points.map(\.x).max() ?? 0
        let minY = points.map(\.y).min() ?? 0
        let maxY = points.map(\.y).max() ?? 0

        return CGRect(
            x: CGFloat(minX),
            y: CGFloat(minY),
            width: CGFloat(max(0, maxX - minX)),
            height: CGFloat(max(0, maxY - minY))
        )
    }

    func blended(toward next: DetectedLane, weight: Double) -> DetectedLane {
        guard imageSize == next.imageSize else {
            return next
        }

        let clampedWeight = min(max(weight, 0), 1)
        let retainedWeight = 1 - clampedWeight

        return DetectedLane(
            imageSize: next.imageSize,
            corners: LaneCorners(
                foulLineLeft: blend(corners.foulLineLeft, next.corners.foulLineLeft, retainedWeight, clampedWeight),
                foulLineRight: blend(corners.foulLineRight, next.corners.foulLineRight, retainedWeight, clampedWeight),
                pinDeckLeft: blend(corners.pinDeckLeft, next.corners.pinDeckLeft, retainedWeight, clampedWeight),
                pinDeckRight: blend(corners.pinDeckRight, next.corners.pinDeckRight, retainedWeight, clampedWeight)
            ),
            confidence: next.confidence,
            detectedAt: next.detectedAt
        )
    }

    private func blend(_ current: ImagePoint, _ next: ImagePoint, _ retainedWeight: Double, _ nextWeight: Double) -> ImagePoint {
        ImagePoint(
            x: current.x * retainedWeight + next.x * nextWeight,
            y: current.y * retainedWeight + next.y * nextWeight
        )
    }
}
