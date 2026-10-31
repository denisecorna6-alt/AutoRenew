import Foundation
import SwiftUI

@MainActor
final class AppStore: ObservableObject {
    static let shared = AppStore()

    @Published var apps: [ManagedApp] = [] { didSet { save() } }
    @Published var attempts: [RefreshAttempt] = [] { didSet { save() } }
    @Published var settings = AppSettings() { didSet { save() } }
    @Published var profiles: [ImportedProfile] = [] { didSet { save() } }

    private struct Snapshot: Codable {
        var apps: [ManagedApp]
        var attempts: [RefreshAttempt]
        var settings: AppSettings
        var profiles: [ImportedProfile]?
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
            profiles = snapshot.profiles ?? []
            restoredSnapshot = true
        }
        loading = false

        // Remove only the exact legacy password item from earlier Alpha builds.
        LegacyCredentialCleanup.run()
        // Rewrite old snapshots so removed Apple ID/Anisette fields are not retained.
        if restoredSnapshot { save() }
    }

    private func save() {
        guard !loading else { return }
        let snapshot = Snapshot(
            apps: apps,
            attempts: Array(attempts.suffix(500)),
            settings: settings,
            profiles: profiles
        )
        do {
            let data = try JSONEncoder().encode(snapshot)
            try data.write(to: url, options: .atomic)
        } catch {
            NSLog("AutoRenew: local state could not be saved (%@)", error.localizedDescription)
        }
    }

    func log(_ app: ManagedApp, trigger: String, success: Bool, message: String) {
        attempts.append(RefreshAttempt(
            bundleID: app.bundleID,
            trigger: trigger,
            success: success,
            message: message
        ))
        if attempts.count > 500 {
            attempts.removeFirst(attempts.count - 500)
        }
    }

    func didRefresh(_ app: ManagedApp, newExpiry: Date, trigger: String) {
        guard newExpiry > app.expiresAt,
              let index = apps.firstIndex(where: { $0.id == app.id }) else { return }
        apps[index].expiresAt = newExpiry
        log(
            app,
            trigger: trigger,
            success: true,
            message: "Renovação confirmada pelo backend até \(newExpiry.formatted())"
        )
    }

    private var profilesDirectory: URL {
        url.deletingLastPathComponent().appendingPathComponent("ProvisioningProfiles", isDirectory: true)
    }

    @discardableResult
    func importProfile(from sourceURL: URL) throws -> ImportedProfile {
        let profile = try ProfileImporter.importProfile(from: sourceURL, into: profilesDirectory)
        guard !profiles.contains(where: { $0.sha256 == profile.sha256 }) else {
            try? FileManager.default.removeItem(
                at: profilesDirectory.appendingPathComponent(profile.storedFileName)
            )
            throw ProfileImportError.duplicate
        }
        profiles.append(profile)
        return profile
    }

    func removeProfile(_ profile: ImportedProfile) {
        // Only delete files whose names match the generated UUID-based storage format.
        guard profile.storedFileName == "\(profile.id).mobileprovision" else { return }
        try? FileManager.default.removeItem(
            at: profilesDirectory.appendingPathComponent(profile.storedFileName)
        )
        profiles.removeAll { $0.id == profile.id }
    }

    private func isValidBundleIdentifier(_ value: String) -> Bool {
        let parts = value.split(separator: ".")
        guard parts.count >= 2 else { return false }
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-")
        return parts.allSatisfy { part in
            !part.isEmpty && part.unicodeScalars.allSatisfy { allowed.contains($0) }
        }
    }

    @discardableResult
    func addApp(name: String, bundleID: String, expiresAt: Date) -> Bool {
        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedID = bundleID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedName.isEmpty,
              isValidBundleIdentifier(normalizedID),
              !apps.contains(where: {
                  $0.bundleID.caseInsensitiveCompare(normalizedID) == .orderedSame
              }) else {
            return false
        }
        apps.append(ManagedApp(bundleID: normalizedID, name: normalizedName, expiresAt: expiresAt))
        Notifier.reschedule(apps)
        return true
    }

    func addDemoApp() {
        let number = apps.count + 1
        apps.append(ManagedApp(
            bundleID: "demo.app\(number)",
            name: "App Demo \(number)",
            expiresAt: Date(timeIntervalSinceNow: 2 * 86_400)
        ))
        Notifier.reschedule(apps)
    }
}
