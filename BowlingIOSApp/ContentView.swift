import SwiftUI
import BowlingTrackingCore

struct ContentView: View {
    private let metrics = DemoShotFactory.sampleMetrics()

    var body: some View {
        NavigationStack {
            List {
                Section("Project") {
                    Text("Bowling tracking app shell")
                    Text("The iPhone app target is now wired to BowlingTrackingCore.")
                        .foregroundStyle(.secondary)
                }

                Section("Next Features") {
                    Label("Live tripod capture on iPhone", systemImage: "camera.viewfinder")
                    Label("Offline video upload on desktop", systemImage: "film.stack")
                    Label("Shared lane metric engine", systemImage: "chart.xyaxis.line")
                }

                Section("Sample Metrics") {
                    MetricRow(title: "Foul line board", value: metrics.foulLineBoard)
                    MetricRow(title: "Arrows board", value: metrics.arrowsBoard)
                    MetricRow(title: "Launch angle", value: metrics.launchAngleDegrees, suffix: "deg")
                    MetricRow(title: "Launch speed", value: metrics.launchSpeedMph, suffix: "mph")
                    MetricRow(title: "Breakpoint board", value: metrics.breakpointBoard)
                    MetricRow(title: "Entry board", value: metrics.entryBoard)
                    MetricRow(title: "Hook boards", value: metrics.hookBoards)
                }
            }
            .navigationTitle("Bowling App")
        }
    }
}

private struct MetricRow: View {
    let title: String
    let value: Double?
    var suffix: String = ""

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(formattedValue)
                .foregroundStyle(.secondary)
        }
    }

    private var formattedValue: String {
        guard let value else {
            return "N/A"
        }

        let number = String(format: "%.1f", value)
        return suffix.isEmpty ? number : "\(number) \(suffix)"
    }
}

private enum DemoShotFactory {
    static func sampleMetrics() -> ShotMetrics {
        let track = BallTrack(observations: [
            observation(time: 0.00, distance: 1.0, board: 24.5),
            observation(time: 0.20, distance: 15.0, board: 18.0),
            observation(time: 0.72, distance: 42.0, board: 8.5),
            observation(time: 1.08, distance: 60.0, board: 17.5)
        ])

        return ShotMetricEstimator().estimate(from: track)
    }

    private static func observation(time: TimeInterval, distance: Double, board: Double) -> BallObservation {
        BallObservation(
            timestamp: time,
            imageCenter: ImagePoint(x: 0, y: 0),
            laneCoordinate: LaneCoordinate(distanceFromFoulLineFeet: distance, board: board),
            radiusPixels: 22,
            confidence: 0.95
        )
    }
}

#Preview {
    ContentView()
}
