import AVFoundation
import BowlingTrackingCore
import Combine
import Foundation
import QuartzCore
import UIKit

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
    @Published private(set) var calibration: LaneCalibration?
    @Published private(set) var currentTrack: BallTrack?
    @Published private(set) var currentMetrics: ShotMetrics?
    @Published private(set) var shotHistory: [ShotRecord] = []
    @Published private(set) var lastShot: ShotRecord?
    @Published var dominantHand: BowlingHand = .right

    let session = AVCaptureSession()

    private let sessionQueue = DispatchQueue(label: "bowling.camera.session")
    private let videoQueue = DispatchQueue(label: "bowling.camera.video")
    private let videoOutput = AVCaptureVideoDataOutput()
    private let laneDetector = LaneVisionDetector()
    private let ballDetector = BallVisionDetector()
    private let metricEstimator = ShotMetricEstimator()
    private let sessionStore = SessionHistoryStore.shared

    private var isConfigured = false
    private var lastAnalysisTime = CACurrentMediaTime()
    private var missedDetectionCount = 0
    private var laneProjection: LaneProjection?
    private var activeShot: ActiveShot?
    private var pendingDetections = 0
    private var sessionId: UUID?
    private var captureDevice: AVCaptureDevice?
    private var captureMetadata: DeviceCaptureMetadata?
    private var isLaneDetectionEnabled = true
    private let shotConfig = ShotTrackingConfig()

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

    func confirmLane() {
        guard let detectedLane else {
            return
        }

        let calibration = LaneCalibration(
            imageSize: detectedLane.imageSize,
            laneCorners: detectedLane.corners,
            dominantHand: dominantHand,
            confidence: detectedLane.confidence
        )

        guard let projection = LaneProjection(calibration: calibration) else {
            statusText = "Lane calibration failed. Try realigning the phone."
            return
        }

        self.calibration = calibration
        laneProjection = projection
        isLaneDetectionEnabled = false
        statusText = "Lane confirmed. Waiting for ball motion..."
        startSessionIfNeeded(calibration: calibration)
    }

    func resetSession() {
        if let sessionId {
            updateOnMain {
                self.sessionStore.finishSession(id: sessionId, endedAt: Date())
            }
        }

        calibration = nil
        laneProjection = nil
        activeShot = nil
        pendingDetections = 0
        sessionId = nil
        captureMetadata = nil
        shotHistory = []
        lastShot = nil
        currentTrack = nil
        currentMetrics = nil
        isLaneDetectionEnabled = true
        statusText = "Point the back camera straight down the lane."
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

        captureDevice = camera

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

    private func updateOnMain(_ block: @escaping () -> Void) {
        DispatchQueue.main.async(execute: block)
    }

    private func ensureCaptureMetadata(from sampleBuffer: CMSampleBuffer) {
        guard captureMetadata == nil else {
            return
        }

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let resolution = ImageSize(width: Double(width), height: Double(height))

        let device = UIDevice.current
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
        let fps = captureDevice.flatMap { device in
            let seconds = CMTimeGetSeconds(device.activeVideoMinFrameDuration)
            return seconds > 0 ? 1.0 / seconds : nil
        } ?? 60.0

        captureMetadata = DeviceCaptureMetadata(
            deviceModel: device.model,
            systemName: device.systemName,
            systemVersion: device.systemVersion,
            appVersion: appVersion,
            captureFps: fps,
            captureResolution: resolution
        )

        if let calibration, sessionId == nil {
            startSessionIfNeeded(calibration: calibration)
        }
    }

    private func startSessionIfNeeded(calibration: LaneCalibration) {
        guard sessionId == nil, let captureMetadata else {
            return
        }

        let context = SessionContext(
            title: "Live Session",
            laneName: nil,
            notes: nil,
            dominantHand: calibration.dominantHand
        )

        let session = SessionRecord(
            context: context,
            deviceMetadata: captureMetadata,
            calibration: calibration
        )

        sessionId = session.id
        updateOnMain {
            self.sessionStore.appendSession(session)
            self.shotHistory = session.shots
        }
    }

    private func trackBall(in sampleBuffer: CMSampleBuffer) {
        guard let calibration, let laneProjection else {
            return
        }

        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let timeSeconds = CMTimeGetSeconds(timestamp)

        if let candidate = ballDetector.detectBall(in: sampleBuffer, calibration: calibration) {
            handleCandidate(candidate, timeSeconds: timeSeconds, calibration: calibration)
        } else {
            handleMissingDetection(timeSeconds: timeSeconds, calibration: calibration)
        }
    }

    private func handleCandidate(
        _ candidate: BallDetectionCandidate,
        timeSeconds: TimeInterval,
        calibration: LaneCalibration
    ) {
        guard let laneProjection, let laneCoordinate = laneProjection.laneCoordinate(for: candidate.center) else {
            handleMissingDetection(timeSeconds: timeSeconds, calibration: calibration)
            return
        }

        let observation = BallObservation(
            timestamp: timeSeconds,
            imageCenter: candidate.center,
            laneCoordinate: laneCoordinate,
            radiusPixels: candidate.radiusPixels,
            confidence: candidate.confidence
        )

        if activeShot == nil {
            pendingDetections = min(pendingDetections + 1, shotConfig.startDetectionsRequired)
            if pendingDetections >= shotConfig.startDetectionsRequired {
                startShot(with: observation, timeSeconds: timeSeconds)
            } else {
                updateOnMain {
                    self.statusText = "Hold steady. Looking for ball motion..."
                }
            }
            return
        }

        appendObservation(observation, timeSeconds: timeSeconds)

        if laneCoordinate.distanceFromFoulLineFeet >= calibration.geometry.foulLineToHeadPinFeet - shotConfig.endDistanceBufferFeet {
            finalizeShot(reason: .reachedPins, calibration: calibration)
        }
    }

    private func handleMissingDetection(timeSeconds: TimeInterval, calibration: LaneCalibration) {
        pendingDetections = 0

        guard var shot = activeShot else {
            return
        }

        shot.missingCount += 1
        shot.maxMissingCount = max(shot.maxMissingCount, shot.missingCount)
        activeShot = shot

        if timeSeconds - shot.startTimestamp >= shotConfig.maxShotDurationSeconds {
            finalizeShot(reason: .timeout, calibration: calibration)
        } else if shot.missingCount >= shotConfig.maxMissingDetections {
            finalizeShot(reason: .lostTrack, calibration: calibration)
        }
    }

    private func startShot(with observation: BallObservation, timeSeconds: TimeInterval) {
        activeShot = ActiveShot(
            startedAt: Date(),
            startTimestamp: timeSeconds,
            lastTimestamp: timeSeconds,
            missingCount: 0,
            maxMissingCount: 0,
            observations: [observation]
        )

        pendingDetections = 0
        let track = BallTrack(observations: [observation])
        let metrics = metricEstimator.estimate(from: track)
        updateOnMain {
            self.statusText = "Tracking shot..."
            self.currentTrack = track
            self.currentMetrics = metrics
        }
    }

    private func appendObservation(_ observation: BallObservation, timeSeconds: TimeInterval) {
        guard var shot = activeShot else {
            return
        }

        shot.lastTimestamp = timeSeconds
        shot.missingCount = 0
        shot.observations.append(observation)
        activeShot = shot

        let track = BallTrack(observations: shot.observations)
        let metrics = metricEstimator.estimate(from: track)
        updateOnMain {
            self.currentTrack = track
            self.currentMetrics = metrics
        }

        if timeSeconds - shot.startTimestamp >= shotConfig.maxShotDurationSeconds,
           let calibration {
            finalizeShot(reason: .timeout, calibration: calibration)
        }
    }

    private func finalizeShot(reason: ShotEndReason, calibration: LaneCalibration) {
        guard let shot = activeShot else {
            return
        }

        activeShot = nil
        pendingDetections = 0

        let track = BallTrack(observations: shot.observations)
        guard track.observations.count >= 2 else {
            updateOnMain {
                self.statusText = "Shot discarded. Keep the ball in frame longer."
                self.currentTrack = nil
                self.currentMetrics = nil
            }
            return
        }

        var metrics = metricEstimator.estimate(from: track)
        let flags = confidenceFlags(for: track, calibration: calibration, shot: shot, reason: reason)
        metrics.confidenceFlags = flags

        let warnings = flags.map { $0.message ?? $0.code }
        let record = ShotRecord(
            startedAt: shot.startedAt,
            endedAt: Date(),
            calibration: calibration,
            track: track,
            metrics: metrics,
            warnings: warnings
        )

        if let sessionId {
            updateOnMain {
                self.sessionStore.appendShot(record, to: sessionId)
                self.shotHistory = self.sessionStore.session(id: sessionId)?.shots ?? []
            }
        }

        updateOnMain {
            self.lastShot = record
            self.currentTrack = nil
            self.currentMetrics = nil
            self.statusText = "Shot saved. Ready for the next one."
        }
    }

    private func confidenceFlags(
        for track: BallTrack,
        calibration: LaneCalibration,
        shot: ActiveShot,
        reason: ShotEndReason
    ) -> [ConfidenceFlag] {
        var flags: [ConfidenceFlag] = []

        if calibration.confidence < 0.6 {
            flags.append(ConfidenceFlag(code: "low_lane_confidence", message: "Lane calibration confidence is low."))
        }

        if track.observations.count < 6 {
            flags.append(ConfidenceFlag(code: "short_track", message: "Track has limited observations."))
        }

        let traveled = track.totalTrackedDistance(geometry: calibration.geometry)
        if traveled < 30 {
            flags.append(ConfidenceFlag(code: "short_distance", message: "Ball was not tracked far down lane."))
        }

        if let last = track.lastObservation,
           last.laneCoordinate.distanceFromFoulLineFeet < calibration.geometry.foulLineToHeadPinFeet - 6 {
            flags.append(ConfidenceFlag(code: "ended_early", message: "Ball tracking ended before the pins."))
        }

        if shot.maxMissingCount >= shotConfig.maxMissingDetections {
            flags.append(ConfidenceFlag(code: "tracking_gaps", message: "Tracking gaps detected during the shot."))
        }

        if reason == .timeout {
            flags.append(ConfidenceFlag(code: "timeout", message: "Shot exceeded expected duration."))
        }

        return flags
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
        let analysisInterval = calibration == nil ? 0.18 : 0.06
        guard now - lastAnalysisTime >= analysisInterval else {
            return
        }

        lastAnalysisTime = now

        ensureCaptureMetadata(from: sampleBuffer)

        if calibration == nil || isLaneDetectionEnabled {
            if let lane = laneDetector.detectLane(in: sampleBuffer) {
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
            return
        }

        trackBall(in: sampleBuffer)
    }
}

private struct ShotTrackingConfig {
    var startDetectionsRequired: Int = 3
    var maxMissingDetections: Int = 6
    var maxShotDurationSeconds: TimeInterval = 8.0
    var endDistanceBufferFeet: Double = 1.5
}

private struct ActiveShot {
    var startedAt: Date
    var startTimestamp: TimeInterval
    var lastTimestamp: TimeInterval
    var missingCount: Int
    var maxMissingCount: Int
    var observations: [BallObservation]
}

private enum ShotEndReason {
    case reachedPins
    case lostTrack
    case timeout
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
