import SwiftUI
import ScoreKit

/// Marcador en vivo. Se actualiza solo cuando sumas puntos desde el reloj; también se puede tocar aquí.
struct LiveView: View {
    @Environment(MatchStore.self) private var store
    @State private var showSetup = false
    @State private var confirmEnd = false
    @State private var showChangeOfEnds = false
    @State private var seenEvents = 0

    var body: some View {
        Group {
            if let match = store.current {
                scoreboard(match)
            } else {
                empty
            }
        }
        .navigationTitle("Tanteo")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ConnectionBadge(reachable: store.otherDeviceReachable)
            }
        }
        .sheet(isPresented: $showSetup) {
            SetupView()
        }
    }

    private var empty: some View {
        ContentUnavailableView {
            Label("Sin partido en curso", systemImage: "applewatch")
        } description: {
            Text("Empieza el partido en el reloj o aquí. El marcador se mantiene igual en los dos.")
        } actions: {
            Button("Nuevo partido") { showSetup = true }
                .buttonStyle(.borderedProminent)
                .foregroundStyle(.black)
        }
    }

    private func scoreboard(_ match: Match) -> some View {
        let s = match.state
        return VStack(spacing: 16) {
            VStack(spacing: 4) {
                HStack(spacing: 10) {
                    Text(s.config.rulesSummary)
                    if !s.isFinished {
                        TimelineView(.periodic(from: match.startedAt, by: 1)) { context in
                            Label {
                                Text(Duration.seconds(max(0, context.date.timeIntervalSince(match.startedAt))),
                                     format: .time(pattern: .minuteSecond))
                            } icon: {
                                Image(systemName: "stopwatch")
                            }
                            .monospacedDigit()
                        }
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                if let status = s.statusLabel {
                    Text(status)
                        .font(.headline)
                        .foregroundStyle(Theme.accent)
                }
            }

            BoardTable(state: s)

            HStack(spacing: 12) {
                PointButton(team: .a, state: s) { store.point(.a) }
                PointButton(team: .b, state: s) { store.point(.b) }
            }
            .frame(maxHeight: 220)

            HStack {
                Button {
                    store.undo()
                } label: {
                    Label("Deshacer", systemImage: "arrow.uturn.backward")
                }
                .disabled(!match.canUndo)

                Spacer()

                Button(role: .destructive) {
                    confirmEnd = true
                } label: {
                    Label("Terminar", systemImage: "flag.checkered")
                }
            }
            .buttonStyle(.bordered)

            Spacer(minLength: 0)
        }
        .padding()
        .overlay(alignment: .top) {
            if showChangeOfEnds {
                Label("Cambio de lado", systemImage: "arrow.left.arrow.right")
                    .font(.headline)
                    .foregroundStyle(.black)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Theme.accent, in: Capsule())
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .onAppear { seenEvents = match.events.count }
        .onChange(of: match.events.count) { _, count in
            if count > seenEvents && match.changeOfEnds {
                withAnimation(.snappy) { showChangeOfEnds = true }
                Task {
                    try? await Task.sleep(for: .seconds(2.5))
                    withAnimation(.snappy) { showChangeOfEnds = false }
                }
            }
            seenEvents = count
        }
        .sensoryFeedback(.warning, trigger: showChangeOfEnds) { _, new in new }
        .confirmationDialog("¿Terminar el partido?", isPresented: $confirmEnd, titleVisibility: .visible) {
            Button("Terminar y guardar", role: .destructive) { store.endMatch() }
        } message: {
            Text("Se guarda en el historial con el marcador actual.")
        }
    }
}

/// Tabla de marcador estilo TV: sets, juegos y puntos.
private struct BoardTable: View {
    let state: ScoreState

    var body: some View {
        VStack(spacing: 0) {
            row(.a)
            Divider()
            row(.b)
        }
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16))
    }

    private func row(_ team: Team) -> some View {
        HStack(spacing: 14) {
            Circle()
                .fill(state.server == team && state.config.sport == .padel && !state.isFinished ? Theme.accent : .clear)
                .frame(width: 10, height: 10)
            Text(state.config.name(of: team))
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.color(team))
                .lineLimit(1)
            Spacer()
            if state.config.sport == .padel {
                ForEach(Array(state.sets.enumerated()), id: \.offset) { _, set in
                    Text(setCell(set, team))
                        .font(.title3.monospacedDigit())
                        .foregroundStyle(set.winner == team ? .primary : .secondary)
                        .frame(minWidth: 24)
                }
                if !state.isFinished {
                    Text("\(state.games[team])")
                        .font(.title3.weight(.bold).monospacedDigit())
                        .frame(minWidth: 24)
                }
            }
            if !state.isFinished {
                Text(state.pointLabel(for: team))
                    .font(.system(size: 34, weight: .heavy, design: .rounded).monospacedDigit())
                    .contentTransition(.numericText())
                    .frame(minWidth: 64, alignment: .trailing)
            } else if state.winner == team {
                Image(systemName: "trophy.fill").foregroundStyle(Theme.accent)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .animation(.snappy, value: state.points)
    }

    private func setCell(_ set: SetResult, _ team: Team) -> String {
        if set.isSuperTiebreak, let tb = set.tiebreak { return "\(tb[team])" }
        return "\(set.games[team])"
    }
}

private struct PointButton: View {
    let team: Team
    let state: ScoreState
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: "plus").font(.title.weight(.bold))
                Text(state.config.name(of: team)).font(.headline).lineLimit(1)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .foregroundStyle(Theme.color(team))
            .background(Theme.color(team).opacity(0.18), in: RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.color(team), lineWidth: 2))
        }
        .buttonStyle(.plain)
        .disabled(state.isFinished)
        .sensoryFeedback(.impact, trigger: state.points)
    }
}

private struct ConnectionBadge: View {
    let reachable: Bool

    var body: some View {
        Image(systemName: reachable ? "applewatch.radiowaves.left.and.right" : "applewatch.slash")
            .foregroundStyle(reachable ? Theme.accent : .secondary)
            .accessibilityLabel(reachable ? "Reloj conectado" : "Reloj sin conexión")
    }
}
