import SwiftUI

@main
struct TanteoWatchApp: App {
    @State private var store = MatchStore()

    var body: some Scene {
        WindowGroup {
            WatchRootView()
                .environment(store)
        }
    }
}

struct WatchRootView: View {
    @Environment(MatchStore.self) private var store

    var body: some View {
        NavigationStack {
            if store.current != nil {
                WatchScoreView()
            } else {
                WatchSetupView()
            }
        }
    }
}
