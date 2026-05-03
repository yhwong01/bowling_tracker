import Foundation

public struct LaneProjection: Sendable {
    private let homography: Homography
    private let geometry: LaneGeometry

    public init?(calibration: LaneCalibration) {
        let boardCount = Double(calibration.geometry.boardCount)
        let lanePoints = [
            LanePlanePoint(distanceFeet: 0.0, board: 1.0),
            LanePlanePoint(distanceFeet: 0.0, board: boardCount),
            LanePlanePoint(distanceFeet: calibration.geometry.foulLineToHeadPinFeet, board: 1.0),
            LanePlanePoint(distanceFeet: calibration.geometry.foulLineToHeadPinFeet, board: boardCount)
        ]

        let imagePoints = [
            calibration.laneCorners.foulLineLeft,
            calibration.laneCorners.foulLineRight,
            calibration.laneCorners.pinDeckLeft,
            calibration.laneCorners.pinDeckRight
        ]

        guard let homography = Homography(imagePoints: imagePoints, lanePoints: lanePoints) else {
            return nil
        }

        self.homography = homography
        self.geometry = calibration.geometry
    }

    public func laneCoordinate(for imagePoint: ImagePoint) -> LaneCoordinate? {
        guard let projected = homography.project(imagePoint) else {
            return nil
        }

        return LaneCoordinate(
            distanceFromFoulLineFeet: projected.distanceFeet,
            board: geometry.clamp(board: projected.board)
        )
    }
}

private struct LanePlanePoint: Sendable {
    var distanceFeet: Double
    var board: Double
}

private struct Homography: Sendable {
    private let m: [Double]

    init?(imagePoints: [ImagePoint], lanePoints: [LanePlanePoint]) {
        guard imagePoints.count == 4, lanePoints.count == 4 else {
            return nil
        }

        var matrix: [[Double]] = []
        var vector: [Double] = []

        for (image, lane) in zip(imagePoints, lanePoints) {
            let x = image.x
            let y = image.y
            let X = lane.distanceFeet
            let Y = lane.board

            matrix.append([x, y, 1.0, 0.0, 0.0, 0.0, -X * x, -X * y])
            vector.append(X)

            matrix.append([0.0, 0.0, 0.0, x, y, 1.0, -Y * x, -Y * y])
            vector.append(Y)
        }

        guard let solution = solveLinearSystem(matrix, vector) else {
            return nil
        }

        let h11 = solution[0]
        let h12 = solution[1]
        let h13 = solution[2]
        let h21 = solution[3]
        let h22 = solution[4]
        let h23 = solution[5]
        let h31 = solution[6]
        let h32 = solution[7]

        self.m = [
            h11, h12, h13,
            h21, h22, h23,
            h31, h32, 1.0
        ]
    }

    func project(_ point: ImagePoint) -> LanePlanePoint? {
        let x = point.x
        let y = point.y
        let denominator = m[6] * x + m[7] * y + m[8]

        guard abs(denominator) > 1e-9 else {
            return nil
        }

        let distance = (m[0] * x + m[1] * y + m[2]) / denominator
        let board = (m[3] * x + m[4] * y + m[5]) / denominator

        return LanePlanePoint(distanceFeet: distance, board: board)
    }
}

private func solveLinearSystem(_ matrix: [[Double]], _ vector: [Double]) -> [Double]? {
    let n = vector.count
    guard matrix.count == n, matrix.allSatisfy({ $0.count == n }) else {
        return nil
    }

    var a = matrix
    var b = vector

    for pivot in 0..<n {
        var maxRow = pivot
        var maxValue = abs(a[pivot][pivot])

        for row in (pivot + 1)..<n {
            let value = abs(a[row][pivot])
            if value > maxValue {
                maxValue = value
                maxRow = row
            }
        }

        guard maxValue > 1e-10 else {
            return nil
        }

        if maxRow != pivot {
            a.swapAt(pivot, maxRow)
            b.swapAt(pivot, maxRow)
        }

        let divisor = a[pivot][pivot]
        for column in pivot..<n {
            a[pivot][column] /= divisor
        }
        b[pivot] /= divisor

        for row in 0..<n where row != pivot {
            let factor = a[row][pivot]
            if factor == 0 {
                continue
            }

            for column in pivot..<n {
                a[row][column] -= factor * a[pivot][column]
            }
            b[row] -= factor * b[pivot]
        }
    }

    return b
}
