import SwiftUI
import WatchKit
import ScoreKit

/// Pantalla de juego: toca la mitad de arriba o la de abajo para sumarle el punto a ese equipo.
struct WatchScoreView: View {
    @Environment(MatchStore.self) private var store
    @State private var showOptions = false

    var body: some View {
        if let match = store.current {
            let s = match.state
            VStack(spacing: 4) {
                header(s)
                TeamButton(team: .a, state: s) { tap(.a, before: s) }
                TeamButton(team: .b, state: s) { tap(.b, before: s) }
            }
            .padding(.horizontal, 2)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        store.undo()
                        WKInterfaceDevice.current().play(.directionDown)
                    } label: {
                        Image(systemName: "arrow.uturn.backward")
                    }
                    .disabled(!match.canUndo)
                    .accessibilityLabel("Deshacer")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showOptions = true
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                    .accessibilityLabel("Opciones")
                }
            }
            .sheet(isPresented: $showOptions) {
                WatchOptionsView(match: match)
            }
            .overlay {
                if let winner = s.winner {
                    WinnerOverlay(name: s.config.name(of: winner), color: Theme.color(winner), summary: match.summary)
                }
            }
        }
    }

    private func header(_ s: ScoreState) -> some View {
        Text(s.statusLabel ?? (s.setsSummary.isEmpty ? s.config.rulesSummary : s.setsSummary))
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundStyle(s.statusLabel != nil ? Theme.accent : .secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }

    private func tap(_ team: Team, before: ScoreState) {
        store.point(team)
        guard let after = store.current?.state else { return }
        let device = WKInterfaceDevice.current()
        if after.isFinished || after.sets.count != before.sets.count {
            device.play(.success)
        } else if after.games != before.games {
            device.play(.notification)
        } else {
            device.play(.click)
        }
    }
}

private struct TeamButton: View {
    let team: Team
    let state: ScoreState
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 6) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 4) {
                        if state.server == team && state.config.sport == .padel {
                            Circle().fill(Theme.accent).frame(width: 7, height: 7)
                        }
                        Text(state.config.name(of: team))
                            .font(.system(size: 12, weight: .medium))
                            .lineLimit(1)
                    }
                    if state.config.sport == .padel {
                        Text("Juegos \(state.games[team])")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
                Text(state.pointLabel(for: team))
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .minimumScaleFactor(0.6)
            }
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.color(team).opacity(0.28), in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.color(team), lineWidth: 1.5))
        }
        .buttonStyle(.plain)
        .disabled(state.isFinished)
        .animation(.snappy, value: state.points)
        .accessibilityLabel("Punto para \(state.config.name(of: team))")
    }
}

private struct WinnerOverlay: View {
    @Environment(MatchStore.self) private var store
    let name: String
    let color: Color
    let summary: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "trophy.fill").font(.title2).foregroundStyle(Theme.accent)
            Text(name).font(.headline).foregroundStyle(color).lineLimit(1)
            Text(summary).font(.caption).foregroundStyle(.secondary)
            Button("Terminar") { store.endMatch() }
                .tint(color)
            Button("Deshacer último punto") { store.undo() }
                .font(.caption2)
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black.opacity(0.9))
    }
}

private struct WatchOptionsView: View {
    @Environment(MatchStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let match: Match

    var body: some View {
        List {
            Section {
                Text(match.config.rulesSummary).font(.caption).foregroundStyle(.secondary)
            }
            if match.config.sport == .padel {
                Section("Saca ahora") {
                    ForEach(Team.allCases, id: \.self) { team in
                        Button {
                            store.setServer(team)
                            dismiss()
                        } label: {
                            HStack {
                                Text(match.config.name(of: team))
                                Spacer()
                                if match.state.server == team { Image(systemName: "checkmark") }
                            }
                        }
                    }
                }
            }
            Section {
                Button("Terminar partido", role: .destructive) {
                    dismiss()
                    store.endMatch()
                }
            }
            Section {
                Label(store.otherDeviceReachable ? "iPhone conectado" : "iPhone sin conexión",
                      systemImage: store.otherDeviceReachable ? "iphone" : "iphone.slash")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
