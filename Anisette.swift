import Foundation

struct AnisetteData: Sendable {
    var headers: [String: String]
    var fetched = Date()

    var isValid: Bool {
        guard let machineData = headers["X-Apple-I-MD"], !machineData.isEmpty else {
            return false
        }
        let age = Date().timeIntervalSince(fetched)
        // Reject clock-skewed/future timestamps as well as expired cache entries.
        return age >= 0 && age < 300
    }
}

protocol AnisetteProvider: Sendable {
    func fetch() async throws -> AnisetteData
}

/// Placeholder only. SideStore Anisette V3 requires a provisioning WebSocket
/// session and a POST to /v3/get_headers with a provisioned ADI blob and identifier.
/// A GET to the server root is not a valid V3 client, so this provider deliberately
/// makes no network request until that flow is implemented and independently tested.
struct RemoteAnisetteProvider: AnisetteProvider {
    let url: URL

    func fetch() async throws -> AnisetteData {
        guard url.scheme?.lowercased() == "https",
              url.user == nil, url.password == nil,
              url.fragment == nil else {
            throw RefreshError.anisetteUnavailable
        }
        throw RefreshError.anisetteUnavailable
    }
}

/// Actor isolation prevents concurrent refresh tasks from racing the metadata cache.
actor AnisetteRouter: AnisetteProvider {
    private var cache: AnisetteData?
    private let providers: [any AnisetteProvider]

    init(urls: [String]) {
        providers = urls.compactMap { raw in
            guard let url = URL(string: raw.trimmingCharacters(in: .whitespacesAndNewlines)),
                  url.scheme?.lowercased() == "https",
                  url.host != nil,
                  url.user == nil, url.password == nil,
                  url.fragment == nil else { return nil }
            return RemoteAnisetteProvider(url: url)
        }
    }

    func fetch() async throws -> AnisetteData {
        if let cached = cache, cached.isValid { return cached }
        for provider in providers {
            if let value = try? await provider.fetch(), value.isValid {
                cache = value
                return value
            }
        }
        throw RefreshError.anisetteUnavailable
    }
}
