import SwiftUI

@main
struct FocusDungeonApp: App {
    @State private var store = GameStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            Group {
                #if DEBUG
                if SceneDemoView.isEnabled {
                    SceneDemoView()
                } else {
                    TavernView()
                }
                #else
                TavernView()
                #endif
            }
            .environment(store)
            .preferredColorScheme(.dark)
        }
        .onChange(of: scenePhase) { _, phase in
            store.scenePhaseChanged(to: phase)
        }
    }
}
