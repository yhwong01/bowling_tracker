import BowlingTrackingCore
import SwiftUI

struct LiveSessionView: View {
    @StateObject private var camera = CameraSessionController()

    var body: some View {
        Group {
            if camera.calibration == nil {
                LiveLaneCaptureView(camera: camera)
            } else {
                LiveShotTrackingView(camera: camera)
            }
        }
        .task {
            camera.start()
        }
        .onDisappear {
            camera.stop()
        }
    }
}

private struct LiveShotTrackingView: View {
    @ObservedObject var camera: CameraSessionController

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            CameraPreviewView(session: camera.session)
                .ignoresSafeArea()

            LaneDetectionOverlay(lane: camera.detectedLane)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header

                Spacer()

                metricsPanel
                    .padding(.horizontal)
                    .padding(.bottom, 12)

                historyPanel
                    .padding(.horizontal)
                    .padding(.bottom, 24)
            }
        }
        .navigationTitle("Live Session")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        HStack {
            Label(camera.isRunning ? "Tracking" : "Starting", systemImage: "camera.viewfinder")
                .font(.callout.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.black.opacity(0.42), in: Capsule())

            Spacer()

            Button("End Session") {
                camera.resetSession()
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }

    private var metricsPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(camera.statusText)
                .font(.headline)
                .foregroundStyle(.white)

            if let metrics = camera.currentMetrics {
                MetricRow(title: "Launch speed", value: metrics.launchSpeedMph, suffix: "mph")
                MetricRow(title: "Average speed", value: metrics.averageSpeedMph, suffix: "mph")
                MetricRow(title: "Launch angle", value: metrics.launchAngleDegrees, suffix: "deg")
                MetricRow(title: "Breakpoint board", value: metrics.breakpointBoard)
                MetricRow(title: "Entry board", value: metrics.entryBoard)
            } else {
                Text("Waiting for a tracked shot...")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .padding(16)
        .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.white.opacity(0.12))
        }
    }

    private var historyPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Shot History")
                .font(.headline)
                .foregroundStyle(.white)

            if camera.shotHistory.isEmpty {
                Text("No shots saved yet.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
            } else {
                ForEach(Array(camera.shotHistory.enumerated()), id: \.element.id) { index, shot in
                    ShotRow(index: index + 1, shot: shot)
                }
            }
        }
        .padding(16)
        .background(.black.opacity(0.5), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.white.opacity(0.1))
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
                .foregroundStyle(.white.opacity(0.8))
        }
        .font(.callout)
    }

    private var formattedValue: String {
        guard let value else {
            return "N/A"
        }

        let number = String(format: "%.1f", value)
        return suffix.isEmpty ? number : "\(number) \(suffix)"
    }
}

private struct ShotRow: View {
    let index: Int
    let shot: ShotRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Shot \(index)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)

            HStack(spacing: 12) {
                MetricPill(label: "Speed", value: shot.metrics.launchSpeedMph, suffix: "mph")
                MetricPill(label: "Entry", value: shot.metrics.entryBoard)
                MetricPill(label: "Hook", value: shot.metrics.hookBoards)
            }

            if !shot.metrics.confidenceFlags.isEmpty {
                Text("Flags: \(shot.metrics.confidenceFlags.map(\.code).joined(separator: ", "))")
                    .font(.caption2)
                    .foregroundStyle(.yellow.opacity(0.9))
            }
        }
        .padding(10)
        .background(.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct MetricPill: View {
    let label: String
    let value: Double?
    var suffix: String = ""

    var body: some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.caption2.weight(.bold))
            Text(formattedValue)
                .font(.caption2.monospacedDigit())
        }
        .foregroundStyle(.white.opacity(0.85))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.white.opacity(0.1), in: Capsule())
    }

    private var formattedValue: String {
        guard let value else {
            return "N/A"
        }

        let number = String(format: "%.1f", value)
        return suffix.isEmpty ? number : "\(number) \(suffix)"
    }
}

#Preview {
    LiveSessionView()
}
