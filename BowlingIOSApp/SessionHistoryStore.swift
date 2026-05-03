import BowlingTrackingCore
import Foundation

final class SessionHistoryStore: ObservableObject {
    static let shared = SessionHistoryStore()

    @Published private(set) var sessions: [SessionRecord] = []

    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    private init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? SessionHistoryStore.defaultFileURL()
        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        decoder = JSONDecoder()
        load()
    }

    func appendSession(_ session: SessionRecord) {
        sessions.append(session)
        persist()
    }

    func appendShot(_ shot: ShotRecord, to sessionId: UUID) {
        guard let index = sessions.firstIndex(where: { $0.id == sessionId }) else {
            return
        }

        sessions[index].shots.append(shot)
        persist()
    }

    func finishSession(id: UUID, endedAt: Date) {
        guard let index = sessions.firstIndex(where: { $0.id == id }) else {
            return
        }

        sessions[index].endedAt = endedAt
        persist()
    }

    func session(id: UUID?) -> SessionRecord? {
        guard let id else {
            return nil
        }

        return sessions.first { $0.id == id }
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else {
            sessions = []
            return
        }

        if let decoded = try? decoder.decode([SessionRecord].self, from: data) {
            sessions = decoded
        } else {
            sessions = []
        }
    }

    private func persist() {
        guard let data = try? encoder.encode(sessions) else {
            return
        }

        try? data.write(to: fileURL)
    }

    private static func defaultFileURL() -> URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let directory = documents.first ?? FileManager.default.temporaryDirectory
        return directory.appendingPathComponent("session-history.json")
    }
}
