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

/// Uses the official V3 flow only after the user has enabled remote Anisette in Settings.
/// Provisioning state remains in the device-only Keychain vault.
struct RemoteAnisetteProvider: AnisetteProvider {
    let url: URL
    let vault: AnisetteV3StateVault

    init(url: URL, vault: AnisetteV3StateVault = AnisetteV3StateVault()) {
        self.url = url
        self.vault = vault
    }

    func fetch() async throws -> AnisetteData {
        guard url.scheme?.lowercased() == "https",
              url.host?.lowercased() == "ani.sidestore.io",
              url.user == nil, url.password == nil,
              url.query == nil, url.fragment == nil else {
            throw RefreshError.anisetteUnavailable
        }

        try await AnisetteV3Provisioner(serverURL: url, vault: vault).provisionIfNeeded()
        guard let state = try await vault.loadProvisioningState() else {
            throw RefreshError.anisetteUnavailable
        }
        return try await AnisetteV3HeadersClient(serverURL: url).fetch(using: state)
    }
}

/// Actor isolation prevents concurrent refresh tasks from racing the metadata cache.
actor AnisetteRouter: AnisetteProvider {
    private var cache: AnisetteData?
    private let providers: [any AnisetteProvider]
    private let remoteRequestsEnabled: Bool

    init(urls: [String], remoteRequestsEnabled: Bool = false) {
        self.remoteRequestsEnabled = remoteRequestsEnabled
        providers = urls.compactMap { raw in
            guard let url = URL(string: raw.trimmingCharacters(in: .whitespacesAndNewlines)),
                  url.scheme?.lowercased() == "https",
                  url.host?.lowercased() == "ani.sidestore.io",
                  url.user == nil, url.password == nil,
                  url.query == nil, url.fragment == nil else { return nil }
            return RemoteAnisetteProvider(url: url)
        }
    }

    func fetch() async throws -> AnisetteData {
        guard remoteRequestsEnabled else { throw RefreshError.anisetteUnavailable }
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
