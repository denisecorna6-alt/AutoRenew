import SwiftUI

@main
struct AutoRenewApp: App {
    @StateObject private var store = AppStore.shared
    @Environment(\.scenePhase) private var phase

    init() { BackgroundScheduler.register() }

    var body: some Scene {
        WindowGroup {
            ContentView().environmentObject(store)
                .task { Notifier.requestAuth() }
        }
        .onChange(of: phase) { _, new in
            switch new {
            case .active:
                Task { await RefreshCoordinator.shared.runIfNeeded(trigger: "foreground", budget: .seconds(60)) }
            case .background:
                BackgroundScheduler.schedule()
            default: break
            }
        }
    }
}
