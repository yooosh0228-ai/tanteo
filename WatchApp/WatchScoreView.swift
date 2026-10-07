import SwiftUI
import WatchKit
import ScoreKit

/// Pantalla de juego: toca el cuadro del equipo que ganó el punto.
struct WatchScoreView: View {
    @Environment(MatchStore.self) private var store
    @Environment(WorkoutManager.self) private var workout
    @State private var showOptions = false
    @State private var showChangeOfEnds = false
    @State private var seenEvents = 0

    var body: some View {
        if let match = store.current {
            let s = match.state
            VStack(spacing: 6) {
                header(s)
                HStack(spacing: 6) {
                    TeamButton(team: .a, state: s) { tap(.a, before: s) }
                    TeamButton(team: .b, state: s) { tap(.b, before: s) }
                }
                footer(match)
            }
            .padding(.horizontal, 2)
            .overlay(alignment: .center) {
                if showChangeOfEnds {
                    Label("Cambio de lado", systemImage: "arrow.left.arrow.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Theme.accent, in: Capsule())
                        .transition(.scale.combined(with: .opacity))
                        .allowsHitTesting(false)
                }
            }
            .onAppear { seenEvents = match.events.count }
            .onChange(of: match.events.count) { _, count in
                // Avisar del cambio de lado solo cuando se suma un punto (aquí o desde el iPhone).
                if count > seenEvents && match.changeOfEnds {
                    WKInterfaceDevice.current().play(.directionUp)
                    withAnimation(.snappy) { showChangeOfEnds = true }
                    Task {
                        try? await Task.sleep(for: .seconds(2.5))
                        withAnimation(.snappy) { showChangeOfEnds = false }
                    }
                }
                seenEvents = count
            }
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

    /// Tiempo de juego y pulso, en una línea discreta debajo de los cuadros.
    private func footer(_ match: Match) -> some View {
        HStack(spacing: 8) {
            TimelineView(.periodic(from: match.startedAt, by: 1)) { context in
                Text(Duration.seconds(max(0, context.date.timeIntervalSince(match.startedAt))),
                     format: .time(pattern: .minuteSecond))
            }
            if workout.isRunning && workout.heartRate > 0 {
                Label("\(Int(workout.heartRate))", systemImage: "heart.fill")
                    .foregroundStyle(.red)
            }
        }
        .font(.system(size: 11, weight: .medium, design: .rounded))
        .monospacedDigit()
        .foregroundStyle(.secondary)
        .labelStyle(.titleAndIcon)
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

    private var color: Color { Theme.color(team) }
    private var serving: Bool { state.server == team && state.config.sport == .padel && !state.isFinished }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                HStack(spacing: 3) {
                    if serving {
                        Circle().fill(Theme.accent).frame(width: 6, height: 6)
                    }
                    Text(state.config.name(of: team))
                        .font(.system(size: 11, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .foregroundStyle(color)
                .frame(maxWidth: .infinity)

                Spacer(minLength: 0)

                Text(state.pointLabel(for: team))
                    .font(.system(size: 46, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .foregroundStyle(.white)

                Spacer(minLength: 0)

                if state.config.sport == .padel {
                    HStack(spacing: 3) {
                        Text("JUEGOS").font(.system(size: 8, weight: .bold)).tracking(0.5)
                        Text("\(state.games[team])").font(.system(size: 13, weight: .bold, design: .rounded)).monospacedDigit()
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(color.opacity(0.35), in: Capsule())
                    .foregroundStyle(.white)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 4)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                LinearGradient(colors: [color.opacity(0.45), color.opacity(0.12)], startPoint: .top, endPoint: .bottom),
                in: RoundedRectangle(cornerRadius: 16)
            )
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(color, lineWidth: serving ? 2 : 1))
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
    @Environment(WorkoutManager.self) private var workout
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
            if workout.isRunning {
                Section("Entrenamiento") {
                    LabeledContent("Pulso", value: workout.heartRate > 0 ? "\(Int(workout.heartRate)) lpm" : "—")
                    LabeledContent("Calorías", value: "\(Int(workout.activeCalories)) kcal")
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
