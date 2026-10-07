import SwiftUI
import ScoreKit

/// Elegir reglas y empezar. Recuerda la última configuración.
struct WatchSetupView: View {
    @Environment(MatchStore.self) private var store
    @State private var config = MatchConfig()
    @State private var loaded = false
    @AppStorage("recordWorkout") private var recordWorkout = true

    var body: some View {
        List {
            Section {
                Picker("Deporte", selection: $config.sport) {
                    ForEach(Sport.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }
            }

            if config.sport == .padel {
                Section("40-40") {
                    Picker("Regla", selection: $config.deuceRule) {
                        ForEach(DeuceRule.allCases, id: \.self) { Text($0.displayName).tag($0) }
                    }
                }
                Section("Partido") {
                    Picker("Sets", selection: $config.setsToWin) {
                        Text("1 set").tag(1)
                        Text("Mejor de 3").tag(2)
                    }
                    if config.setsToWin > 1 {
                        Toggle("3.º set: súper tie-break", isOn: $config.superTiebreakDecider)
                    }
                }
            } else {
                Section("Gana quien llegue a") {
                    Stepper(value: $config.targetPoints, in: 1...99) {
                        Text("\(config.targetPoints) puntos")
                    }
                    Toggle("Diferencia de 2", isOn: $config.winByTwo)
                }
            }

            Section {
                Toggle("Guardar en Salud", isOn: $recordWorkout)
            } footer: {
                Text("Registra tiempo, pulso y calorías, y deja la app en pantalla todo el partido.")
            }

            Section("¿Quién saca primero?") {
                ForEach(Team.allCases, id: \.self) { team in
                    Button {
                        store.start(config: config, firstServer: team)
                    } label: {
                        Label(config.name(of: team), systemImage: "figure.tennis")
                            .foregroundStyle(Theme.color(team))
                    }
                }
            }
        }
        .navigationTitle("Tanteo")
        .onAppear {
            if !loaded {
                config = store.lastConfig
                loaded = true
            }
        }
    }
}
