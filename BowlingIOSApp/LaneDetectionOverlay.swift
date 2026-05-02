import BowlingTrackingCore
import SwiftUI

struct LaneDetectionOverlay: View {
    let lane: DetectedLane?

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                if let lane {
                    let polygon = displayPolygon(for: lane, in: proxy.size)
                    let boundingBox = displayBoundingBox(for: lane, in: proxy.size)

                    polygonPath(points: polygon)
                        .fill(.mint.opacity(0.16))

                    polygonPath(points: polygon)
                        .stroke(.mint, style: StrokeStyle(lineWidth: 3, lineJoin: .round))
                        .shadow(color: .black.opacity(0.55), radius: 4, y: 2)

                    Path(boundingBox)
                        .stroke(.yellow, style: StrokeStyle(lineWidth: 2, dash: [7, 5]))
                        .shadow(color: .black.opacity(0.45), radius: 3, y: 1)

                    ForEach(Array(cornerLabels(for: lane, in: proxy.size).enumerated()), id: \.offset) { _, label in
                        Text(label.text)
                            .font(.caption2.monospacedDigit().weight(.semibold))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(.yellow.opacity(0.92), in: Capsule())
                            .position(label.position)
                    }
                } else {
                    scanningGuide(in: proxy.size)
                }
            }
            .animation(.easeOut(duration: 0.18), value: lane)
        }
    }

    private func scanningGuide(in size: CGSize) -> some View {
        let guide = [
            CGPoint(x: size.width * 0.16, y: size.height * 0.92),
            CGPoint(x: size.width * 0.84, y: size.height * 0.92),
            CGPoint(x: size.width * 0.58, y: size.height * 0.18),
            CGPoint(x: size.width * 0.42, y: size.height * 0.18)
        ]

        return polygonPath(points: guide)
            .stroke(.white.opacity(0.55), style: StrokeStyle(lineWidth: 2, dash: [9, 7]))
            .overlay {
                Text("Align the lane inside this guide")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.black.opacity(0.45), in: Capsule())
                    .position(x: size.width / 2, y: size.height * 0.14)
            }
    }

    private func polygonPath(points: [CGPoint]) -> Path {
        Path { path in
            guard let first = points.first else {
                return
            }

            path.move(to: first)
            for point in points.dropFirst() {
                path.addLine(to: point)
            }
            path.closeSubpath()
        }
    }

    private func displayPolygon(for lane: DetectedLane, in size: CGSize) -> [CGPoint] {
        lane.polygonPoints.map {
            displayPoint(for: $0, imageSize: lane.imageSize, viewSize: size)
        }
    }

    private func displayBoundingBox(for lane: DetectedLane, in size: CGSize) -> CGRect {
        let origin = displayPoint(
            for: ImagePoint(x: Double(lane.boundingBox.minX), y: Double(lane.boundingBox.minY)),
            imageSize: lane.imageSize,
            viewSize: size
        )
        let end = displayPoint(
            for: ImagePoint(x: Double(lane.boundingBox.maxX), y: Double(lane.boundingBox.maxY)),
            imageSize: lane.imageSize,
            viewSize: size
        )

        return CGRect(
            x: min(origin.x, end.x),
            y: min(origin.y, end.y),
            width: abs(end.x - origin.x),
            height: abs(end.y - origin.y)
        )
    }

    private func cornerLabels(for lane: DetectedLane, in size: CGSize) -> [(text: String, position: CGPoint)] {
        let rows: [(String, ImagePoint)] = [
            ("FL", lane.corners.foulLineLeft),
            ("FR", lane.corners.foulLineRight),
            ("PR", lane.corners.pinDeckRight),
            ("PL", lane.corners.pinDeckLeft)
        ]

        return rows.map { label, point in
            let displayPoint = displayPoint(for: point, imageSize: lane.imageSize, viewSize: size)
            return (
                "\(label) \(Int(point.x)),\(Int(point.y))",
                CGPoint(x: displayPoint.x, y: displayPoint.y - 16)
            )
        }
    }

    private func displayPoint(for point: ImagePoint, imageSize: ImageSize, viewSize: CGSize) -> CGPoint {
        let imageWidth = CGFloat(imageSize.width)
        let imageHeight = CGFloat(imageSize.height)

        guard imageWidth > 0, imageHeight > 0 else {
            return .zero
        }

        let scale = max(viewSize.width / imageWidth, viewSize.height / imageHeight)
        let renderedWidth = imageWidth * scale
        let renderedHeight = imageHeight * scale
        let xOffset = (viewSize.width - renderedWidth) / 2
        let yOffset = (viewSize.height - renderedHeight) / 2

        return CGPoint(
            x: CGFloat(point.x) * scale + xOffset,
            y: CGFloat(point.y) * scale + yOffset
        )
    }
}
