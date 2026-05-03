import Foundation
import BowlingTrackingCore

struct BallTrackEnvelope: Codable {
    var track: BallTrack
    var geometry: LaneGeometry?
}

struct MetricsEnvelope: Codable {
    var metrics: ShotMetrics
}

enum CLIError: Error, CustomStringConvertible {
    case usage(String)
    case missingValue(String)
    case missingCalibration
    case unsupportedCommand(String)

    var description: String {
        switch self {
        case .usage(let message):
            return message
        case .missingValue(let flag):
            return "Missing value for \(flag)."
        case .missingCalibration:
            return "Missing calibration. Provide --calibration when creating the request or use create-calibration."
        case .unsupportedCommand(let command):
            return "Unsupported command: \(command)."
        }
    }
}

struct CLI {
    private let arguments: [String]

    init(arguments: [String]) {
        self.arguments = arguments
    }

    func run() throws {
        guard arguments.count > 1 else {
            printHelp()
            return
        }

        switch arguments[1] {
        case "help", "--help", "-h":
            printHelp()
        case "create-video-request":
            try createVideoRequest()
        case "create-calibration":
            try createCalibration()
        case "analyze-ball-track":
            try analyzeBallTrack()
        case "analyze-video":
            try analyzeVideo()
        default:
            throw CLIError.unsupportedCommand(arguments[1])
        }
    }

    private func createVideoRequest() throws {
        let input = try requiredValue(for: "--input")
        let output = try requiredValue(for: "--output")
        let mode = VideoAnalysisMode(rawValue: optionalValue(for: "--mode") ?? "singleShot") ?? .singleShot
        let hand = BowlingHand(rawValue: optionalValue(for: "--hand") ?? "right") ?? .right
        let fps = Double(optionalValue(for: "--fps") ?? "60") ?? 60
        let trimStart = optionalValue(for: "--trim-start").flatMap(Double.init)
        let trimEnd = optionalValue(for: "--trim-end").flatMap(Double.init)
        let calibrationPath = optionalValue(for: "--calibration")
        let calibration: LaneCalibration? = try calibrationPath.map { try readJSON(from: $0) }

        let request = ImportedVideoAnalysisRequest(
            video: ImportedVideo(filePath: input),
            mode: mode,
            dominantHand: hand,
            calibration: calibration,
            frameSamplingFPS: fps,
            trimStartSeconds: trimStart,
            trimEndSeconds: trimEnd
        )

        try writeJSON(request, to: output)
        print("Wrote video analysis request to \(output)")
    }

    private func analyzeBallTrack() throws {
        let input = try requiredValue(for: "--input")
        let output = try requiredValue(for: "--output")

        let envelope: BallTrackEnvelope = try readJSON(from: input)
        let estimator = ShotMetricEstimator(geometry: envelope.geometry ?? .regulation)
        let metrics = estimator.estimate(from: envelope.track)

        try writeJSON(MetricsEnvelope(metrics: metrics), to: output)
        print("Wrote shot metrics to \(output)")
    }

    private func createCalibration() throws {
        let output = try requiredValue(for: "--output")
        let imageWidth = try requiredDouble(for: "--image-width")
        let imageHeight = try requiredDouble(for: "--image-height")
        let hand = BowlingHand(rawValue: optionalValue(for: "--hand") ?? "right") ?? .right
        let confidence = Double(optionalValue(for: "--confidence") ?? "0.9") ?? 0.9

        let calibration = LaneCalibration(
            imageSize: ImageSize(width: imageWidth, height: imageHeight),
            laneCorners: LaneCorners(
                foulLineLeft: ImagePoint(
                    x: try requiredDouble(for: "--foul-left-x"),
                    y: try requiredDouble(for: "--foul-left-y")
                ),
                foulLineRight: ImagePoint(
                    x: try requiredDouble(for: "--foul-right-x"),
                    y: try requiredDouble(for: "--foul-right-y")
                ),
                pinDeckLeft: ImagePoint(
                    x: try requiredDouble(for: "--pin-left-x"),
                    y: try requiredDouble(for: "--pin-left-y")
                ),
                pinDeckRight: ImagePoint(
                    x: try requiredDouble(for: "--pin-right-x"),
                    y: try requiredDouble(for: "--pin-right-y")
                )
            ),
            dominantHand: hand,
            confidence: confidence
        )

        try writeJSON(calibration, to: output)
        print("Wrote lane calibration to \(output)")
    }

    private func analyzeVideo() throws {
        let requestPath = try requiredValue(for: "--request")
        let output = try requiredValue(for: "--output")
        let trackDir = try requiredValue(for: "--track-dir")
        let ffmpegPath = optionalValue(for: "--ffmpeg") ?? "ffmpeg"
        let ffprobePath = optionalValue(for: "--ffprobe") ?? "ffprobe"
        let framesDir = optionalValue(for: "--frames-dir")

        let request: ImportedVideoAnalysisRequest = try readJSON(from: requestPath)

        let analyzer = ImportedVideoAnalyzer(
            metadataReader: FFmpegVideoMetadataReader(ffprobePath: ffprobePath),
            frameExtractor: FFmpegFrameExtractor(
                ffmpegPath: ffmpegPath,
                outputDirectory: framesDir.map { URL(fileURLWithPath: $0) }
            ),
            shotSegmenter: ManualOrWholeVideoShotSegmenter(),
            laneCalibrator: RequiredLaneCalibrator(),
            ballTracker: PrecomputedBallTracker(trackDirectory: URL(fileURLWithPath: trackDir))
        )

        let result = try analyzer.analyze(request)
        try writeJSON(result, to: output)
        print("Wrote video analysis to \(output)")
    }

    private func requiredValue(for flag: String) throws -> String {
        guard let value = optionalValue(for: flag) else {
            throw CLIError.missingValue(flag)
        }

        return value
    }

    private func requiredDouble(for flag: String) throws -> Double {
        let value = try requiredValue(for: flag)
        guard let number = Double(value) else {
            throw CLIError.usage("Invalid numeric value for \(flag).")
        }
        return number
    }

    private func optionalValue(for flag: String) -> String? {
        guard let index = arguments.firstIndex(of: flag), index + 1 < arguments.count else {
            return nil
        }

        return arguments[index + 1]
    }

    private func readJSON<T: Decodable>(from path: String) throws -> T {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func writeJSON<T: Encodable>(_ value: T, to path: String) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(value)
        try data.write(to: URL(fileURLWithPath: path))
    }

    private func printHelp() {
        let help = """
        BowlingVideoAnalyzerCLI

        Commands:
                    create-video-request --input <videoPath> --output <request.json> [--mode singleShot|multiShotSession] [--hand left|right] [--fps 60] [--trim-start seconds] [--trim-end seconds] [--calibration calibration.json]
                    create-calibration --output <calibration.json> --image-width <px> --image-height <px> --foul-left-x <px> --foul-left-y <px> --foul-right-x <px> --foul-right-y <px> --pin-left-x <px> --pin-left-y <px> --pin-right-x <px> --pin-right-y <px> [--hand left|right] [--confidence 0.9]
                    analyze-ball-track --input <track.json> --output <metrics.json>
                    analyze-video --request <request.json> --output <result.json> --track-dir <directory> [--ffmpeg path] [--ffprobe path] [--frames-dir directory]
          help
        """

        print(help)
    }
}

private struct RequiredLaneCalibrator: VideoLaneCalibrating {
    func calibration(
        for frames: [VideoFrame],
        request: ImportedVideoAnalysisRequest,
        segment: VideoShotSegment
    ) throws -> LaneCalibration {
        if let calibration = request.calibration {
            return calibration
        }

        throw CLIError.missingCalibration
    }
}

do {
    try CLI(arguments: CommandLine.arguments).run()
} catch {
    FileHandle.standardError.write(Data("\(error)\n".utf8))
    exit(1)
}
