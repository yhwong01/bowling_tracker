import AVFoundation
import BowlingTrackingCore
import CoreGraphics
import ImageIO
import Vision

final class BallVisionDetector {
    private let analysisOrientation = CGImagePropertyOrientation.right
    private let request: VNDetectContoursRequest

    init() {
        let request = VNDetectContoursRequest()
        request.contrastAdjustment = 1.15
        request.detectsDarkOnLight = true
        request.maximumImageDimension = 640
        self.request = request
    }

    func detectBall(in sampleBuffer: CMSampleBuffer, calibration: LaneCalibration) -> BallDetectionCandidate? {
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

        let imageSize = calibration.imageSize
        let laneBounds = normalizedLaneBounds(from: calibration.laneCorners, imageSize: imageSize)
        var bestCandidate: BallDetectionCandidate?
        var bestScore = 0.0

        for contour in collectContours(from: contours) {
            let points = contour.normalizedPoints.map { point in
                CGPoint(x: CGFloat(point.x), y: CGFloat(1 - point.y))
            }

            guard points.count >= 6 else {
                continue
            }

            let bounds = boundingBox(for: points)
            guard bounds.width > 0, bounds.height > 0 else {
                continue
            }

            let center = CGPoint(x: bounds.midX, y: bounds.midY)
            guard laneBounds.contains(center) else {
                continue
            }

            let area = polygonArea(points)
            let perimeter = polygonPerimeter(points)
            guard area > 0, perimeter > 0 else {
                continue
            }

            let circularity = (4.0 * Double.pi * area) / (perimeter * perimeter)
            guard circularity >= 0.65 else {
                continue
            }

            let areaScore = min(1.0, area / 0.002)
            let score = circularity * areaScore
            guard score > bestScore else {
                continue
            }

            let areaPixels = area * imageSize.width * imageSize.height
            let radiusPixels = sqrt(max(areaPixels, 0.0) / Double.pi)
            let imageCenter = ImagePoint(x: Double(center.x) * imageSize.width, y: Double(center.y) * imageSize.height)

            bestScore = score
            bestCandidate = BallDetectionCandidate(
                center: imageCenter,
                radiusPixels: radiusPixels,
                confidence: min(0.98, max(0.1, score))
            )
        }

        return bestCandidate
    }

    private func collectContours(from observation: VNContoursObservation) -> [VNContour] {
        var contours: [VNContour] = []
        for index in 0..<observation.contourCount {
            guard let contour = try? observation.contour(at: index) else {
                continue
            }
            collect(contour, into: &contours)
        }
        return contours
    }

    private func collect(_ contour: VNContour, into output: inout [VNContour]) {
        output.append(contour)
        for index in 0..<contour.childContourCount {
            guard let child = try? contour.childContour(at: index) else {
                continue
            }
            collect(child, into: &output)
        }
    }

    private func normalizedLaneBounds(from corners: LaneCorners, imageSize: ImageSize) -> CGRect {
        let points = [
            corners.foulLineLeft,
            corners.foulLineRight,
            corners.pinDeckLeft,
            corners.pinDeckRight
        ]

        let xs = points.map { CGFloat($0.x / imageSize.width) }
        let ys = points.map { CGFloat($0.y / imageSize.height) }

        let minX = max(0.0, (xs.min() ?? 0) - 0.03)
        let maxX = min(1.0, (xs.max() ?? 1) + 0.03)
        let minY = max(0.0, (ys.min() ?? 0) - 0.03)
        let maxY = min(1.0, (ys.max() ?? 1) + 0.03)

        return CGRect(x: minX, y: minY, width: max(0, maxX - minX), height: max(0, maxY - minY))
    }

    private func boundingBox(for points: [CGPoint]) -> CGRect {
        let xs = points.map(\.x)
        let ys = points.map(\.y)

        guard let minX = xs.min(), let maxX = xs.max(), let minY = ys.min(), let maxY = ys.max() else {
            return .zero
        }

        return CGRect(x: minX, y: minY, width: max(0, maxX - minX), height: max(0, maxY - minY))
    }

    private func polygonArea(_ points: [CGPoint]) -> Double {
        guard points.count >= 3 else {
            return 0
        }

        var total: Double = 0
        for index in 0..<points.count {
            let next = (index + 1) % points.count
            total += Double(points[index].x * points[next].y - points[next].x * points[index].y)
        }

        return abs(total) * 0.5
    }

    private func polygonPerimeter(_ points: [CGPoint]) -> Double {
        guard points.count >= 2 else {
            return 0
        }

        var total: Double = 0
        for index in 0..<points.count {
            let next = (index + 1) % points.count
            let dx = Double(points[index].x - points[next].x)
            let dy = Double(points[index].y - points[next].y)
            total += sqrt(dx * dx + dy * dy)
        }

        return total
    }
}
