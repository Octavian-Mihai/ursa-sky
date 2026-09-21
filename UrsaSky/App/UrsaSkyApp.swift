import SwiftUI

@main
struct UrsaSkyApp: App {
    @StateObject private var app = AppState()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(app)
                .preferredColorScheme(.dark)
                .onChange(of: scenePhase) { _, phase in
                    app.sceneActive = phase == .active
                    if phase == .active {
                        Task { await app.refreshTLEIfOnline() }
                    }
                }
        }
    }
}
