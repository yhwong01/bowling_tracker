import AVFoundation
import BowlingTrackingCore
import CoreGraphics
import Foundation
import ImageIO
import Vision

final class LaneVisionDetector {
    private let analysisOrientation = CGImagePropertyOrientation.right

    func detectLane(in sampleBuffer: CMSampleBuffer) -> DetectedLane? {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return nil
        }

        let request = VNDetectContoursRequest()
        request.contrastAdjustment = 1.35
        request.detectsDarkOnLight = true
        request.maximumImageDimension = 640

        let handler = VNImageRequestHandler(
            cmSampleBuffer: sampleBuffer,
            orientation: analysisOrientation,
            options: [:]
        )

        do {
            try handler.perform([request])
        } catch {
            return nil
        }

        guard let contours = request.results?.first as? VNContoursObservation else {
            return nil
        }

        let rawWidth = CVPixelBufferGetWidth(pixelBuffer)
        let rawHeight = CVPixelBufferGetHeight(pixelBuffer)
        let imageSize = orientedImageSize(width: rawWidth, height: rawHeight)
        return estimateLane(from: contours, imageSize: imageSize)
    }

    private func estimateLane(from observation: VNContoursObservation, imageSize: ImageSize) -> DetectedLane? {
        let polylines = collectPolylines(from: observation)
        var leftPoints: [CGPoint] = []
        var rightPoints: [CGPoint] = []
        var lineSegmentCount = 0

        for polyline in polylines {
            guard polyline.count > 1 else {
                continue
            }

            for index in 0..<(polyline.count - 1) {
                let first = polyline[index]
                let second = polyline[index + 1]
                let dx = second.x - first.x
                let dy = second.y - first.y

                guard abs(dx) > 0.006 else {
                    continue
                }

                let slope = dy / dx
                let length = sqrt(dx * dx + dy * dy)
                let midpoint = CGPoint(x: (first.x + second.x) / 2, y: (first.y + second.y) / 2)

                guard length >= 0.035,
                      abs(slope) >= 0.65,
                      midpoint.y >= 0.12,
                      midpoint.y <= 0.98,
                      isInsideLaneRegion(midpoint) else {
                    continue
                }

                if slope < 0, midpoint.x < 0.70 {
                    leftPoints.append(first)
                    leftPoints.append(second)
                    lineSegmentCount += 1
                } else if slope > 0, midpoint.x > 0.30 {
                    rightPoints.append(first)
                    rightPoints.append(second)
                    lineSegmentCount += 1
                }
            }
        }

        guard leftPoints.count >= 6,
              rightPoints.count >= 6,
              let leftFit = robustFitXFromY(leftPoints),
              let rightFit = robustFitXFromY(rightPoints) else {
            return nil
        }

        let topY = CGFloat(0.18)
        let bottomY = CGFloat(0.92)
        let leftBottom = leftFit.x(atY: bottomY)
        let leftTop = leftFit.x(atY: topY)
        let rightBottom = rightFit.x(atY: bottomY)
        let rightTop = rightFit.x(atY: topY)

        guard isValidLaneGeometry(
            leftBottom: leftBottom,
            rightBottom: rightBottom,
            leftTop: leftTop,
            rightTop: rightTop
        ) else {
            return nil
        }

        let confidence = confidenceScore(
            lineSegmentCount: lineSegmentCount,
            leftPoints: leftPoints,
            rightPoints: rightPoints,
            leftFit: leftFit,
            rightFit: rightFit,
            bottomWidth: rightBottom - leftBottom
        )

        return DetectedLane(
            imageSize: imageSize,
            corners: LaneCorners(
                foulLineLeft: imagePoint(x: leftBottom, y: bottomY, imageSize: imageSize),
                foulLineRight: imagePoint(x: rightBottom, y: bottomY, imageSize: imageSize),
                pinDeckLeft: imagePoint(x: leftTop, y: topY, imageSize: imageSize),
                pinDeckRight: imagePoint(x: rightTop, y: topY, imageSize: imageSize)
            ),
            confidence: confidence,
            detectedAt: Date()
        )
    }

    private func collectPolylines(from observation: VNContoursObservation) -> [[CGPoint]] {
        var polylines: [[CGPoint]] = []

        for index in 0..<observation.contourCount {
            guard let contour = try? observation.contour(at: index) else {
                continue
            }

            collect(contour, into: &polylines)
        }

        return polylines
    }

    private func collect(_ contour: VNContour, into polylines: inout [[CGPoint]]) {
        let points = contour.normalizedPoints.map { point in
            CGPoint(x: CGFloat(point.x), y: CGFloat(1 - point.y))
        }

        if points.count > 1 {
            polylines.append(points)
        }

        for index in 0..<contour.childContourCount {
            guard let child = try? contour.childContour(at: index) else {
                continue
            }

            collect(child, into: &polylines)
        }
    }

    private func isInsideLaneRegion(_ point: CGPoint) -> Bool {
        let topY = CGFloat(0.12)
        let bottomY = CGFloat(1.0)
        let progress = min(max((point.y - topY) / (bottomY - topY), 0), 1)
        let leftBound = interpolate(from: 0.30, to: 0.04, progress: progress)
        let rightBound = interpolate(from: 0.70, to: 0.96, progress: progress)
        return point.x >= leftBound && point.x <= rightBound
    }

    private func robustFitXFromY(_ points: [CGPoint]) -> LineFit? {
        guard points.count >= 4, let firstFit = fitXFromY(points) else {
            return nil
        }

        let residuals = points.map { abs($0.x - firstFit.x(atY: $0.y)) }
        let medianResidual = median(residuals)
        let threshold = max(CGFloat(0.025), medianResidual * 2.5)
        let filtered = points.filter { abs($0.x - firstFit.x(atY: $0.y)) <= threshold }

        guard filtered.count >= 4 else {
            return firstFit
        }

        return fitXFromY(filtered) ?? firstFit
    }

    private func fitXFromY(_ points: [CGPoint]) -> LineFit? {
        guard points.count >= 2 else {
            return nil
        }

        let count = CGFloat(points.count)
        let meanX = points.reduce(CGFloat.zero) { $0 + $1.x } / count
        let meanY = points.reduce(CGFloat.zero) { $0 + $1.y } / count
        let numerator = points.reduce(CGFloat.zero) { partial, point in
            partial + (point.y - meanY) * (point.x - meanX)
        }
        let denominator = points.reduce(CGFloat.zero) { partial, point in
            let centeredY = point.y - meanY
            return partial + centeredY * centeredY
        }

        guard abs(denominator) > 0.0001 else {
            return nil
        }

        let slope = numerator / denominator
        let intercept = meanX - slope * meanY
        return LineFit(slope: slope, intercept: intercept)
    }

    private func isValidLaneGeometry(
        leftBottom: CGFloat,
        rightBottom: CGFloat,
        leftTop: CGFloat,
        rightTop: CGFloat
    ) -> Bool {
        let bottomWidth = rightBottom - leftBottom
        let topWidth = rightTop - leftTop
        let bottomCenter = (leftBottom + rightBottom) / 2
        let topCenter = (leftTop + rightTop) / 2

        return leftBottom >= 0
            && rightBottom <= 1
            && leftTop >= 0
            && rightTop <= 1
            && leftBottom < rightBottom
            && leftTop < rightTop
            && bottomWidth >= 0.32
            && bottomWidth <= 0.96
            && topWidth >= 0.035
            && topWidth <= bottomWidth * 0.75
            && bottomCenter >= 0.22
            && bottomCenter <= 0.78
            && topCenter >= 0.25
            && topCenter <= 0.75
    }

    private func confidenceScore(
        lineSegmentCount: Int,
        leftPoints: [CGPoint],
        rightPoints: [CGPoint],
        leftFit: LineFit,
        rightFit: LineFit,
        bottomWidth: CGFloat
    ) -> Double {
        let leftError = median(leftPoints.map { abs($0.x - leftFit.x(atY: $0.y)) })
        let rightError = median(rightPoints.map { abs($0.x - rightFit.x(atY: $0.y)) })
        let residualScore = max(0, 1 - Double((leftError + rightError) / 2) / 0.08)
        let lineScore = min(1, Double(lineSegmentCount) / 24)
        let widthScore = min(1, max(0, Double(bottomWidth) / 0.65))

        return min(0.98, 0.25 + 0.35 * lineScore + 0.30 * residualScore + 0.10 * widthScore)
    }

    private func imagePoint(x: CGFloat, y: CGFloat, imageSize: ImageSize) -> ImagePoint {
        ImagePoint(
            x: Double(x) * imageSize.width,
            y: Double(y) * imageSize.height
        )
    }

    private func orientedImageSize(width: Int, height: Int) -> ImageSize {
        switch analysisOrientation {
        case .left, .right, .leftMirrored, .rightMirrored:
            return ImageSize(width: Double(height), height: Double(width))
        default:
            return ImageSize(width: Double(width), height: Double(height))
        }
    }

    private func interpolate(from start: CGFloat, to end: CGFloat, progress: CGFloat) -> CGFloat {
        start + (end - start) * progress
    }

    private func median(_ values: [CGFloat]) -> CGFloat {
        guard !values.isEmpty else {
            return 1
        }

        let sorted = values.sorted()
        let middle = sorted.count / 2

        if sorted.count.isMultiple(of: 2) {
            return (sorted[middle - 1] + sorted[middle]) / 2
        }

        return sorted[middle]
    }
}

private struct LineFit {
    var slope: CGFloat
    var intercept: CGFloat

    func x(atY y: CGFloat) -> CGFloat {
        slope * y + intercept
    }
}
