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
    case unsupportedCommand(String)

    var description: String {
        switch self {
        case .usage(let message):
            return message
        case .missingValue(let flag):
            return "Missing value for \(flag)."
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
        case "analyze-ball-track":
            try analyzeBallTrack()
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

        let request = ImportedVideoAnalysisRequest(
            video: ImportedVideo(filePath: input),
            mode: mode,
            dominantHand: hand,
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

    private func requiredValue(for flag: String) throws -> String {
        guard let value = optionalValue(for: flag) else {
            throw CLIError.missingValue(flag)
        }

        return value
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
          create-video-request --input <videoPath> --output <request.json> [--mode singleShot|multiShotSession] [--hand left|right] [--fps 60] [--trim-start seconds] [--trim-end seconds]
          analyze-ball-track --input <track.json> --output <metrics.json>
          help
        """

        print(help)
    }
}

do {
    try CLI(arguments: CommandLine.arguments).run()
} catch {
    FileHandle.standardError.write(Data("\(error)\n".utf8))
    exit(1)
}
