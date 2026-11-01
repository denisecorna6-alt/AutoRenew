import Foundation
import SwiftUI

@MainActor
final class AppStore: ObservableObject {
    static let shared = AppStore()

    @Published var apps: [ManagedApp] = [] { didSet { save() } }
    @Published var attempts: [RefreshAttempt] = [] { didSet { save() } }
    @Published var settings = AppSettings() { didSet { save() } }

    private struct Snapshot: Codable { var apps: [ManagedApp]; var attempts: [RefreshAttempt]; var settings: AppSettings }
    private let url: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("store.json")
    }()
    private var loading = true

    private init() {
        if let d = try? Data(contentsOf: url), let s = try? JSONDecoder().decode(Snapshot.self, from: d) {
            apps = s.apps; attempts = s.attempts; settings = s.settings
        }
        loading = false
    }

    private func save() {
        guard !loading else { return }
        let snap = Snapshot(apps: apps, attempts: Array(attempts.suffix(500)), settings: settings)
        try? JSONEncoder().encode(snap).write(to: url, options: .atomic)
    }

    func log(_ app: ManagedApp, trigger: String, success: Bool, message: String) {
        attempts.append(RefreshAttempt(bundleID: app.bundleID, trigger: trigger, success: success, message: message))
        if attempts.count > 500 {
            attempts.removeFirst(attempts.count - 500)
        }
    }

    func didRefresh(_ app: ManagedApp, newExpiry: Date, trigger: String) {
        if let i = apps.firstIndex(where: { $0.id == app.id }) { apps[i].expiresAt = newExpiry }
        log(app, trigger: trigger, success: true, message: "Renovado até \(newExpiry.formatted())")
    }

    @discardableResult
    func addApp(name: String, bundleID: String, expiresAt: Date) -> Bool {
        let normalizedID = bundleID.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedName.isEmpty, !normalizedID.isEmpty,
              !apps.contains(where: { $0.bundleID.caseInsensitiveCompare(normalizedID) == .orderedSame }) else {
            return false
        }
        apps.append(ManagedApp(bundleID: normalizedID, name: normalizedName, expiresAt: expiresAt))
        Notifier.reschedule(apps)
        return true
    }
}
