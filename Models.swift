import Foundation

struct ManagedApp: Codable, Identifiable, Hashable {
    var id: String { bundleID }
    var bundleID: String
    var name: String
    var expiresAt: Date
    var isActive = true
    var daysLeft: Double { expiresAt.timeIntervalSinceNow / 86_400 }
}

struct RefreshAttempt: Codable, Identifiable {
    var id = UUID()
    var date = Date()
    var bundleID: String
    var trigger: String
    var success: Bool
    var message: String
}

struct AppSettings: Codable {
    var thresholdHours = 48.0
}

enum RefreshError: Error, Equatable {
    case notImplemented
    case network
    case anisetteUnavailable
    case other
}
