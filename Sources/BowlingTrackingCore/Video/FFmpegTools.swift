import Foundation

public struct FFmpegVideoMetadataReader: VideoMetadataReading {
    public var ffprobePath: String

    public init(ffprobePath: String = "ffprobe") {
        self.ffprobePath = ffprobePath
    }

    public func resolveVideo(for video: ImportedVideo) throws -> ImportedVideo {
        let args = [
            "-v", "error",
            "-select_streams", "v:0",
            "-show_entries", "stream=duration,avg_frame_rate,width,height",
            "-of", "json",
            video.filePath
        ]

        let result = try ProcessRunner.run(path: ffprobePath, arguments: args)
        guard result.exitCode == 0 else {
            throw VideoAnalysisError.externalToolFailed(tool: "ffprobe", message: result.errorOutput)
        }

        guard let data = result.standardOutput.data(using: .utf8) else {
            return video
        }

        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let streams = json["streams"] as? [[String: Any]],
            let stream = streams.first
        else {
            return video
        }

        let duration = stream["duration"].flatMap { Double("\($0)") }
        let frameRate = stream["avg_frame_rate"].flatMap { parseFrameRate("\($0)") }
        let width = stream["width"].flatMap { Double("\($0)") }
        let height = stream["height"].flatMap { Double("\($0)") }

        var updated = video
        if updated.durationSeconds == nil {
            updated.durationSeconds = duration
        }
        if updated.frameRate == nil {
            updated.frameRate = frameRate
        }
        if updated.frameSize == nil, let width, let height {
            updated.frameSize = ImageSize(width: width, height: height)
        }

        return updated
    }

    private func parseFrameRate(_ value: String) -> Double? {
        if value.contains("/") {
            let parts = value.split(separator: "/")
            guard parts.count == 2,
                  let numerator = Double(parts[0]),
                  let denominator = Double(parts[1]),
                  denominator != 0
            else {
                return nil
            }
            return numerator / denominator
        }

        return Double(value)
    }
}

public struct FFmpegFrameExtractor: VideoFrameExtracting {
    public var ffmpegPath: String
    public var outputDirectory: URL?

    public init(ffmpegPath: String = "ffmpeg", outputDirectory: URL? = nil) {
        self.ffmpegPath = ffmpegPath
        self.outputDirectory = outputDirectory
    }

    public func extractFrames(from request: ImportedVideoAnalysisRequest) throws -> [VideoFrame] {
        let fps = request.frameSamplingFPS
        guard fps > 0 else {
            throw VideoAnalysisError.invalidSamplingFPS(fps)
        }

        let range = effectiveTimeRange(for: request)
        let outputDir = outputDirectory ?? FileManager.default.temporaryDirectory
            .appendingPathComponent("bowling_frames_\(UUID().uuidString)")

        try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

        var args: [String] = ["-hide_banner", "-loglevel", "error"]
        if let start = range.startSeconds {
            args.append(contentsOf: ["-ss", String(format: "%.3f", start)])
        }
        if let end = range.endSeconds {
            if let start = range.startSeconds {
                let duration = max(0, end - start)
                args.append(contentsOf: ["-t", String(format: "%.3f", duration)])
            } else {
                args.append(contentsOf: ["-to", String(format: "%.3f", end)])
            }
        }

        args.append(contentsOf: ["-i", request.video.filePath])
        args.append(contentsOf: ["-vf", "fps=\(String(format: "%.3f", fps))"])
        args.append(outputDir.appendingPathComponent("frame_%05d.png").path)

        let result = try ProcessRunner.run(path: ffmpegPath, arguments: args)
        guard result.exitCode == 0 else {
            throw VideoAnalysisError.externalToolFailed(tool: "ffmpeg", message: result.errorOutput)
        }

        let files = try FileManager.default.contentsOfDirectory(atPath: outputDir.path)
        let frames = files.filter { $0.hasPrefix("frame_") && $0.hasSuffix(".png") }
            .sorted()

        guard !frames.isEmpty else {
            throw VideoAnalysisError.noFramesExtracted
        }

        let startTime = range.startSeconds ?? 0.0
        let imageSize = request.video.frameSize ?? ImageSize(width: 0, height: 0)

        return frames.enumerated().map { index, filename in
            VideoFrame(
                index: index,
                timestamp: startTime + (Double(index) / fps),
                imagePath: outputDir.appendingPathComponent(filename).path,
                imageSize: imageSize
            )
        }
    }

    private func effectiveTimeRange(for request: ImportedVideoAnalysisRequest) -> (startSeconds: Double?, endSeconds: Double?) {
        if !request.manualShotRanges.isEmpty {
            let starts = request.manualShotRanges.map(\.startTimeSeconds)
            let ends = request.manualShotRanges.map(\.endTimeSeconds)
            return (starts.min(), ends.max())
        }

        return (request.trimStartSeconds, request.trimEndSeconds)
    }
}

public struct ProcessResult {
    public var exitCode: Int32
    public var standardOutput: String
    public var errorOutput: String
}

public enum ProcessRunner {
    public static func run(path: String, arguments: [String]) throws -> ProcessResult {
        let process = Process()
        guard let resolvedPath = resolveExecutable(path) else {
            throw VideoAnalysisError.missingExternalTool(path)
        }
        process.executableURL = URL(fileURLWithPath: resolvedPath)
        process.arguments = arguments

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
        } catch {
            throw VideoAnalysisError.missingExternalTool(path)
        }

        process.waitUntilExit()

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

        let output = String(data: outputData, encoding: .utf8) ?? ""
        let errorOutput = String(data: errorData, encoding: .utf8) ?? ""

        return ProcessResult(exitCode: process.terminationStatus, standardOutput: output, errorOutput: errorOutput)
    }

    private static func resolveExecutable(_ path: String) -> String? {
        if path.contains("/") || path.contains("\\") {
            return FileManager.default.isExecutableFile(atPath: path) ? path : nil
        }

        let pathValue = ProcessInfo.processInfo.environment["PATH"] ?? ""
        let separator: Character = pathValue.contains(";") ? ";" : ":"
        let directories = pathValue.split(separator: separator).map(String.init)
        var candidates = [path]

        if !path.lowercased().hasSuffix(".exe") {
            candidates.append("\(path).exe")
        }

        for dir in directories {
            for candidate in candidates {
                let fullPath = URL(fileURLWithPath: dir).appendingPathComponent(candidate).path
                if FileManager.default.isExecutableFile(atPath: fullPath) {
                    return fullPath
                }
            }
        }

        return nil
    }
}
