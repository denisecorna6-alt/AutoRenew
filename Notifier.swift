import UserNotifications

enum Notifier {
    static func requestAuth() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    /// Avisos escalonados (48h/24h/6h); eles não executam assinatura ou reinstalação.
    static func reschedule(_ apps: [ManagedApp]) {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { pending in
            center.removePendingNotificationRequests(
                withIdentifiers: pending.map(\.identifier).filter { $0.hasPrefix("expiry.") }
            )
            for app in apps where app.isActive {
                for hours in [48.0, 24.0, 6.0] {
                    let fireDate = app.expiresAt.addingTimeInterval(-hours * 3600)
                    guard fireDate > Date() else { continue }
                    let content = UNMutableNotificationContent()
                    content.title = "\(app.name) expira em \(Int(hours))h"
                    content.body = "Abra o AutoRenew para consultar o estado. A renovação automática não está disponível nesta versão."
                    content.sound = .default
                    let components = Calendar.current.dateComponents(
                        [.year, .month, .day, .hour, .minute], from: fireDate
                    )
                    let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                    center.add(UNNotificationRequest(
                        identifier: "expiry.\(app.bundleID).\(Int(hours))",
                        content: content,
                        trigger: trigger
                    ))
                }
            }
        }
    }
}
