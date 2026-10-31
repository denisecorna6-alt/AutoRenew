import UserNotifications

enum Notifier {
    static func requestAuth() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    /// Reminders at 48h/24h/6h before the manually entered expiry date.
    static func reschedule(_ apps: [ManagedApp]) {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { pending in
            let oldIDs = pending.map(\.identifier).filter { $0.hasPrefix("expiry.") }
            center.removePendingNotificationRequests(withIdentifiers: oldIDs)

            for app in apps where app.isActive {
                for hours in [48.0, 24.0, 6.0] {
                    let fireDate = app.expiresAt.addingTimeInterval(-hours * 3600)
                    guard fireDate > Date() else { continue }
                    let content = UNMutableNotificationContent()
                    content.title = "\(app.name) vence em \(Int(hours))h"
                    content.body = "Abra o AutoRenew para conferir a data informada. A renovação automática ainda está em desenvolvimento."
                    content.sound = .default
                    let components = Calendar.current.dateComponents(
                        [.year, .month, .day, .hour, .minute], from: fireDate
                    )
                    let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                    let request = UNNotificationRequest(
                        identifier: "expiry.\(app.bundleID).\(Int(hours))",
                        content: content,
                        trigger: trigger
                    )
                    center.add(request)
                }
            }
        }
    }
}
