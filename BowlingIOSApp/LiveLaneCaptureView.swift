import BowlingTrackingCore
import SwiftUI
import UIKit

struct LiveLaneCaptureView: View {
    @ObservedObject var camera: CameraSessionController

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            switch camera.permissionState {
            case .authorized:
                CameraPreviewView(session: camera.session)
                    .ignoresSafeArea()

                LaneDetectionOverlay(lane: camera.detectedLane)
                    .ignoresSafeArea()

                captureHUD
            case .notDetermined:
                permissionMessage(
                    title: "Camera permission needed",
                    message: "The app uses the back camera to find the bowling lane in real time."
                )
            case .denied:
                permissionMessage(
                    title: "Camera access is off",
                    message: "Enable camera access in Settings so the app can detect lane coordinates.",
                    showsSettingsButton: true
                )
            case .restricted:
                permissionMessage(
                    title: "Camera restricted",
                    message: "This device does not currently allow camera capture."
                )
            case .unavailable:
                permissionMessage(
                    title: "Camera unavailable",
                    message: camera.statusText
                )
            }
        }
        .navigationTitle("Lane Alignment")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var captureHUD: some View {
        VStack(spacing: 0) {
            HStack {
                Label(camera.isRunning ? "Live camera" : "Starting camera", systemImage: "camera.viewfinder")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.black.opacity(0.42), in: Capsule())

                Spacer()
            }
            .padding()

            Spacer()

            coordinatePanel
                .padding()

            confirmationPanel
                .padding(.horizontal)
                .padding(.bottom, 24)
        }
    }

    private var confirmationPanel: some View {
        VStack(spacing: 12) {
            Picker("Dominant hand", selection: $camera.dominantHand) {
                Text("Right").tag(BowlingTrackingCore.BowlingHand.right)
                Text("Left").tag(BowlingTrackingCore.BowlingHand.left)
            }
            .pickerStyle(.segmented)

            Button("Confirm Lane") {
                camera.confirmLane()
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canConfirmLane)

            if !canConfirmLane {
                Text("Hold the phone still until the lane overlay is stable.")
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

    private var canConfirmLane: Bool {
        guard let lane = camera.detectedLane else {
            return false
        }

        return lane.confidence >= 0.55
    }

    private var coordinatePanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(camera.statusText)
                .font(.headline)
                .foregroundStyle(.white)

            if let lane = camera.detectedLane {
                Text("Image \(Int(lane.imageSize.width)) x \(Int(lane.imageSize.height)) px · Rectangle \(format(rect: lane.boundingBox))")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.75))

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 8) {
                    coordinateRow("Foul L", lane.corners.foulLineLeft)
                    coordinateRow("Foul R", lane.corners.foulLineRight)
                    coordinateRow("Pins L", lane.corners.pinDeckLeft)
                    coordinateRow("Pins R", lane.corners.pinDeckRight)
                }
            } else {
                Text("Waiting for two stable lane edges. Keep the phone still and aim from behind the bowler toward the pins.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.72))
            }
        }
        .padding(16)
        .background(.black.opacity(0.56), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(.white.opacity(0.14))
        }
    }

    private func coordinateRow(_ label: String, _ point: BowlingTrackingCore.ImagePoint) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white.opacity(0.58))

            Text("\(Int(point.x)), \(Int(point.y))")
                .font(.callout.monospacedDigit().weight(.semibold))
                .foregroundStyle(.white)
        }
    }

    private func permissionMessage(
        title: String,
        message: String,
        showsSettingsButton: Bool = false
    ) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 52, weight: .semibold))
                .foregroundStyle(.mint)

            Text(title)
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)

            Text(message)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.72))

            if showsSettingsButton {
                Button("Open Settings") {
                    guard let url = URL(string: UIApplication.openSettingsURLString) else {
                        return
                    }

                    UIApplication.shared.open(url)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(28)
    }

    private func format(rect: CGRect) -> String {
        "x \(Int(rect.minX)), y \(Int(rect.minY)), w \(Int(rect.width)), h \(Int(rect.height))"
    }
}
