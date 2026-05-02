import AVFoundation
import Combine
import Foundation
import QuartzCore

enum CameraPermissionState: Equatable {
    case notDetermined
    case authorized
    case denied
    case restricted
    case unavailable
}

final class CameraSessionController: NSObject, ObservableObject {
    @Published private(set) var permissionState: CameraPermissionState
    @Published private(set) var detectedLane: DetectedLane?
    @Published private(set) var statusText = "Point the back camera straight down the lane."
    @Published private(set) var isRunning = false

    let session = AVCaptureSession()

    private let sessionQueue = DispatchQueue(label: "bowling.camera.session")
    private let videoQueue = DispatchQueue(label: "bowling.camera.video")
    private let videoOutput = AVCaptureVideoDataOutput()
    private let detector = LaneVisionDetector()

    private var isConfigured = false
    private var lastAnalysisTime = CACurrentMediaTime()
    private var missedDetectionCount = 0

    override init() {
        permissionState = CameraSessionController.currentPermissionState()
        super.init()
    }

    func start() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            permissionState = .authorized
            startConfiguredSession()
        case .notDetermined:
            permissionState = .notDetermined
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    guard let self else {
                        return
                    }

                    self.permissionState = granted ? .authorized : .denied
                    if granted {
                        self.startConfiguredSession()
                    } else {
                        self.statusText = "Camera permission is required for live lane detection."
                    }
                }
            }
        case .denied:
            permissionState = .denied
            statusText = "Camera access is disabled. Enable it in Settings to detect the lane."
        case .restricted:
            permissionState = .restricted
            statusText = "Camera access is restricted on this device."
        @unknown default:
            permissionState = .unavailable
            statusText = "Camera access is unavailable on this device."
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            guard let self else {
                return
            }

            if self.session.isRunning {
                self.session.stopRunning()
            }

            DispatchQueue.main.async {
                self.isRunning = false
            }
        }
    }

    private func startConfiguredSession() {
        sessionQueue.async { [weak self] in
            guard let self else {
                return
            }

            do {
                try self.configureSessionIfNeeded()

                if !self.session.isRunning {
                    self.session.startRunning()
                }

                DispatchQueue.main.async {
                    self.isRunning = true
                    self.statusText = "Scanning for lane edges..."
                }
            } catch {
                DispatchQueue.main.async {
                    self.permissionState = .unavailable
                    self.statusText = error.localizedDescription
                }
            }
        }
    }

    private func configureSessionIfNeeded() throws {
        guard !isConfigured else {
            return
        }

        session.beginConfiguration()
        session.sessionPreset = .hd1280x720

        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            session.commitConfiguration()
            throw CameraSetupError.noBackCamera
        }

        let input = try AVCaptureDeviceInput(device: camera)
        guard session.canAddInput(input) else {
            session.commitConfiguration()
            throw CameraSetupError.cannotAddInput
        }

        session.addInput(input)

        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        videoOutput.setSampleBufferDelegate(self, queue: videoQueue)

        guard session.canAddOutput(videoOutput) else {
            session.commitConfiguration()
            throw CameraSetupError.cannotAddOutput
        }

        session.addOutput(videoOutput)
        session.commitConfiguration()
        isConfigured = true
    }

    private func publish(lane: DetectedLane) {
        let stabilizedLane = detectedLane?.blended(toward: lane, weight: 0.36) ?? lane
        detectedLane = stabilizedLane
        statusText = "Lane locked · \(Int(round(stabilizedLane.confidence * 100)))% confidence"
    }

    private static func currentPermissionState() -> CameraPermissionState {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return .authorized
        case .notDetermined:
            return .notDetermined
        case .denied:
            return .denied
        case .restricted:
            return .restricted
        @unknown default:
            return .unavailable
        }
    }
}

extension CameraSessionController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        let now = CACurrentMediaTime()
        guard now - lastAnalysisTime >= 0.18 else {
            return
        }

        lastAnalysisTime = now

        if let lane = detector.detectLane(in: sampleBuffer) {
            missedDetectionCount = 0
            DispatchQueue.main.async { [weak self] in
                self?.publish(lane: lane)
            }
        } else {
            missedDetectionCount += 1
            if missedDetectionCount >= 8 {
                DispatchQueue.main.async { [weak self] in
                    self?.statusText = "Looking for both lane edges..."
                }
            }
        }
    }
}

private enum CameraSetupError: LocalizedError {
    case noBackCamera
    case cannotAddInput
    case cannotAddOutput

    var errorDescription: String? {
        switch self {
        case .noBackCamera:
            return "No back camera was found on this device."
        case .cannotAddInput:
            return "The camera input could not be added."
        case .cannotAddOutput:
            return "The camera video output could not be added."
        }
    }
}
