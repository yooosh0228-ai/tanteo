import SwiftUI
import ScoreKit

struct HistoryView: View {
    @Environment(MatchStore.self) private var store

    var body: some View {
        Group {
            if store.history.isEmpty {
                ContentUnavailableView("Todavía no hay partidos",
                                       systemImage: "clock",
                                       description: Text("Los partidos que termines aparecen aquí."))
            } else {
                List {
                    ForEach(store.history) { match in
                        NavigationLink {
                            MatchDetailView(match: match)
                        } label: {
                            HistoryRow(match: match)
                        }
                    }
                    .onDelete { offsets in
                        let ids = Set(offsets.map { store.history[$0].id })
                        store.deleteFromHistory(ids)
                    }
                }
            }
        }
        .navigationTitle("Historial")
    }
}

private struct HistoryRow: View {
    let match: Match

    var body: some View {
        let s = match.state
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("\(s.config.name(of: .a)) vs \(s.config.name(of: .b))")
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                Text(match.summary)
                    .font(.subheadline.monospacedDigit())
            }
            HStack {
                if let w = s.winner {
                    Label("Ganó \(s.config.name(of: w))", systemImage: "trophy.fill")
                        .foregroundStyle(Theme.color(w))
                } else {
                    Label("Sin terminar", systemImage: "pause.circle")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(match.startedAt, format: .dateTime.day().month().hour().minute())
                    .foregroundStyle(.secondary)
            }
            .font(.caption)
        }
        .padding(.vertical, 2)
    }
}

private struct MatchDetailView: View {
    let match: Match

    var body: some View {
        let s = match.state
        let won = match.pointsWon
        List {
            Section("Resultado") {
                LabeledContent("Marcador", value: match.summary)
                if let w = s.winner {
                    LabeledContent("Ganador", value: s.config.name(of: w))
                }
                LabeledContent("Reglas", value: s.config.rulesSummary)
            }
            if s.config.sport == .padel && !s.sets.isEmpty {
                Section("Sets") {
                    ForEach(Array(s.sets.enumerated()), id: \.offset) { i, set in
                        LabeledContent(set.isSuperTiebreak ? "Súper tie-break" : "Set \(i + 1)", value: set.label)
                    }
                }
            }
            Section("Puntos ganados") {
                LabeledContent(s.config.name(of: .a), value: "\(won.a)")
                LabeledContent(s.config.name(of: .b), value: "\(won.b)")
            }
            Section("Tiempo") {
                LabeledContent("Empezó", value: match.startedAt.formatted(date: .abbreviated, time: .shortened))
                LabeledContent("Duración", value: Duration.seconds(match.updatedAt.timeIntervalSince(match.startedAt))
                    .formatted(.units(allowed: [.hours, .minutes], width: .abbreviated)))
            }
        }
        .navigationTitle("\(s.config.name(of: .a)) vs \(s.config.name(of: .b))")
        .navigationBarTitleDisplayMode(.inline)
    }
}
