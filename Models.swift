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
    var anisetteURLs = ["https://ani.sidestore.io"]   // ordem = prioridade/fallback
    var thresholdHours = 48.0
    var blockDomains = false
}

enum RefreshError: Error, Equatable {
    case authentication, anisetteUnavailable, network, other
}
