import UserNotifications

enum Notifier {
    /// Ask only when the user explicitly enables reminders in Settings.
    static func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            NSLog("AutoRenew: notification authorization failed (%@)", error.localizedDescription)
            return false
        }
    }

    /// Schedule local expiry reminders only when iOS currently authorizes them.
    /// iOS may defer delivery; reminders never sign, install, or renew apps.
    static func reschedule(_ apps: [ManagedApp], thresholdHours: Double) async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        let authorized = settings.authorizationStatus == .authorized ||
            settings.authorizationStatus == .provisional ||
            settings.authorizationStatus == .ephemeral

        let pending = await center.pendingNotificationRequests()
        center.removePendingNotificationRequests(
            withIdentifiers: pending.map(\.identifier).filter { $0.hasPrefix("expiry.") }
        )
        guard authorized else { return }

        let threshold = min(max(thresholdHours, 6), 120)
        let reminderHours = Array(Set([threshold, 24.0, 6.0])).sorted(by: >)
        let orderedApps = apps.filter(\.isActive).sorted { $0.expiresAt < $1.expiresAt }

        // Keep below the platform's pending-notification limit with room for other features.
        let maximumPendingReminders = 60
        var scheduledCount = 0
        for app in orderedApps {
            for hours in reminderHours {
                guard scheduledCount < maximumPendingReminders else { return }
                let fireDate = app.expiresAt.addingTimeInterval(-hours * 3600)
                guard fireDate > Date() else { continue }

                let content = UNMutableNotificationContent()
                content.title = "\(app.name) expira em aproximadamente \(Int(hours))h"
                content.body = "Abra o AutoRenew para conferir a data cadastrada. O app não renova automaticamente."
                content.sound = settings.soundSetting == .enabled ? .default : nil

                let components = Calendar.current.dateComponents(
                    [.year, .month, .day, .hour, .minute], from: fireDate
                )
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                let request = UNNotificationRequest(
                    identifier: "expiry.\(app.bundleID).\(Int(hours))",
                    content: content,
                    trigger: trigger
                )
                do {
                    try await center.add(request)
                    scheduledCount += 1
                } catch {
                    NSLog("AutoRenew: could not schedule reminder (%@)", error.localizedDescription)
                }
            }
        }
    }
}
