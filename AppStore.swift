import Foundation
import SwiftUI

@MainActor
final class AppStore: ObservableObject {
    static let shared = AppStore()

    @Published var apps: [ManagedApp] = [] { didSet { save() } }
    @Published var attempts: [RefreshAttempt] = [] { didSet { save() } }
    @Published var settings = AppSettings() { didSet { save() } }

    private struct Snapshot: Codable {
        var apps: [ManagedApp]
        var attempts: [RefreshAttempt]
        var settings: AppSettings
    }
    private let url: URL = {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("store.json")
    }()
    private var loading = true

    private init() {
        var restoredSnapshot = false
        if let data = try? Data(contentsOf: url),
           let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data) {
            apps = snapshot.apps
            attempts = snapshot.attempts
            settings = snapshot.settings
            restoredSnapshot = true
        }
        loading = false

        // Delete only the exact legacy password item created by the previous Alpha UI.
        LegacyCredentialCleanup.run()
        // Re-encode a valid legacy snapshot so removed Apple ID/Anisette fields are not kept on disk.
        if restoredSnapshot { save() }
        Task { await Notifier.reschedule(apps, thresholdHours: settings.thresholdHours) }
    }

    private func save() {
        guard !loading else { return }
        let snapshot = Snapshot(apps: apps, attempts: Array(attempts.suffix(500)), settings: settings)
        do {
            let data = try JSONEncoder().encode(snapshot)
            try data.write(to: url, options: .atomic)
        } catch {
            NSLog("AutoRenew: local state could not be saved (%@)", error.localizedDescription)
        }
    }

    func log(_ app: ManagedApp, trigger: String, success: Bool, message: String) {
        attempts.append(RefreshAttempt(bundleID: app.bundleID, trigger: trigger,
                                       success: success, message: message))
        if attempts.count > 500 {
            attempts.removeFirst(attempts.count - 500)
        }
    }

    func didRefresh(_ app: ManagedApp, newExpiry: Date, trigger: String) {
        guard newExpiry > app.expiresAt,
              let index = apps.firstIndex(where: { $0.id == app.id }) else { return }
        apps[index].expiresAt = newExpiry
        log(app, trigger: trigger, success: true,
            message: "Renovação confirmada pelo backend até \(newExpiry.formatted())")
    }

    func addDemoApp() {
        let number = apps.count + 1
        apps.append(ManagedApp(bundleID: "demo.app\(number)", name: "App Demo \(number)",
                               expiresAt: Date(timeIntervalSinceNow: 2 * 86_400), isDemo: true))
        Task { await Notifier.reschedule(apps, thresholdHours: settings.thresholdHours) }
    }

    func removeApps(at offsets: IndexSet) {
        apps.remove(atOffsets: offsets)
        Task { await Notifier.reschedule(apps, thresholdHours: settings.thresholdHours) }
    }
}
