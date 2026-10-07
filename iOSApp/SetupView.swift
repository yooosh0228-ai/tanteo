import SwiftUI
import ScoreKit

/// Nuevo partido desde el iPhone (aquí sí se pueden escribir los nombres cómodamente).
struct SetupView: View {
    @Environment(MatchStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var config = MatchConfig()
    @State private var firstServer: Team = .a

    var body: some View {
        NavigationStack {
            Form {
                Section("Equipos") {
                    TextField("Equipo A", text: $config.teamA)
                    TextField("Equipo B", text: $config.teamB)
                }

                Section {
                    Picker("Deporte", selection: $config.sport) {
                        ForEach(Sport.allCases, id: \.self) { Text($0.displayName).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }

                if config.sport == .padel {
                    Section {
                        Picker("En 40-40", selection: $config.deuceRule) {
                            ForEach(DeuceRule.allCases, id: \.self) { Text($0.displayName).tag($0) }
                        }
                        Picker("Partido", selection: $config.setsToWin) {
                            Text("A 1 set").tag(1)
                            Text("Al mejor de 3").tag(2)
                        }
                        if config.setsToWin > 1 {
                            Toggle("3.er set como súper tie-break a 10", isOn: $config.superTiebreakDecider)
                        }
                    } footer: {
                        Text("Punto de oro: en 40-40 el siguiente punto gana el juego. Ventaja: hay que ganar dos seguidos.")
                    }
                } else {
                    Section {
                        Stepper("Gana quien llegue a \(config.targetPoints)", value: $config.targetPoints, in: 1...99)
                        Toggle("Hay que ganar por 2", isOn: $config.winByTwo)
                    } footer: {
                        Text("Sirve para vóleibol, ping-pong, bádminton o cualquier juego que se cuente por puntos.")
                    }
                }

                if config.sport == .padel {
                    Section("Saca primero") {
                        Picker("Saca primero", selection: $firstServer) {
                            Text(config.name(of: .a)).tag(Team.a)
                            Text(config.name(of: .b)).tag(Team.b)
                        }
                        .pickerStyle(.segmented)
                    }
                }
            }
            .navigationTitle("Nuevo partido")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Empezar") {
                        store.start(config: config, firstServer: firstServer)
                        dismiss()
                    }
                    .bold()
                }
            }
            .onAppear { config = store.lastConfig }
        }
    }
}
