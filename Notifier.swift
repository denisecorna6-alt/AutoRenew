import UserNotifications

enum Notifier {
    /// Request permission only after an explicit tap in Settings.
    static func requestAuthorization(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            completion(granted)
        }
    }

    /// Schedule reminders only while notification delivery is authorized.
    static func reschedule(_ apps: [ManagedApp]) {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            let authorized = settings.authorizationStatus == .authorized ||
                settings.authorizationStatus == .provisional ||
                settings.authorizationStatus == .ephemeral

            center.getPendingNotificationRequests { pending in
                let expiryIDs = pending.map(\.identifier).filter { $0.hasPrefix("expiry.") }
                center.removePendingNotificationRequests(withIdentifiers: expiryIDs)
                guard authorized else { return }

                for app in apps where app.isActive {
                    for hours in [48.0, 24.0, 6.0] {
                        let fireDate = app.expiresAt.addingTimeInterval(-hours * 3600)
                        guard fireDate > Date() else { continue }

                        let content = UNMutableNotificationContent()
                        content.title = "\(app.name) expira em \(Int(hours))h"
                        content.body = "Abra o AutoRenew para conferir o prazo. A renovação automática ainda não está disponível."
                        content.sound = .default
                        let components = Calendar.current.dateComponents(
                            [.year, .month, .day, .hour, .minute],
                            from: fireDate
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
}
