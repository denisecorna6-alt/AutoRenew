import Foundation

struct ManagedApp: Codable, Identifiable, Hashable, Sendable {
    var id: String { bundleID }
    var bundleID: String
    var name: String
    var expiresAt: Date
    var isActive = true
    var daysLeft: Double { expiresAt.timeIntervalSinceNow / 86_400 }
}

struct RefreshAttempt: Codable, Identifiable, Sendable {
    var id = UUID()
    var date = Date()
    var bundleID: String
    var trigger: String
    var success: Bool
    var message: String
}

struct AppSettings: Codable, Sendable {
    static let sideStoreAnisetteURL = "https://ani.sidestore.io"

    var anisetteURLs: [String] = [sideStoreAnisetteURL]
    var thresholdHours = 48.0
    /// Explicit opt-in: provisioning and header requests send device Anisette data remotely.
    var allowRemoteAnisette = false

    private enum CodingKeys: String, CodingKey {
        case anisetteURLs
        case thresholdHours
        case allowRemoteAnisette
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        anisetteURLs = try values.decodeIfPresent([String].self, forKey: .anisetteURLs)
            ?? [Self.sideStoreAnisetteURL]
        thresholdHours = try values.decodeIfPresent(Double.self, forKey: .thresholdHours) ?? 48.0
        allowRemoteAnisette = try values.decodeIfPresent(Bool.self, forKey: .allowRemoteAnisette) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(anisetteURLs, forKey: .anisetteURLs)
        try values.encode(thresholdHours, forKey: .thresholdHours)
        try values.encode(allowRemoteAnisette, forKey: .allowRemoteAnisette)
    }
}

enum RefreshError: Error, Equatable, Sendable {
    case authentication
    case anisetteUnavailable
    case network
    case notImplemented
    case other
}
