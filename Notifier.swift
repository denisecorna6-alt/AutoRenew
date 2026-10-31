import UserNotifications

enum ExpiryNotificationPolicy {
    static let maximumPendingRequests = 64
    static let reminderHours = [48, 24, 6]

    struct Reminder: Equatable {
        let identifier: String
        let appName: String
        let hoursBefore: Int
        let fireDate: Date
    }

    static func reminders(
        for apps: [ManagedApp],
        now: Date,
        limit: Int = maximumPendingRequests
    ) -> [Reminder] {
        guard limit > 0 else { return [] }
        var reminders: [Reminder] = []
        for app in apps where app.isActive {
            for hours in reminderHours {
                let fireDate = app.expiresAt.addingTimeInterval(-Double(hours) * 3600)
                guard fireDate > now else { continue }
                reminders.append(Reminder(
                    identifier: "expiry.\(app.bundleID).\(hours)",
                    appName: app.name,
                    hoursBefore: hours,
                    fireDate: fireDate
                ))
            }
        }
        return Array(reminders.sorted {
            if $0.fireDate == $1.fireDate {
                return $0.identifier < $1.identifier
            }
            return $0.fireDate < $1.fireDate
        }.prefix(limit))
    }
}

enum Notifier {
    static func requestAuth() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    /// iOS keeps at most 64 pending local notifications for an app; reserve space for other features.
    static func reschedule(_ apps: [ManagedApp]) {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { pending in
            let expiryRequests = pending.filter { $0.identifier.hasPrefix("expiry.") }
            center.removePendingNotificationRequests(withIdentifiers: expiryRequests.map(\.identifier))

            let otherRequestCount = pending.count - expiryRequests.count
            let capacity = max(0, ExpiryNotificationPolicy.maximumPendingRequests - otherRequestCount)
            let reminders = ExpiryNotificationPolicy.reminders(for: apps, now: Date(), limit: capacity)

            for reminder in reminders {
                let content = UNMutableNotificationContent()
                content.title = "\(reminder.appName) vence em \(reminder.hoursBefore)h"
                content.body = "Abra o AutoRenew para conferir a data informada. A renovação automática ainda está em desenvolvimento."
                content.sound = .default
                let components = Calendar.current.dateComponents(
                    [.year, .month, .day, .hour, .minute], from: reminder.fireDate
                )
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                let request = UNNotificationRequest(
                    identifier: reminder.identifier,
                    content: content,
                    trigger: trigger
                )
                center.add(request)
            }
        }
    }
}
