import UserNotifications

enum Notifier {
    static func requestAuth() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    /// Avisos escalonados (48h/24h/6h) que funcionam mesmo se nenhum BGTask rodar.
    static func reschedule(_ apps: [ManagedApp]) {
        let c = UNUserNotificationCenter.current()
        c.getPendingNotificationRequests { pending in
            c.removePendingNotificationRequests(withIdentifiers: pending.map(\.identifier).filter { $0.hasPrefix("expiry.") })
            for app in apps where app.isActive {
                for h in [48.0, 24.0, 6.0] {
                    let fire = app.expiresAt.addingTimeInterval(-h * 3600)
                    guard fire > Date() else { continue }
                    let content = UNMutableNotificationContent()
                    content.title = "\(app.name) expira em \(Int(h))h"
                    content.body = "Abra o AutoRenew para renovar agora."
                    content.sound = .default
                    let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
                    let trig = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
                    c.add(UNNotificationRequest(identifier: "expiry.\(app.bundleID).\(Int(h))", content: content, trigger: trig))
                }
            }
        }
    }
}
