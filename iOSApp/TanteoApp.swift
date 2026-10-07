import SwiftUI

@main
struct TanteoApp: App {
    @State private var store = MatchStore()

    var body: some Scene {
        WindowGroup {
            TabView {
                NavigationStack { LiveView() }
                    .tabItem { Label("Partido", systemImage: "sportscourt") }
                NavigationStack { HistoryView() }
                    .tabItem { Label("Historial", systemImage: "clock.arrow.circlepath") }
            }
            .tint(Theme.accent)
            .preferredColorScheme(.dark)
            .environment(store)
        }
    }
}
