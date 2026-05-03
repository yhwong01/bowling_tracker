import BowlingTrackingCore
import SwiftUI

struct ShotHistoryView: View {
    @StateObject private var store = SessionHistoryStore.shared

    var body: some View {
        List {
            if store.sessions.isEmpty {
                Text("No sessions saved yet.")
                    .foregroundStyle(.secondary)
            }

            ForEach(store.sessions, id: \.id) { session in
                Section(sessionHeader(session)) {
                    ForEach(Array(session.shots.enumerated()), id: \.element.id) { index, shot in
                        ShotHistoryRow(index: index + 1, shot: shot)
                    }
                }
            }
        }
        .navigationTitle("Shot History")
    }

    private func sessionHeader(_ session: SessionRecord) -> String {
        let formattedDate = dateFormatter.string(from: session.context.startedAt)
        let title = session.context.title ?? "Session"
        return "\(title) · \(formattedDate)"
    }

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }
}

private struct ShotHistoryRow: View {
    let index: Int
    let shot: ShotRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Shot \(index)")
                .font(.headline)

            HStack {
                MetricLabel(title: "Launch", value: shot.metrics.launchSpeedMph, suffix: "mph")
                MetricLabel(title: "Entry", value: shot.metrics.entryBoard)
                MetricLabel(title: "Hook", value: shot.metrics.hookBoards)
            }

            if !shot.metrics.confidenceFlags.isEmpty {
                Text("Flags: \(shot.metrics.confidenceFlags.map(\.code).joined(separator: ", "))")
                    .font(.caption)
                    .foregroundStyle(.yellow)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct MetricLabel: View {
    let title: String
    let value: Double?
    var suffix: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(formattedValue)
                .font(.callout.monospacedDigit())
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

#Preview {
    NavigationStack {
        ShotHistoryView()
    }
}
