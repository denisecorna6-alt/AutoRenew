import SwiftUI

@main
struct AutoRenewApp: App {
    @StateObject private var store = AppStore.shared
    @Environment(\.scenePhase) private var phase

    init() {
        LegacyCredentialCleanup.removePreviouslyStoredApplePassword()
        BackgroundScheduler.register()
    }

    var body: some Scene {
        WindowGroup {
            ContentView().environmentObject(store)
                .task {
                    await Notifier.reschedule(store.apps, thresholdHours: store.settings.thresholdHours)
                }
        }
        .onChange(of: phase) { _, new in
            switch new {
            case .active:
                Task {
                    await Notifier.reschedule(store.apps, thresholdHours: store.settings.thresholdHours)
                    _ = await RefreshCoordinator.shared.runIfNeeded(
                        trigger: "foreground", budget: .seconds(60)
                    )
                }
            case .background:
                BackgroundScheduler.schedule()
            default:
                break
            }
        }
    }
}
