import SwiftUI

@main
struct TanteoWatchApp: App {
    @State private var store = MatchStore()
    @State private var workout = WorkoutManager()

    var body: some Scene {
        WindowGroup {
            WatchRootView()
                .environment(store)
                .environment(workout)
        }
    }
}

struct WatchRootView: View {
    @Environment(MatchStore.self) private var store
    @Environment(WorkoutManager.self) private var workout
    @AppStorage("recordWorkout") private var recordWorkout = true

    var body: some View {
        NavigationStack {
            if store.current != nil {
                WatchScoreView()
            } else {
                WatchSetupView()
            }
        }
        .task {
            if recordWorkout { await workout.requestAuthorization() }
            await syncWorkout()
        }
        .onChange(of: store.current?.id) {
            Task { await syncWorkout() }
        }
        .onChange(of: store.current?.state.isFinished) {
            Task { await syncWorkout() }
        }
    }

    /// Hay partido en juego → se registra; no hay o ya terminó → se guarda.
    private func syncWorkout() async {
        if let match = store.current, !match.state.isFinished, recordWorkout {
            await workout.start(for: match)
        } else if workout.isRunning {
            workout.end()
        }
    }
}
